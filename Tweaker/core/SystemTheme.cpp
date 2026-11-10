#include "SystemTheme.hpp"

#include "RootScript.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSettings>
#include <QTimer>
#include <QDebug>

namespace tweaker {

namespace {

const char* const kDeviceProperties = "/pps/services/deviceproperties";
const char* const kHubChoice = "/var/addons/tweaker/on/hub-theme";
const char* const kChangedKey = "systemTheme/changed";
const char* const kEmojiFontEnabledKey = "emojiFont/enabled";

const int kScriptTimeoutMs = 300 * 1000;        // the Hub's files, some 300 of them, are copied one by one

// The real path of a file of the package: the root shell runs outside our sandbox.
QString packagePath(const char* name)
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

bool systemThemeIsDark()
{
    QFile properties(QString::fromLatin1(kDeviceProperties));
    if (!properties.open(QIODevice::ReadOnly)) {
        qWarning() << "[theme] cannot read" << kDeviceProperties << properties.errorString();
        return false;
    }
    return properties.readAll().contains("defaultTheme::black");
}

bool hubIsChosenDark()
{
    QFile choice(QString::fromLatin1(kHubChoice));
    if (!choice.open(QIODevice::ReadOnly)) {
        return false;
    }
    return choice.readAll().trimmed() == "black";
}

} // namespace

SystemTheme::SystemTheme(QObject* parent) :
        QObject(parent),
        m_script(new bbshared::RootScript(this)),
        m_action(NoAction),
        m_systemDark(systemThemeIsDark()),
        m_hubDark(hubIsChosenDark()),
        m_finishedCount(0)
{
    connect(m_script, SIGNAL(finished(QString, QString)), this, SLOT(onScriptFinished(QString, QString)));

    if (!rootAvailable()) {
        m_error = tr("This phone has no root wrapper (__root): Tweaker cannot change anything here.");
        return;
    }
    // EmojiFont puts a new boot script in place when the font is on; with only this tweak in use, it is done here.
    QSettings settings;
    if (settings.value(QString::fromLatin1(kChangedKey), false).toBool()
            && !settings.value(QString::fromLatin1(kEmojiFontEnabledKey), false).toBool()) {
        QTimer::singleShot(0, this, SLOT(updateHook()));
    }
}

bool SystemTheme::rootAvailable() const
{
    return !bbshared::RootScript::findWrapper().isEmpty();
}

void SystemTheme::updateHook()
{
    run(UpdatingHook, QStringList() << QString::fromLatin1("install") << packagePath("tweaker-boot.sh"));
}

void SystemTheme::setSystemDark(bool dark)
{
    const QString theme = QString::fromLatin1(dark ? "black" : "white");
    run(ChangingTheme, QStringList() << QString::fromLatin1("system-theme") << packagePath("tweaker-boot.sh") << theme);
}

void SystemTheme::setHubDark(bool dark)
{
    const QString theme = QString::fromLatin1(dark ? "black" : "white");
    run(ChangingTheme, QStringList() << QString::fromLatin1("hub-theme") << packagePath("tweaker-boot.sh") << theme << packagePath("hub_icons"));
}

void SystemTheme::readState()
{
    m_systemDark = systemThemeIsDark();
    m_hubDark = hubIsChosenDark();
}

void SystemTheme::run(Action action, const QStringList& arguments)
{
    if (m_action != NoAction) {
        return;
    }
    if (!m_script->start(arguments.at(1), arguments, kScriptTimeoutMs)) {
        finishWithError(m_script->errorString());
        return;
    }
    m_action = action;
    if (action != UpdatingHook) {
        m_error.clear();
    }
    emit stateChanged();
}

void SystemTheme::onScriptFinished(const QString& verdict, const QString& output)
{
    const Action action = m_action;
    m_action = NoAction;
    const bool succeeded = verdict == QLatin1String("ok") || verdict == QLatin1String("same");

    if (action == UpdatingHook) {
        // Not the user's doing, and early after a boot root is not up yet: the next start of the app tries again.
        if (!succeeded) {
            qWarning() << "[theme] the boot start was not updated:" << output.simplified();
        }
        emit stateChanged();
        return;
    }

    if (!succeeded) {
        finishWithError(reasonOf(output));
        return;
    }

    QSettings().setValue(QString::fromLatin1(kChangedKey), true);
    readState();
    m_finishedCount += 1;
    emit stateChanged();
}

void SystemTheme::finishWithError(const QString& problem)
{
    qWarning() << "[theme]" << problem;
    m_error = problem;
    readState();
    m_finishedCount += 1;
    emit stateChanged();
}

} // namespace tweaker
