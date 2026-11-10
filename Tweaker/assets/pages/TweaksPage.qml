import bb.cascades 1.4
import "../shared"

// The app's first page: one row per tweak, each pushing its own page (main.qml wires the signals).
Page {
    id: root

    signal emojiFontRequested()
    signal certificatesRequested()
    signal themeRequested()

    titleBar: TitleBar {
        title: "Tweaker"
    }

    actionBarAutoHideBehavior: ActionBarAutoHideBehavior.HideOnScroll
    actionBarVisibility: ChromeVisibility.Overlay

    function stateName(enabled) {
        if (enabled) {
            return qsTr("On");
        }
        return qsTr("Off");
    }

    function certificatesStateName(upToDate) {
        if (upToDate) {
            return qsTr("Up to date");
        }
        return qsTr("Not updated");
    }

    function themeStateName(hubDark, systemDark) {
        if (hubDark && systemDark) {
            return qsTr("Dark");
        }
        if (! hubDark && ! systemDark) {
            return qsTr("Light");
        }
        if (hubDark) {
            return qsTr("Hub dark, the rest light");
        }
        return qsTr("Hub light, the rest dark");
    }

    ScrollView {
        scrollRole: ScrollRole.Main

        Container {
            horizontalAlignment: HorizontalAlignment.Fill
            bottomPadding: ui.du(15)

            SettingsItem {
                title: qsTr("Emoji font") + Retranslate.onLocaleOrLanguageChanged
                description: root.stateName(emojiFont.enabled) + Retranslate.onLocaleOrLanguageChanged
                imageSource: "asset:///images/ic_emoji.png"
                onTapped: {
                    root.emojiFontRequested();
                }
            }

            SettingsItem {
                title: qsTr("Certificates") + Retranslate.onLocaleOrLanguageChanged
                description: root.certificatesStateName(certificates.upToDate) + Retranslate.onLocaleOrLanguageChanged
                imageSource: "asset:///images/ic_lock.png"
                onTapped: {
                    root.certificatesRequested();
                }
            }

            SettingsItem {
                title: qsTr("System theme") + Retranslate.onLocaleOrLanguageChanged
                description: root.themeStateName(systemTheme.hubDark, systemTheme.systemDark) + Retranslate.onLocaleOrLanguageChanged
                imageSource: "asset:///images/ic_theme.png"
                onTapped: {
                    root.themeRequested();
                }
            }
        }
    }
}
