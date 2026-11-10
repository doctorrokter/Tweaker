/*
 * SystemTheme - the light or dark theme of the phone (the context property "systemTheme"), in two parts that are set apart: the Hub
 * with email, and everything else that takes the system's theme. The work is boot/tweaker-boot.sh's, as root; the system forgets both
 * at every reboot, so the boot start sets them again.
 *
 * `systemDark` is what is really set, the system's defaultTheme. `hubDark` is the choice the script keeps for the boot start.
 */

#ifndef TWEAKER_SYSTEMTHEME_HPP_
#define TWEAKER_SYSTEMTHEME_HPP_

#include <QObject>
#include <QString>
#include <QStringList>

namespace bbshared {
    class RootScript;
}

namespace tweaker {

class SystemTheme: public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool rootAvailable READ rootAvailable CONSTANT)
    Q_PROPERTY(bool systemDark READ systemDark NOTIFY stateChanged)
    Q_PROPERTY(bool hubDark READ hubDark NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    // What went wrong last, as it is; "" for nothing.
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    // Counts finished changes: one that failed leaves the state as it was, and the controls have to follow that too.
    Q_PROPERTY(int finishedCount READ finishedCount NOTIFY stateChanged)
public:
    explicit SystemTheme(QObject* parent = 0);

    bool rootAvailable() const;
    bool systemDark() const { return m_systemDark; }
    bool hubDark() const { return m_hubDark; }
    bool busy() const { return m_action != NoAction; }
    QString error() const { return m_error; }
    int finishedCount() const { return m_finishedCount; }

    Q_INVOKABLE void setSystemDark(bool dark);
    Q_INVOKABLE void setHubDark(bool dark);

Q_SIGNALS:
    void stateChanged();

private Q_SLOTS:
    void updateHook();
    void onScriptFinished(const QString& verdict, const QString& output);

private:
    enum Action {
        NoAction,
        UpdatingHook,
        ChangingTheme
    };

    void run(Action action, const QStringList& arguments);
    void finishWithError(const QString& problem);
    void readState();

    bbshared::RootScript* m_script;
    Action m_action;
    bool m_systemDark;
    bool m_hubDark;
    QString m_error;
    int m_finishedCount;
};

} // namespace tweaker

#endif /* TWEAKER_SYSTEMTHEME_HPP_ */
