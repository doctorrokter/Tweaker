#include "Certificates.hpp"

#include "RootScript.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSet>
#include <QStringList>
#include <QTextStream>
#include <QTimer>
#include <QDebug>

#include <dirent.h>

namespace tweaker {

namespace {

// The stores the roots are imported into, as the certificate manager serves them: the user's, or the system's on a phone that has no
// user store yet. An app can read each by its own path.
const char* const kServedUserStore = "/var/certs/web_trusted@personal@certmgr";
const char* const kServedSystemStore = "/var/certs/rim_trusted@global@nto";

const int kScriptTimeoutMs = 120 * 1000;

// The real path of a file of the package: the root shell runs outside our sandbox.
QString packagePath(const char* name)
{
    return QFileInfo(QDir::currentPath() + QString::fromLatin1("/app/native/") + QString::fromLatin1(name)).canonicalFilePath();
}

// The names only: asking for each file's details would go to the certificate manager once per file.
void addFileNames(const char* path, QSet<QString>& names)
{
    DIR* folder = opendir(path);
    if (folder == NULL) {
        return;
    }
    struct dirent* entry = readdir(folder);
    while (entry != NULL) {
        names.insert(QString::fromLatin1(entry->d_name));
        entry = readdir(folder);
    }
    closedir(folder);
}

QSet<QString> servedFileNames()
{
    QSet<QString> names;
    addFileNames(kServedUserStore, names);
    addFileNames(kServedSystemStore, names);
    return names;
}

// The script's reason=<text> line; what it printed altogether when it has none.
QString reasonOf(const QString& output)
{
    const QStringList lines = output.split(QLatin1Char('\n'), QString::SkipEmptyParts);
    for (int i = 0; i < lines.size(); ++i) {
        if (lines.at(i).startsWith(QLatin1String("reason="))) {
            return lines.at(i).mid(7).trimmed();
        }
    }
    return output.simplified();
}

} // namespace

Certificates::Certificates(QObject* parent) :
        QObject(parent),
        m_script(new bbshared::RootScript(this)),
        m_upToDate(false),
        m_busy(false)
{
    connect(m_script, SIGNAL(finished(QString, QString)), this, SLOT(onScriptFinished(QString, QString)));

    if (!rootAvailable()) {
        m_error = tr("This phone has no root wrapper (__root): Tweaker cannot change anything here.");
    }
    QTimer::singleShot(0, this, SLOT(refresh()));
}

bool Certificates::rootAvailable() const
{
    return !bbshared::RootScript::findWrapper().isEmpty();
}

void Certificates::refresh()
{
    bool upToDate = false;
    QFile index(packagePath("certs/index.txt"));
    if (index.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QSet<QString> served = servedFileNames();
        int total = 0;
        int present = 0;
        QTextStream lines(&index);
        while (!lines.atEnd()) {
            const QString sha1 = lines.readLine().section(QLatin1Char(' '), 0, 0).trimmed();
            if (sha1.isEmpty()) {
                continue;
            }
            total += 1;
            if (served.contains(QString::fromLatin1("cert_") + sha1 + QString::fromLatin1(".pem"))) {
                present += 1;
            }
        }
        upToDate = total > 0 && present == total;
    }
    if (upToDate != m_upToDate) {
        m_upToDate = upToDate;
        emit stateChanged();
    }
}

void Certificates::updateCertificates()
{
    if (m_busy) {
        return;
    }
    const QString script = packagePath("tweaker-boot.sh");
    const QStringList arguments = QStringList() << QString::fromLatin1("certs-update") << script << packagePath("certs") << packagePath("certstore-tool");
    m_error.clear();
    if (!m_script->start(script, arguments, kScriptTimeoutMs)) {
        finishWithError(m_script->errorString());
        return;
    }
    m_busy = true;
    emit stateChanged();
}

void Certificates::onScriptFinished(const QString& verdict, const QString& output)
{
    m_busy = false;
    if (verdict != QLatin1String("ok") && verdict != QLatin1String("same")) {
        finishWithError(reasonOf(output));
        return;
    }
    refresh();
    emit stateChanged();
}

void Certificates::finishWithError(const QString& problem)
{
    qWarning() << "[certificates]" << problem;
    m_error = problem;
    refresh();
    emit stateChanged();
}

} // namespace tweaker
