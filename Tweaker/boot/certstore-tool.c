/*
 * certstore-tool - changes a certificate store in place, through SQLite, while the certificate manager runs.
 *
 *   certstore-tool count  <certstore.db>
 *   certstore-tool import <certstore.db> <roots.db> [SHA-1 of one root]
 *   certstore-tool remove <certstore.db> <file with one SHA-1 per line>
 *   certstore-tool list-expired <certstore.db>     the SHA-1 of the roots past their date, nothing changed
 *   certstore-tool remove-expired <certstore.db>   those roots removed; BlackBerry's own are never touched
 *
 * Writes the same rows the certificate manager writes for an imported certificate.
 */
#include <sqlite3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static sqlite3 *store = NULL;

static void stop(const char *what)
{
    printf("error: %s: %s\n", what, store != NULL ? sqlite3_errmsg(store) : "no database");
    if (store != NULL) {
        sqlite3_close(store);
    }
    exit(1);
}

static void run(const char *sql)
{
    if (sqlite3_exec(store, sql, NULL, NULL, NULL) != SQLITE_OK) {
        stop(sql);
    }
}

static sqlite3_stmt *prepare(const char *sql)
{
    sqlite3_stmt *statement = NULL;
    if (sqlite3_prepare_v2(store, sql, -1, &statement, NULL) != SQLITE_OK) {
        stop(sql);
    }
    return statement;
}

static void finish_write(sqlite3_stmt *statement, const char *what)
{
    if (sqlite3_step(statement) != SQLITE_DONE) {
        stop(what);
    }
    sqlite3_finalize(statement);
}

static int count_objects(void)
{
    sqlite3_stmt *statement = prepare("select count(*) from StoredObjects");
    int count = 0;
    if (sqlite3_step(statement) == SQLITE_ROW) {
        count = sqlite3_column_int(statement, 0);
    }
    sqlite3_finalize(statement);
    return count;
}

static int store_has_root(const void *fingerprint, int size)
{
    sqlite3_stmt *statement = prepare("select count(*) from Attributes where key = 'tpattr.fingerprint' and value = ?");
    int count = 0;
    sqlite3_bind_blob(statement, 1, fingerprint, size, SQLITE_TRANSIENT);
    if (sqlite3_step(statement) == SQLITE_ROW) {
        count = sqlite3_column_int(statement, 0);
    }
    sqlite3_finalize(statement);
    return count > 0;
}

static void add_blob_attribute(sqlite3_int64 object_id, const char *key, const void *value, int size)
{
    sqlite3_stmt *statement = prepare("insert into Attributes (id, key, value) values (?, ?, ?)");
    sqlite3_bind_int64(statement, 1, object_id);
    sqlite3_bind_text(statement, 2, key, -1, SQLITE_STATIC);
    sqlite3_bind_blob(statement, 3, value, size, SQLITE_TRANSIENT);
    finish_write(statement, key);
}

static void add_number_attribute(sqlite3_int64 object_id, const char *key, sqlite3_int64 value)
{
    sqlite3_stmt *statement = prepare("insert into Attributes (id, key, value) values (?, ?, ?)");
    sqlite3_bind_int64(statement, 1, object_id);
    sqlite3_bind_text(statement, 2, key, -1, SQLITE_STATIC);
    sqlite3_bind_int64(statement, 3, value);
    finish_write(statement, key);
}

static void add_column_attribute(sqlite3_int64 object_id, const char *key, sqlite3_stmt *source, int column)
{
    add_blob_attribute(object_id, key, sqlite3_column_blob(source, column), sqlite3_column_bytes(source, column));
}

