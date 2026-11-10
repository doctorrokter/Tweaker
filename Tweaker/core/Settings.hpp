/*
 * Settings - what the app keeps for itself (the context property "settings"). The same language API as BBHealth's,
 * Syno's and Tunnel's, so their LanguageSettingsPage is used as is.
 *
 *   language          "system" | "en" | "ru" | ... - a code bb-shared L10n ships a catalog for
 *   lastSeenVersion   the app version "What's new" was last shown for
 */

#ifndef TWEAKER_SETTINGS_HPP_
#define TWEAKER_SETTINGS_HPP_

#include <QObject>
#include <QString>
#include <QVariantList>

namespace tweaker {

class Settings: public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(QString lastSeenVersion READ lastSeenVersion WRITE setLastSeenVersion NOTIFY lastSeenVersionChanged)
public:
    // The process's one instance, created on first use (parented to qApp).
    static Settings* instance();

    QString language() const { return m_language; }
    void setLanguage(const QString& language);
    QString lastSeenVersion() const { return m_lastSeenVersion; }
    void setLastSeenVersion(const QString& version);

    // [{ code, name }] - the languages the app ships a catalog for (bb-shared L10n).
    Q_INVOKABLE QVariantList supportedLanguages() const;
    // A language in its own name ("Русский").
    Q_INVOKABLE QString languageName(const QString& code) const;

Q_SIGNALS:
    void languageChanged(const QString& language);
    void lastSeenVersionChanged();

private:
    Settings();

    QString m_language;
    QString m_lastSeenVersion;
};

} // namespace tweaker

#endif /* TWEAKER_SETTINGS_HPP_ */
