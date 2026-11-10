/*
 * bb-shared / root / RootScript.hpp - runs a shell script of the app's package as root, through the root
 * wrapper of a rooted phone (BB10-ROOT-AUTOSTART.md, section 4). CONFIG += bb_shared_root.
 *
 *     m_script = new bbshared::RootScript(this);
 *     connect(m_script, SIGNAL(finished(QString, QString)), this, SLOT(onDone(QString, QString)));
 *     if (!m_script->start(pathOfScript, QStringList() << "install" << pathOfScript, 60 * 1000)) {
 *         qWarning() << m_script->errorString();
 *     }
 *
 * The script is fed to a shell on stdin. `/bin/ksh -s <arguments> < <script>`, so what it starts must not read
 * stdin (give those tools < /dev/null). Its last line of output is the verdict, `result=<word>`:
 * finished() brings the word, "" when the last line is anything else, with everything the script printed.
 *
 * The script's path must be the real one (QFileInfo::canonicalFilePath): the shell runs outside the sandbox.
 * A path or an argument with a ' in it cannot be quoted and is refused.
 */

#ifndef BBSHARED_ROOTSCRIPT_HPP_
#define BBSHARED_ROOTSCRIPT_HPP_

#include <QObject>
#include <QProcess>
#include <QString>
#include <QStringList>

class QTimer;

namespace bbshared {

class RootScript: public QObject
{
    Q_OBJECT
public:
    explicit RootScript(QObject* parent = 0);

    // The phone has the wrapper the app can run: "" when it has none.
    static QString findWrapper();

    bool isRunning() const;

    // Starts the script: true, and finished() follows. False - nothing was started, errorString() says why.
    bool start(const QString& script, const QStringList& arguments, int timeoutMs);
    QString errorString() const;

Q_SIGNALS:
    // verdict: the word of the last line `result=<word>`; "" when there is no such line (a wrapper that could
    // not run, a time-out, a script that died) - output then says what happened.
    void finished(const QString& verdict, const QString& output);

private Q_SLOTS:
    void onProcessError(QProcess::ProcessError error);
    void onProcessFinished();
    void onTimeout();

private:
    void finish(const QString& verdict, const QString& output);

    QProcess* m_process;
    QTimer* m_timeout;
    QString m_wrapper;
    QString m_error;
    bool m_timedOut;
};

} // namespace bbshared

#endif /* BBSHARED_ROOTSCRIPT_HPP_ */