static void import_roots(const char *roots_path, const char *only_sha1)
{
    static const char type_value[] = "cert";
    static const char all_roots[] = "select der, fingerprint, ias, issuer, subject, skid, hash from Roots";
    static const char one_root[] = "select der, fingerprint, ias, issuer, subject, skid, hash from Roots where hex(fingerprint) = ?";
    sqlite3 *source = NULL;
    sqlite3_stmt *roots = NULL;
    int added = 0;
    int already_there = 0;

    /* A separate read-only connection: "begin immediate" on an attached file would try to lock it for writing. */
    if (sqlite3_open_v2(roots_path, &source, SQLITE_OPEN_READONLY, NULL) != SQLITE_OK) {
        stop(roots_path);
    }
    if (sqlite3_prepare_v2(source, only_sha1 != NULL ? one_root : all_roots, -1, &roots, NULL) != SQLITE_OK) {
        printf("error: reading the roots: %s\n", sqlite3_errmsg(source));
        stop(roots_path);
    }
    if (only_sha1 != NULL) {
        sqlite3_bind_text(roots, 1, only_sha1, -1, SQLITE_STATIC);
    }

    run("begin immediate");

    while (sqlite3_step(roots) == SQLITE_ROW) {
        if (store_has_root(sqlite3_column_blob(roots, 1), sqlite3_column_bytes(roots, 1))) {
            already_there++;
        } else {
            sqlite3_stmt *object = prepare("insert into StoredObjects (cert, certfmt) values (?, 0)");
            sqlite3_int64 object_id;

            sqlite3_bind_blob(object, 1, sqlite3_column_blob(roots, 0), sqlite3_column_bytes(roots, 0), SQLITE_TRANSIENT);
            finish_write(object, "insert object");
            object_id = sqlite3_last_insert_rowid(store);

            add_column_attribute(object_id, "tpattr.fingerprint", roots, 1);
            add_column_attribute(object_id, "tpattr.ias", roots, 2);
            add_column_attribute(object_id, "tpattr.issuer", roots, 3);
            add_column_attribute(object_id, "tpattr.subject", roots, 4);
            if (sqlite3_column_type(roots, 5) != SQLITE_NULL) {
                add_column_attribute(object_id, "tpattr.subjectkeyid", roots, 5);
            }
            add_column_attribute(object_id, "tpattr.kvp.OSSLFileHash", roots, 6);
            add_blob_attribute(object_id, "tpattr.kvp.type", type_value, sizeof(type_value));
            add_number_attribute(object_id, "tpattr.uid", object_id);
            added++;
        }
    }
    sqlite3_finalize(roots);
    sqlite3_close(source);
    run("commit");
    printf("added %d, already there %d\n", added, already_there);
}

static void remove_one(sqlite3_int64 object_id)
{
    static const char *const deletions[] = {
        "delete from Attributes where id = ?",
        "delete from AttributeSets where id = ?",
        "delete from StoredObjects where id = ?",
    };
    unsigned int index;
    for (index = 0; index < sizeof(deletions) / sizeof(deletions[0]); index++) {
        sqlite3_stmt *statement = prepare(deletions[index]);
        sqlite3_bind_int64(statement, 1, object_id);
        finish_write(statement, deletions[index]);
    }
}

static void remove_roots(const char *list_path)
{
    char line[128];
    int removed = 0;
    int not_there = 0;
    FILE *list = fopen(list_path, "r");

    if (list == NULL) {
        stop("cannot open the list");
    }
    run("begin immediate");
    while (fgets(line, sizeof(line), list) != NULL) {
        sqlite3_stmt *find = prepare("select id from Attributes where key = 'tpattr.fingerprint' and hex(value) = ?");
        line[strcspn(line, "\r\n")] = 0;
        sqlite3_bind_text(find, 1, line, -1, SQLITE_STATIC);
        if (sqlite3_step(find) == SQLITE_ROW) {
            sqlite3_int64 object_id = sqlite3_column_int64(find, 0);
            sqlite3_finalize(find);
            remove_one(object_id);
            removed++;
        } else {
            sqlite3_finalize(find);
            not_there++;
        }
    }
    fclose(list);
    run("commit");
    printf("removed %d, not there %d\n", removed, not_there);
}

/* One DER element. */
struct der_item {
    int tag;
    const unsigned char *value;
    long size;
    const unsigned char *after;
};

static int read_der(const unsigned char *at, const unsigned char *end, struct der_item *item)
{
    long size;

    if (end - at < 2) {
        return 0;
    }
    item->tag = at[0];
    size = at[1];
    at += 2;
    if (size & 0x80) {
        int count = (int)(size & 0x7f);
        if (count > 4 || end - at < count) {
            return 0;
        }
        size = 0;
        while (count > 0) {
            size = (size << 8) | *at;
            at++;
            count--;
        }
    }
    if (size < 0 || end - at < size) {
        return 0;
    }
    item->value = at;
    item->size = size;
    item->after = at + size;
    return 1;
}

/* The end of a certificate's validity as "YYYYMMDDHHMMSS", and its subject as DER. Returns 0 for what it cannot read. */
static int read_certificate(const unsigned char *der, int size, char *not_after, struct der_item *subject)
{
    struct der_item certificate;
    struct der_item body;
    struct der_item field;
    struct der_item validity;
    struct der_item valid_from;
    struct der_item valid_until;

    if (!read_der(der, der + size, &certificate) || !read_der(certificate.value, certificate.after, &body)) {
        return 0;
    }
    if (!read_der(body.value, body.after, &field)) {
        return 0;
    }
    if (field.tag == 0xA0 && !read_der(field.after, body.after, &field)) { /* the version; the serial number follows */
        return 0;
    }
    if (!read_der(field.after, body.after, &field)         /* signature algorithm */
            || !read_der(field.after, body.after, &field)  /* issuer */
            || !read_der(field.after, body.after, &validity)
            || !read_der(validity.after, body.after, subject)) {
        return 0;
    }
    if (!read_der(validity.value, validity.after, &valid_from) || !read_der(valid_from.after, validity.after, &valid_until)) {
        return 0;
    }
    if (valid_until.tag == 0x17 && valid_until.size >= 12) {
        memcpy(not_after, valid_until.value[0] >= '5' ? "19" : "20", 2);
        memcpy(not_after + 2, valid_until.value, 12);
    } else if (valid_until.tag == 0x18 && valid_until.size >= 14) {
        memcpy(not_after, valid_until.value, 14);
    } else {
        return 0;
    }
    not_after[14] = 0;
    return 1;
}

