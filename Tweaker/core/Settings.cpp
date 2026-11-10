#include "Settings.hpp"

#include "L10n.hpp"

#include <QCoreApplication>
#include <QSettings>

namespace tweaker {

namespace {

const char* const kLanguage = "settings/language";
const char* const kLastSeenVersion = "settings/lastSeenVersion";

} // namespace

Settings* Settings::instance()
{
    static Settings* one = 0;
    if (one == 0) {
        one = new Settings();
        one->setParent(QCoreApplication::instance());
    }
    return one;
}

Settings::Settings() :
        QObject(0)
{
    QSettings settings;
    m_language = settings.value(QString::fromLatin1(kLanguage), QString::fromLatin1("system")).toString();
    m_lastSeenVersion = settings.value(QString::fromLatin1(kLastSeenVersion)).toString();
}

void Settings::setLanguage(const QString& language)
{
    if (language == m_language) {
        return;
    }
    m_language = language;
    QSettings().setValue(QString::fromLatin1(kLanguage), language);
    emit languageChanged(language);
}

void Settings::setLastSeenVersion(const QString& version)
{
    if (version == m_lastSeenVersion) {
        return;
    }
    m_lastSeenVersion = version;
    QSettings().setValue(QString::fromLatin1(kLastSeenVersion), version);
    emit lastSeenVersionChanged();
}

QVariantList Settings::supportedLanguages() const
{
    return bbshared::L10n::languages();
}

QString Settings::languageName(const QString& code) const
{
    return bbshared::L10n::nativeNameFor(code);
}

} // namespace tweaker
