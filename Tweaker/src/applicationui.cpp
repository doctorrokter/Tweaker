/*
 * Copyright (c) 2011-2015 BlackBerry Limited.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "applicationui.hpp"
#include "BbSharedDimens.hpp"
#include "BbSharedUi.hpp"
#include "L10n.hpp"
#include "Certificates.hpp"
#include "Changelog.hpp"
#include "EmojiFont.hpp"
#include "Settings.hpp"
#include "SystemTheme.hpp"

#include <bb/cascades/Application>
#include <bb/cascades/QmlDocument>
#include <bb/cascades/AbstractPane>
#include <bb/cascades/LocaleHandler>

#include <QDeclarativeContext>
#include <QDeclarativeEngine>
#include <QFile>
#include <QTranslator>
#include <QDebug>

// Only the cascades namespace is opened: L10n.hpp brings in bb::system::LocaleHandler, so with bb::system open as well
// a bare LocaleHandler would be ambiguous.
using namespace bb::cascades;

ApplicationUI::ApplicationUI() :
        QObject(),
        m_pTranslator(new QTranslator(this)),
        m_pLocaleHandler(new LocaleHandler(this))
{
    // Language layer first: the shared L10n module builds its language map from the shipped Tweaker_<code>.qm files
    // (English is the source language and ships none).
    bbshared::L10n::init(QString::fromLatin1("Tweaker"));

    tweaker::Settings* settings = tweaker::Settings::instance();

    // The language follows the setting (Settings > Language), and with "system" the device, live.
    bool ok = QObject::connect(m_pLocaleHandler, SIGNAL(systemLanguageChanged()), this, SLOT(onSystemLanguageChanged()));
    Q_ASSERT(ok);
    ok = QObject::connect(settings, SIGNAL(languageChanged(QString)), this, SLOT(onSystemLanguageChanged()));
    Q_ASSERT(ok);
    Q_UNUSED(ok);

    // initial load
    onSystemLanguageChanged();

    // bb-shared's QML types (import bb.shared 1.0): Loader, the Help sheet coffee card's SharedClipboard.
    bbshared::registerUiTypes();

    // On the engine's ROOT context, not the document's: only those stay live inside list rows, sheets and pushed pages
    // (KB 1.14).
    QDeclarativeContext* context = QmlDocument::defaultDeclarativeEngine()->rootContext();
    context->setContextProperty("app", this);
    // The spacing of every app's service pages.
    bbshared::installDimensContext(context);
    context->setContextProperty("settings", settings);
    context->setContextProperty("changelog", new tweaker::Changelog(this));
    context->setContextProperty("emojiFont", new tweaker::EmojiFont(this));
    context->setContextProperty("certificates", new tweaker::Certificates(this));
    context->setContextProperty("systemTheme", new tweaker::SystemTheme(this));

    QmlDocument *qml = QmlDocument::create("asset:///main.qml").parent(this);
    AbstractPane *root = qml->createRootObject<AbstractPane>();
    Application::instance()->setScene(root);
}

void ApplicationUI::onSystemLanguageChanged()
{
    const QString language = bbshared::L10n::installTranslator(m_pTranslator, tweaker::Settings::instance()->language());
    qDebug() << "[tweaker] translator loaded for" << language;
}

QString ApplicationUI::bootLog() const
{
    QFile log(QString::fromLatin1("/accounts/1000/shared/misc/tweaker-boot.txt"));
    if (!log.exists()) {
        return QString();
    }
    if (!log.open(QIODevice::ReadOnly)) {
        return log.errorString();
    }
    const qint64 lastPartBytes = 32 * 1024;
    if (log.size() > lastPartBytes) {
        log.seek(log.size() - lastPartBytes);
    }
    return QString::fromUtf8(log.readAll());
}