static int bytes_contain(const unsigned char *bytes, long size, const char *text)
{
    long text_size = (long)strlen(text);
    long at;

    for (at = 0; at + text_size <= size; at++) {
        if (memcmp(bytes + at, text, (size_t)text_size) == 0) {
            return 1;
        }
    }
    return 0;
}

static int is_blackberrys_own(const struct der_item *subject)
{
    return bytes_contain(subject->value, subject->size, "BlackBerry")
            || bytes_contain(subject->value, subject->size, "Research In Motion")
            || bytes_contain(subject->value, subject->size, "RIM ")
            || bytes_contain(subject->value, subject->size, "Certicom");
}

/* The roots past their date, by the phone's clock. A clock that cannot be right removes nothing: it would take every root with it. */
static void handle_expired(int remove_them)
{
    enum { MOST_OBJECTS = 2048 };
    sqlite3_int64 expired_ids[MOST_OBJECTS];
    int expired_count = 0;
    int own_kept = 0;
    int unreadable = 0;
    int index;
    char now[16];
    time_t clock_now = time(NULL);
    sqlite3_stmt *objects;

    strftime(now, sizeof(now), "%Y%m%d%H%M%S", gmtime(&clock_now));
    if (strncmp(now, "2024", 4) < 0 || strncmp(now, "2100", 4) > 0) {
        printf("the phone's clock says %s, nothing is removed\n", now);
        return;
    }

    objects = prepare("select id, cert from StoredObjects where cert is not null");
    while (sqlite3_step(objects) == SQLITE_ROW) {
        char not_after[16];
        struct der_item subject;
        if (!read_certificate(sqlite3_column_blob(objects, 1), sqlite3_column_bytes(objects, 1), not_after, &subject)) {
            unreadable++;
        } else if (strcmp(not_after, now) < 0) {
            if (is_blackberrys_own(&subject)) {
                own_kept++;
            } else if (expired_count < MOST_OBJECTS) {
                expired_ids[expired_count] = sqlite3_column_int64(objects, 0);
                expired_count++;
            }
        }
    }
    sqlite3_finalize(objects);

    if (remove_them) {
        run("begin immediate");
    }
    for (index = 0; index < expired_count; index++) {
        if (remove_them) {
            remove_one(expired_ids[index]);
        } else {
            sqlite3_stmt *fingerprint = prepare("select hex(value) from Attributes where id = ? and key = 'tpattr.fingerprint'");
            sqlite3_bind_int64(fingerprint, 1, expired_ids[index]);
            if (sqlite3_step(fingerprint) == SQLITE_ROW) {
                printf("%s\n", sqlite3_column_text(fingerprint, 0));
            }
            sqlite3_finalize(fingerprint);
        }
    }
    if (remove_them) {
        run("commit");
    }
    printf("expired %d, BlackBerry's own kept %d, unreadable %d\n", expired_count, own_kept, unreadable);
}

int main(int argc, char **argv)
{
    if (argc < 3) {
        printf("usage: certstore-tool count|import|remove <certstore.db> ...\n");
        return 2;
    }
    if (sqlite3_open_v2(argv[2], &store, SQLITE_OPEN_READWRITE, NULL) != SQLITE_OK) {
        stop(argv[2]);
    }
    sqlite3_busy_timeout(store, 10000);
    printf("sqlite %s, objects before: %d\n", sqlite3_libversion(), count_objects());

    if (strcmp(argv[1], "import") == 0 && argc >= 4) {
        import_roots(argv[3], argc >= 5 ? argv[4] : NULL);
    } else if (strcmp(argv[1], "remove") == 0 && argc >= 4) {
        remove_roots(argv[3]);
    } else if (strcmp(argv[1], "list-expired") == 0) {
        handle_expired(0);
    } else if (strcmp(argv[1], "remove-expired") == 0) {
        handle_expired(1);
    } else if (strcmp(argv[1], "count") != 0) {
        printf("unknown command\n");
        sqlite3_close(store);
        return 2;
    }

    printf("objects now: %d\n", count_objects());
    sqlite3_close(store);
    return 0;
}
