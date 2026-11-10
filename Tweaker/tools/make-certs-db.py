#!/usr/bin/env python3
#
# make-certs-db.py <folder of make-certs.sh>
#
# Writes into that folder mozilla.db, what Tweaker imports: the roots with the attributes the phone's certificate manager keeps
# for an imported certificate. Run with -I in WSL or on Linux.

import hashlib
import os
import sqlite3
import sys

SKI_OID = bytes([0x06, 0x03, 0x55, 0x1D, 0x0E])


def tlv(data, at):
    """The element at this offset: (tag, offset of its value, length of its value, offset after it)."""
    tag = data[at]
    size = data[at + 1]
    body = at + 2
    if size & 0x80:
        count = size & 0x7F
        size = int.from_bytes(data[body:body + count], "big")
        body += count
    return tag, body, size, body + size


def children(data, start, end):
    at = start
    while at < end:
        tag, body, size, after = tlv(data, at)
        yield tag, at, body, size, after
        at = after


def der_length(size):
    if size < 0x80:
        return bytes([size])
    encoded = size.to_bytes((size.bit_length() + 7) // 8, "big")
    return bytes([0x80 | len(encoded)]) + encoded


def parse(der):
    """What the certificate manager stores about a certificate, cut out of the certificate itself."""
    _, cert_body, cert_size, _ = tlv(der, 0)
    _, tbs_body, tbs_size, _ = tlv(der, cert_body)
    fields = list(children(der, tbs_body, tbs_body + tbs_size))
    if fields[0][0] == 0xA0:
        fields = fields[1:]
    serial = der[fields[0][1]:fields[0][4]]
    issuer = der[fields[2][1]:fields[2][4]]
    subject = der[fields[4][1]:fields[4][4]]

    subject_key_id = None
    for tag, at, body, size, after in fields[6:]:
        if tag != 0xA3:
            continue
        _, list_body, list_size, _ = tlv(der, body)
        for _, _, ext_body, ext_size, _ in children(der, list_body, list_body + list_size):
            if der[ext_body:ext_body + len(SKI_OID)] == SKI_OID:
                parts = list(children(der, ext_body, ext_body + ext_size))
                outer = parts[-1]
                _, inner_body, inner_size, _ = tlv(der, outer[2])
                subject_key_id = der[inner_body:inner_body + inner_size]

    inner = issuer + serial
    issuer_and_serial = b"\x30" + der_length(len(inner)) + inner

    return {
        "fingerprint": hashlib.sha1(der).digest(),
        "ias": issuer_and_serial,
        "issuer": issuer,
        "subject": subject,
        "skid": subject_key_id,
    }


def pem_to_der(path):
    import base64
    lines = open(path, "r").read().splitlines()
    return base64.b64decode("".join(line for line in lines if "CERTIFICATE" not in line))


def main():
    folder = sys.argv[1]

    output = os.path.join(folder, "mozilla.db")
    if os.path.exists(output):
        os.remove(output)
    db = sqlite3.connect(output)
    db.execute("create table Roots (der blob, fingerprint blob, ias blob, issuer blob, subject blob, skid blob, hash blob)")
    count = 0
    for line in open(os.path.join(folder, "index.txt")):
        sha1, subject_hash = line.split()
        der = pem_to_der(os.path.join(folder, "cert_%s.pem" % sha1))
        info = parse(der)
        db.execute("insert into Roots values (?,?,?,?,?,?,?)", (der, info["fingerprint"], info["ias"], info["issuer"], info["subject"], info["skid"], subject_hash.encode("ascii")))
        count += 1
    db.commit()
    db.close()
    print(count, "roots in mozilla.db")


if __name__ == "__main__":
    main()
