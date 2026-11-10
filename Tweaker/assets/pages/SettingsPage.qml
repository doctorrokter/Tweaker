/*
 * SettingsPage - the settings hub, pushed from the app menu: one row per group, each pushing its own page onto the
 * same stack (main.qml wires the signals below). The shape of BBTelega's, BBHealth's, Syno's and Tunnel's hubs.
 */
import bb.cascades 1.4
import "../shared"

Page {
    id: root

    // main.qml keeps the app menu off while the settings are open (one hub at a time).
    objectName: "settings"

    signal languageSettingsRequested()
    signal bootLogRequested()

    actionBarAutoHideBehavior: ActionBarAutoHideBehavior.HideOnScroll
    actionBarVisibility: ChromeVisibility.Overlay

    titleBar: TitleBar {
        title: qsTr("Settings") + Retranslate.onLocaleOrLanguageChanged
    }

    ScrollView {
        scrollRole: ScrollRole.Main

        Container {
            horizontalAlignment: HorizontalAlignment.Fill
            bottomPadding: ui.du(15)

            SettingsItem {
                title: qsTr("Language") + Retranslate.onLocaleOrLanguageChanged
                // The current choice: "System" translated, a language in its own name from the L10n registry.
                description: (settings.language === "system"
                        ? qsTr("System")
                        : settings.languageName(settings.language)) + Retranslate.onLocaleOrLanguageChanged
                imageSource: "asset:///images/ic_sb_network.png"
                onTapped: {
                    root.languageSettingsRequested();
                }
            }

            SettingsItem {
                title: qsTr("Boot log") + Retranslate.onLocaleOrLanguageChanged
                description: qsTr("What Tweaker did when the phone started") + Retranslate.onLocaleOrLanguageChanged
                imageSource: "asset:///images/ic_diagnostics.png"
                onTapped: {
                    root.bootLogRequested();
                }
            }
        }
    }
}
