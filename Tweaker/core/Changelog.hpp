/*
 * Changelog - the release notes behind "What's new", read from assets/changelog[_<lang>].json and exposed to QML
 * as `changelog`. BBHealth's class (the reference) by way of Tunnel's.
 *
 * The JSON is a newest-first array of { version, date, changes: [..] }. On startup main.qml compares the app version
 * with Settings::lastSeenVersion and, when it changed, shows ChangelogSheet with everything newer (since()). A fresh
 * install shows nothing.
 */

#ifndef TWEAKER_CHANGELOG_HPP_
#define TWEAKER_CHANGELOG_HPP_

#include <QObject>
#include <QString>
#include <QVariantList>

namespace tweaker {

class Changelog: public QObject
{
    Q_OBJECT
public:
    explicit Changelog(QObject* parent = 0);

    // All release entries, newest first.
    Q_INVOKABLE QVariantList all() const;
    // Entries strictly newer than fromVersion (empty fromVersion -> nothing).
    Q_INVOKABLE QVariantList since(const QString& fromVersion) const;

private Q_SLOTS:
    // Re-read for the current language (wired to Settings::languageChanged).
    void reload();

private:
    void load();
    // Compares dotted version strings ("1.2.0"): -1 / 0 / +1.
    static int compareVersions(const QString& a, const QString& b);

    QVariantList m_entries;
};

} // namespace tweaker

#endif /* TWEAKER_CHANGELOG_HPP_ */
