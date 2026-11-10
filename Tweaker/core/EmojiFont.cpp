#include "EmojiFont.hpp"

#include "RootScript.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSettings>
#include <QTimer>
#include <QDebug>

namespace tweaker {

namespace {

const char* const kSystemFont = "/base/usr/fonts/font_repository/monotype/NotoColorEmoji.ttf";
const char* const kOurFont = "/var/addons/tweaker/fonts/NotoColorEmoji.ttf";
const char* const kEnabledKey = "emojiFont/enabled";
const char* const kCustomFileKey = "emojiFont/customFile";
const char* const kStyleKey = "emojiFont/style";
const char* const kStyleTelegram = "telegram";
const char* const kStyleNoto = "noto";

const int kScriptTimeoutMs = 120 * 1000;        // copies a font of up to kMaxFontBytes
const qint64 kMaxFontBytes = 64 * 1024 * 1024;

// The real path of a file of the package: the root shell runs outside our sandbox.
QString packageFile(const char* name)
{
    return QFileInfo(QDir::currentPath() + QString::fromLatin1("/app/native/") + QString::fromLatin1(name)).canonicalFilePath();
}

// The package's font of a built-in style.
const char* fontFileOfStyle(const QString& style)
{
    if (style == QLatin1String(kStyleNoto)) {
        return "emoji-noto.ttf";
    }
    return "emoji-telegram.ttf";
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

EmojiFont::EmojiFont(QObject* parent) :
        QObject(parent),
        m_script(new bbshared::RootScript(this)),
        m_action(NoAction),
        m_enabled(false),
        m_linked(false),
        m_finishedCount(0)
{
    connect(m_script, SIGNAL(finished(QString, QString)), this, SLOT(onScriptFinished(QString, QString)));

    QSettings settings;
    m_enabled = settings.value(QString::fromLatin1(kEnabledKey), false).toBool();
    m_customFileName = settings.value(QString::fromLatin1(kCustomFileKey)).toString();
    m_style = settings.value(QString::fromLatin1(kStyleKey), QString::fromLatin1(kStyleTelegram)).toString();
    refresh();

    if (!rootAvailable()) {
        m_error = tr("This phone has no root wrapper (__root): Tweaker cannot change anything here.");
        return;
    }
    // An update of the app brings a new boot script: it goes into place at the first start after the update.
    if (m_enabled) {
        QTimer::singleShot(0, this, SLOT(updateHook()));
    }
}

bool EmojiFont::rootAvailable() const
{
    return !bbshared::RootScript::findWrapper().isEmpty();
}

void EmojiFont::refresh()
{
    const QFileInfo systemFont(QString::fromLatin1(kSystemFont));
    bool linked = false;
    QString foreignLink;
    if (systemFont.isSymLink()) {
        const QString target = systemFont.symLinkTarget();
        if (target == QString::fromLatin1(kOurFont)) {
            linked = true;
        } else {
            foreignLink = target;
        }
    }
    if (linked != m_linked || foreignLink != m_foreignLink) {
        m_linked = linked;
        m_foreignLink = foreignLink;
        emit stateChanged();
    }
}

void EmojiFont::updateHook()
{
    const QString script = packageFile("tweaker-boot.sh");
    run(UpdatingHook, QStringList() << QString::fromLatin1("install") << script);
}

void EmojiFont::turnOn()
{
    turnOnWithStyle(m_style);
}

void EmojiFont::chooseStyle(const QString& style)
{
    if (m_enabled) {
        turnOnWithStyle(style);
        return;
    }
    m_style = style;
    QSettings().setValue(QString::fromLatin1(kStyleKey), m_style);
    emit stateChanged();
}

void EmojiFont::turnOnWithStyle(const QString& style)
{
    m_pendingCustomFileName.clear();
    m_pendingStyle = style;
    const QString script = packageFile("tweaker-boot.sh");
    run(TurningOn, QStringList() << QString::fromLatin1("font-on") << script << packageFile(fontFileOfStyle(style)));
}

void EmojiFont::turnOff()
{
    const QString script = packageFile("tweaker-boot.sh");
    run(TurningOff, QStringList() << QString::fromLatin1("font-off") << script);
}

void EmojiFont::useFile(const QString& path)
{
    const QString problem = checkFontFile(path);
    if (!problem.isEmpty()) {
        finishWithError(problem);
        return;
    }
    const QFileInfo file(path);
    m_pendingCustomFileName = file.fileName();
    m_pendingStyle = m_style;
    const QString script = packageFile("tweaker-boot.sh");
    run(TurningOn, QStringList() << QString::fromLatin1("font-on") << script << file.canonicalFilePath());
}

void EmojiFont::run(Action action, const QStringList& arguments)
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

void EmojiFont::onScriptFinished(const QString& verdict, const QString& output)
{
    const Action action = m_action;
    m_action = NoAction;
    const bool succeeded = verdict == QLatin1String("ok") || verdict == QLatin1String("same");

    if (action == UpdatingHook) {
        // Not the user's doing, and early after a boot root is not up yet: the next start of the app tries again.
        if (!succeeded) {
            qWarning() << "[emojiFont] the boot start was not updated:" << output.simplified();
        }
        emit stateChanged();
        return;
    }

    if (!succeeded) {
        finishWithError(reasonOf(output));
        return;
    }

    QSettings settings;
    if (action == TurningOn) {
        m_enabled = true;
        m_customFileName = m_pendingCustomFileName;
        m_style = m_pendingStyle;
    } else {
        m_enabled = false;
        m_customFileName.clear();
    }
    settings.setValue(QString::fromLatin1(kEnabledKey), m_enabled);
    settings.setValue(QString::fromLatin1(kCustomFileKey), m_customFileName);
    settings.setValue(QString::fromLatin1(kStyleKey), m_style);

    refresh();
    m_finishedCount += 1;
    emit stateChanged();
}

void EmojiFont::finishWithError(const QString& problem)
{
    qWarning() << "[emojiFont]" << problem;
    m_error = problem;
    refresh();
    m_finishedCount += 1;
    emit stateChanged();
}

// What the system's engine draws: a TrueType file with colour bitmap tables. The rest it would show as nothing.
QString EmojiFont::checkFontFile(const QString& path) const
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return tr("Cannot open the file: %1").arg(file.errorString());
    }
    if (file.size() > kMaxFontBytes) {
        return tr("The file is too big for an emoji font: %1 MB").arg(file.size() / (1024 * 1024));
    }

    const QByteArray header = file.read(12);
    if (header.size() != 12 || header.left(4) != QByteArray("\0\1\0\0", 4)) {
        return tr("This is not a TrueType font file.");
    }
    const int tableCount = (static_cast<uchar>(header.at(4)) << 8) | static_cast<uchar>(header.at(5));
    const QByteArray directory = file.read(tableCount * 16);
    if (directory.size() != tableCount * 16) {
        return tr("This is not a TrueType font file.");
    }

    bool hasBitmapData = false;
    bool hasBitmapLocations = false;
    for (int i = 0; i < tableCount; ++i) {
        const QByteArray tag = directory.mid(i * 16, 4);
        if (tag == "CBDT") {
            hasBitmapData = true;
        } else if (tag == "CBLC") {
            hasBitmapLocations = true;
        }
    }
    if (!hasBitmapData || !hasBitmapLocations) {
        return tr("This font has no colour bitmaps (CBDT and CBLC tables), and the system draws no other emoji.");
    }
    return QString();
}

} // namespace tweaker
