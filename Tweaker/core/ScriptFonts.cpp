#include "ScriptFonts.hpp"

#include "RootScript.hpp"

#include <bb/data/JsonDataAccess>

#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QSettings>
#include <QTimer>
#include <QDebug>

namespace tweaker {

namespace {

// One of the fonts, as the system's font folder sees it and as the boot script keeps it.
const char* const kSystemFont = "/base/usr/fonts/font_repository/monotype/NotoSansGothic-Regular.ttf";
const char* const kOurFont = "/var/addons/tweaker/script-fonts/NotoSansGothic-Regular.ttf";
const char* const kEnabledKey = "scriptFonts/enabled";
// When the app last turned the fonts on or off, ms since the epoch.
const char* const kAppliedAtKey = "scriptFonts/appliedAtMs";

const int kScriptTimeoutMs = 120 * 1000;        // copies 2.5 MB of fonts and remakes the eight lists

// The real path of a file or folder of the package: the system user's shell runs outside our sandbox.
QString packageFile(const char* name)
{
    return QFileInfo(QDir::currentPath() + QString::fromLatin1("/app/native/") + QString::fromLatin1(name)).canonicalFilePath();
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

ScriptFonts::ScriptFonts(QObject* parent) :
        QObject(parent),
        m_script(new bbshared::RootScript(this)),
        m_action(NoAction),
        m_enabled(false),
        m_linked(false),
        m_finishedCount(0),
        m_startedAtMs(QDateTime::currentMSecsSinceEpoch())
{
    connect(m_script, SIGNAL(finished(QString, QString)), this, SLOT(onScriptFinished(QString, QString)));

    QSettings settings;
    m_enabled = settings.value(QString::fromLatin1(kEnabledKey), false).toBool();
    refresh();

    bb::data::JsonDataAccess json;
    m_samples = json.load(packageFile("assets/scriptsamples.json")).toList();
    if (json.hasError()) {
        qWarning() << "[scriptFonts] the samples cannot be read:" << json.error().errorMessage();
    }

    if (!rootAvailable()) {
        m_error = tr("This phone has no root wrapper (__root): Tweaker cannot change anything here.");
        return;
    }
    // An update of the app brings a new boot script: it goes into place at the first start after the update.
    if (m_enabled) {
        QTimer::singleShot(0, this, SLOT(updateHook()));
    }
}

bool ScriptFonts::rootAvailable() const
{
    return !bbshared::RootScript::findWrapper().isEmpty();
}

bool ScriptFonts::needsReopen() const
{
    const qint64 appliedAtMs = QSettings().value(QString::fromLatin1(kAppliedAtKey), 0).toLongLong();
    return appliedAtMs > m_startedAtMs;
}

void ScriptFonts::refresh()
{
    const QFileInfo systemFont(QString::fromLatin1(kSystemFont));
    bool linked = false;
    if (systemFont.isSymLink() && systemFont.symLinkTarget() == QString::fromLatin1(kOurFont)) {
        linked = true;
    }
    if (linked != m_linked) {
        m_linked = linked;
        emit stateChanged();
    }
}

void ScriptFonts::updateHook()
{
    const QString script = packageFile("tweaker-boot.sh");
    run(UpdatingHook, QStringList() << QString::fromLatin1("install") << script);
}

void ScriptFonts::turnOn()
{
    const QString script = packageFile("tweaker-boot.sh");
    run(TurningOn, QStringList() << QString::fromLatin1("scripts-on") << script << packageFile("scriptfonts"));
}

void ScriptFonts::turnOff()
{
    const QString script = packageFile("tweaker-boot.sh");
    run(TurningOff, QStringList() << QString::fromLatin1("scripts-off") << script);
}

void ScriptFonts::run(Action action, const QStringList& arguments)
{
    if (m_action != NoAction) {
        return;
    }
    const QString script = arguments.at(1);
    if (!m_script->start(script, arguments, kScriptTimeoutMs)) {
        finishWithError(m_script->errorString());
        return;
    }
    m_action = action;
    if (action != UpdatingHook) {
        m_error.clear();
    }
    emit stateChanged();
}

void ScriptFonts::onScriptFinished(const QString& verdict, const QString& output)
{
    const Action action = m_action;
    m_action = NoAction;
    const bool succeeded = verdict == QLatin1String("ok") || verdict == QLatin1String("same");

    if (action == UpdatingHook) {
        // Not the user's doing, and early after a boot the system user is not up yet: the next start of the app tries again.
        if (!succeeded) {
            qWarning() << "[scriptFonts] the boot start was not updated:" << output.simplified();
        }
        emit stateChanged();
        return;
    }

    if (!succeeded) {
        finishWithError(reasonOf(output));
        return;
    }

    if (action == TurningOn) {
        m_enabled = true;
    } else {
        m_enabled = false;
    }
    QSettings settings;
    settings.setValue(QString::fromLatin1(kEnabledKey), m_enabled);
    settings.setValue(QString::fromLatin1(kAppliedAtKey), QDateTime::currentMSecsSinceEpoch());

    refresh();
    m_finishedCount += 1;
    emit stateChanged();
}

void ScriptFonts::finishWithError(const QString& problem)
{
    qWarning() << "[scriptFonts]" << problem;
    m_error = problem;
    refresh();
    m_finishedCount += 1;
    emit stateChanged();
}

} // namespace tweaker
