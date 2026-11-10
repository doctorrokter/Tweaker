#include "RootScript.hpp"

#include <QFile>
#include <QTimer>

namespace bbshared {

namespace {

// The verdict is the last line of the output: result=<word>. None - an empty string.
QString verdictOf(const QString& output)
{
    const QStringList lines = output.split(QLatin1Char('\n'), QString::SkipEmptyParts);
    if (lines.isEmpty()) {
        return QString();
    }
    const QString last = lines.last().trimmed();
    if (!last.startsWith(QLatin1String("result="))) {
        return QString();
    }
    return last.mid(7);
}

QString quoted(const QString& text)
{
    return QLatin1Char('\'') + text + QLatin1Char('\'');
}

} // namespace

RootScript::RootScript(QObject* parent) :
        QObject(parent),
        m_process(0),
        m_timeout(new QTimer(this)),
        m_timedOut(false)
{
    m_timeout->setSingleShot(true);
    connect(m_timeout, SIGNAL(timeout()), this, SLOT(onTimeout()));
}

QString RootScript::findWrapper()
{
    const char* const wrappers[] = { "/base/bin/__root", "/bin/__root" };
    for (unsigned i = 0; i < sizeof(wrappers) / sizeof(wrappers[0]); ++i) {
        const QString path = QString::fromLatin1(wrappers[i]);
        if (QFile::exists(path)) {
            return path;
        }
    }
    return QString();
}

bool RootScript::isRunning() const
{
    return m_process != 0;
}

QString RootScript::errorString() const
{
    return m_error;
}

bool RootScript::start(const QString& script, const QStringList& arguments, int timeoutMs)
{
    if (m_process != 0) {
        m_error = QString::fromLatin1("a script is running already");
        return false;
    }
    m_wrapper = findWrapper();
    if (m_wrapper.isEmpty()) {
        m_error = QString::fromLatin1("no root wrapper on this phone (/base/bin/__root, /bin/__root)");
        return false;
    }
    if (script.isEmpty() || script.contains(QLatin1Char('\''))) {
        m_error = QString::fromLatin1("the script is not in the package, or its path cannot be quoted: %1").arg(script);
        return false;
    }

    QString command = QString::fromLatin1("/bin/ksh -s");
    for (int i = 0; i < arguments.size(); ++i) {
        if (arguments.at(i).contains(QLatin1Char('\''))) {
            m_error = QString::fromLatin1("an argument cannot be quoted: %1").arg(arguments.at(i));
            return false;
        }
        command += QLatin1Char(' ') + quoted(arguments.at(i));
    }
    command += QString::fromLatin1(" < ") + quoted(script) + QLatin1Char('\n');

    m_timedOut = false;
    m_process = new QProcess(this);
    m_process->setProcessChannelMode(QProcess::MergedChannels);
    connect(m_process, SIGNAL(error(QProcess::ProcessError)), this, SLOT(onProcessError(QProcess::ProcessError)));
    connect(m_process, SIGNAL(finished(int, QProcess::ExitStatus)), this, SLOT(onProcessFinished()));
    m_timeout->start(timeoutMs);

    m_process->start(m_wrapper, QStringList(), QIODevice::ReadWrite);
    m_process->write(command.toLocal8Bit());
    m_process->closeWriteChannel();
    return true;
}

void RootScript::onProcessError(QProcess::ProcessError error)
{
    // Only a process that never started: every other error ends in finished() too.
    if (error != QProcess::FailedToStart || m_process == 0) {
        return;
    }
    finish(QString(), QString::fromLatin1("%1 did not start: %2").arg(m_wrapper, m_process->errorString()));
}

void RootScript::onTimeout()
{
    if (m_process == 0) {
        return;
    }
    m_timedOut = true;
    m_process->kill();      // finished() follows
}

void RootScript::onProcessFinished()
{
    if (m_process == 0) {
        return;
    }
    const QString output = QString::fromLocal8Bit(m_process->readAll());
    if (m_timedOut) {
        finish(QString(), QString::fromLatin1("%1 timed out; said: %2").arg(m_wrapper, output.simplified()));
        return;
    }
    finish(verdictOf(output), output);
}

void RootScript::finish(const QString& verdict, const QString& output)
{
    m_timeout->stop();
    m_process->deleteLater();
    m_process = 0;
    emit finished(verdict, output);
}

} // namespace bbshared
