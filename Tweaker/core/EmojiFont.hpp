/*
 * EmojiFont - the first tweak: a modern emoji font over the system's 2012 one, in every app (the context property
 * "emojiFont"; bb-shared/BB10-SYSTEM-EMOJI.md). The app only asks: the work is boot/tweaker-boot.sh's, as root.
 *
 * The state on screen comes from what is really there - the system font's path being a link, and to where. `enabled`
 * is what the user asked for, kept in QSettings: the link can be missing for a while after a boot.
 */

#ifndef TWEAKER_EMOJIFONT_HPP_
#define TWEAKER_EMOJIFONT_HPP_

#include <QObject>
#include <QString>
#include <QStringList>

namespace bbshared {
    class RootScript;
}

namespace tweaker {

class EmojiFont: public QObject
{
    Q_OBJECT
    // The phone has the root wrapper. Without it nothing can be changed, and `error` says so.
    Q_PROPERTY(bool rootAvailable READ rootAvailable CONSTANT)
    Q_PROPERTY(bool enabled READ enabled NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    // Our link is over the system's font right now.
    Q_PROPERTY(bool linked READ linked NOTIFY stateChanged)
    // Where someone else's link over the system's font goes (a boot loader's); "" for none.
    Q_PROPERTY(QString foreignLink READ foreignLink NOTIFY stateChanged)
    // The built-in style chosen: "telegram" (the default) or "noto".
    Q_PROPERTY(QString style READ style NOTIFY stateChanged)
    // The user's own font file in use; "" for a built-in style.
    Q_PROPERTY(QString customFileName READ customFileName NOTIFY stateChanged)
    // What went wrong last, as it is; "" for nothing.
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    // Counts finished changes: one that failed leaves `enabled` as it was, and the toggle has to follow that too.
    Q_PROPERTY(int finishedCount READ finishedCount NOTIFY stateChanged)
public:
    explicit EmojiFont(QObject* parent = 0);

    bool rootAvailable() const;
    bool enabled() const { return m_enabled; }
    bool busy() const { return m_action != NoAction; }
    bool linked() const { return m_linked; }
    QString foreignLink() const { return m_foreignLink; }
    QString style() const { return m_style; }
    QString customFileName() const { return m_customFileName; }
    QString error() const { return m_error; }
    int finishedCount() const { return m_finishedCount; }

    Q_INVOKABLE void turnOn();
    Q_INVOKABLE void turnOff();
    // A built-in style: applied at once when the tweak is on, kept for when it is turned on otherwise.
    Q_INVOKABLE void chooseStyle(const QString& style);
    // A font file of the user's instead of a built-in style; turns the tweak on.
    Q_INVOKABLE void useFile(const QString& path);
    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void stateChanged();

private Q_SLOTS:
    void updateHook();
    void onScriptFinished(const QString& verdict, const QString& output);

private:
    enum Action {
        NoAction,
        UpdatingHook,
        TurningOn,
        TurningOff
    };

    void run(Action action, const QStringList& arguments);
    void turnOnWithStyle(const QString& style);
    void finishWithError(const QString& problem);
    QString checkFontFile(const QString& path) const;

    bbshared::RootScript* m_script;
    Action m_action;
    bool m_enabled;
    bool m_linked;
    QString m_foreignLink;
    QString m_style;
    QString m_pendingStyle;
    QString m_customFileName;
    QString m_pendingCustomFileName;
    QString m_error;
    int m_finishedCount;
};

} // namespace tweaker

#endif /* TWEAKER_EMOJIFONT_HPP_ */
