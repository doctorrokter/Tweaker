/*
 * ScriptFonts - fonts for letters of rare alphabets (Gothic, Tai Le, Cherokee, Yi, math letters and the like, the
 * context property "scriptFonts"): names written with them draw as empty boxes on the stock system. Small Noto fonts
 * (SIL OFL, scriptfonts/ in the package) go into the system's composite font lists, the same way as the emoji font
 * (docs/TWEAKS.md). The app only asks: the work is boot/tweaker-boot.sh's, as the system user.
 *
 * `enabled` is what the user asked for, kept in QSettings; `linked` is what is really there - one of the fonts'
 * paths in the system's font folder being our link.
 */

#ifndef TWEAKER_SCRIPTFONTS_HPP_
#define TWEAKER_SCRIPTFONTS_HPP_

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>

namespace bbshared {
    class RootScript;
}

namespace tweaker {

class ScriptFonts: public QObject
{
    Q_OBJECT
    // The phone has the kit's wrapper. Without it nothing can be changed, and `error` says so.
    Q_PROPERTY(bool rootAvailable READ rootAvailable CONSTANT)
    Q_PROPERTY(bool enabled READ enabled NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    // Our fonts are in the system's font folder right now.
    Q_PROPERTY(bool linked READ linked NOTIFY stateChanged)
    // What went wrong last, as it is; "" for nothing.
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    // Counts finished changes: one that failed leaves `enabled` as it was, and the toggle has to follow that too.
    Q_PROPERTY(int finishedCount READ finishedCount NOTIFY stateChanged)
    // The fonts were turned on or off after this process started. Every Cascades app takes the character lists from the
    // Cascades host it was started from, so this one draws the letters only once it is closed and opened again.
    Q_PROPERTY(bool needsReopen READ needsReopen NOTIFY stateChanged)
    // How many scripts and symbol sets the fonts add (assets/scriptsamples.json, made by tools/script-fonts.js).
    Q_PROPERTY(int sampleCount READ sampleCount CONSTANT)
public:
    explicit ScriptFonts(QObject* parent = 0);

    bool rootAvailable() const;
    bool enabled() const { return m_enabled; }
    bool busy() const { return m_action != NoAction; }
    bool linked() const { return m_linked; }
    QString error() const { return m_error; }
    int finishedCount() const { return m_finishedCount; }
    bool needsReopen() const;
    int sampleCount() const { return m_samples.size(); }

    Q_INVOKABLE void turnOn();
    Q_INVOKABLE void turnOff();
    Q_INVOKABLE void refresh();
    // Each script with a few of its letters: maps of "name" and "sample", for the "What it adds" page.
    Q_INVOKABLE QVariantList samples() const { return m_samples; }

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
    void finishWithError(const QString& problem);

    bbshared::RootScript* m_script;
    Action m_action;
    bool m_enabled;
    bool m_linked;
    QString m_error;
    int m_finishedCount;
    qint64 m_startedAtMs;
    QVariantList m_samples;
};

} // namespace tweaker

#endif /* TWEAKER_SCRIPTFONTS_HPP_ */
