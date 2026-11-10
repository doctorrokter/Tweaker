import bb.cascades 1.4
import "pages"
import "sheets"

// The list of tweaks at the bottom of the stack, a tweak's page above it, the settings hub from the app menu
// (docs/TWEAKS.md). The menu's pages and sheets are created on open and destroyed once closed.
NavigationPane {
    id: root

    // The settings hub is on the stack: the app menu stays off meanwhile (one hub at a time).
    property bool settingsOpen: false
    // The app menu's sheets while they are up. Held here because createObject() gives them no parent. Qt 4.8 reads an
    // unset `variant` back as undefined, so they are tested for truthiness, never against null.
    property variant helpSheetObj
    property variant changelogSheetObj

    Menu.definition: MenuDefinition {
        settingsAction: SettingsActionItem {
            onTriggered: {
                root.openSettings();
            }
        }

        helpAction: HelpActionItem {
            onTriggered: {
                root.openHelpSheet();
            }
        }

        actions: [
            ActionItem {
                title: qsTr("What's new") + Retranslate.onLocaleOrLanguageChanged
                imageSource: "asset:///images/ic_doctype_generic.png"
                onTriggered: {
                    root.openChangelogSheet(changelog.all());
                }
            }
        ]
    }

    TweaksPage {
        onEmojiFontRequested: {
            root.push(emojiFontDef.createObject());
        }
        onCertificatesRequested: {
            root.push(certificatesDef.createObject());
        }
        onThemeRequested: {
            root.push(themeDef.createObject());
        }
    }

    attachedObjects: [
        ComponentDefinition {
            id: emojiFontDef
            EmojiFontPage {
            }
        },
        ComponentDefinition {
            id: certificatesDef
            CertificatesPage {
            }
        },
        ComponentDefinition {
            id: themeDef
            ThemePage {
            }
        },
        ComponentDefinition {
            id: settingsDef
            SettingsPage {
                onLanguageSettingsRequested: {
                    root.push(languageDef.createObject());
                }
                onBootLogRequested: {
                    root.push(bootLogDef.createObject());
                }
            }
        },
        ComponentDefinition {
            id: languageDef
            LanguageSettingsPage {
            }
        },
        ComponentDefinition {
            id: bootLogDef
            BootLogPage {
            }
        },
        ComponentDefinition {
            id: helpSheetDef
            HelpSheet {
            }
        },
        ComponentDefinition {
            id: changelogSheetDef
            ChangelogSheet {
            }
        }
    ]

    onPopTransitionEnded: {
        if (page.objectName === "settings") {
            root.settingsOpen = false;
            root.syncMenu();
        }
        page.destroy();
    }

    onCreationCompleted: {
        root.syncMenu();
        root.recordVersion();
    }

    // "What's new" once per upgrade; a fresh install only records the version.
    function recordVersion() {
        var current = Application.applicationVersion;
        var lastSeen = settings.lastSeenVersion;
        if (lastSeen === "") {
            settings.lastSeenVersion = current;
        } else if (lastSeen !== current) {
            var entries = changelog.since(lastSeen);
            settings.lastSeenVersion = current;
            if (entries.length > 0) {
                root.openChangelogSheet(entries);
            }
        }
    }

    function openHelpSheet() {
        if (root.helpSheetObj) {
            return;
        }
        root.helpSheetObj = helpSheetDef.createObject();
        if (root.helpSheetObj) {
            root.helpSheetObj.closed.connect(root.helpSheetClosed);
            root.helpSheetObj.open();
        }
    }

    function helpSheetClosed() {
        var sheet = root.helpSheetObj;
        root.helpSheetObj = null;
        if (sheet) {
            sheet.destroy();
        }
    }

    // ENTRIES: the changelog to show - all of it from the menu, what is newer than the version last seen on an upgrade.
    function openChangelogSheet(entries) {
        if (root.changelogSheetObj) {
            root.changelogSheetObj.entries = entries;
            return;
        }
        root.changelogSheetObj = changelogSheetDef.createObject();
        if (root.changelogSheetObj) {
            root.changelogSheetObj.entries = entries;
            root.changelogSheetObj.closed.connect(root.changelogSheetClosed);
            root.changelogSheetObj.open();
        }
    }

    function changelogSheetClosed() {
        var sheet = root.changelogSheetObj;
        root.changelogSheetObj = null;
        if (sheet) {
            sheet.destroy();
        }
    }

    function openSettings() {
        if (root.settingsOpen) {
            return;
        }
        root.settingsOpen = true;
        root.syncMenu();
        root.push(settingsDef.createObject());
    }

    function syncMenu() {
        Application.menuEnabled = ! root.settingsOpen;
    }
}
