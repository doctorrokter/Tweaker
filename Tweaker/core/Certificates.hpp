/*
 * Certificates - brings the phone's root certificates up to date (the context property "certificates"). Mozilla's list goes into
 * the certificate manager's own store and the expired roots come out of the system's; the work is boot/tweaker-boot.sh's, as root.
 * What is written stays: after a reboot and without Tweaker.
 *
 * `upToDate` is what is really there: every root of the package being in a store the certificate manager serves.
 */

#ifndef TWEAKER_CERTIFICATES_HPP_
#define TWEAKER_CERTIFICATES_HPP_

#include <QObject>
#include <QString>

namespace bbshared {
    class RootScript;
}

namespace tweaker {

class Certificates: public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool rootAvailable READ rootAvailable CONSTANT)
    Q_PROPERTY(bool upToDate READ upToDate NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    // What went wrong last, as it is; "" for nothing.
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
public:
    explicit Certificates(QObject* parent = 0);

    bool rootAvailable() const;
    bool upToDate() const { return m_upToDate; }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }

    Q_INVOKABLE void updateCertificates();

Q_SIGNALS:
    void stateChanged();

private Q_SLOTS:
    void refresh();
    void onScriptFinished(const QString& verdict, const QString& output);

private:
    void finishWithError(const QString& problem);

    bbshared::RootScript* m_script;
    bool m_upToDate;
    bool m_busy;
    QString m_error;
};

} // namespace tweaker

#endif /* TWEAKER_CERTIFICATES_HPP_ */
