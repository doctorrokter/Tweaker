import bb.cascades 1.4

// The boot script's log: did the tweaks get applied when the phone started, and if not, why.
Page {
    id: root

    titleBar: TitleBar {
        title: qsTr("Boot log") + Retranslate.onLocaleOrLanguageChanged
    }

    actionBarAutoHideBehavior: ActionBarAutoHideBehavior.HideOnScroll
    actionBarVisibility: ChromeVisibility.Overlay

    actions: [
        ActionItem {
            title: qsTr("Refresh") + Retranslate.onLocaleOrLanguageChanged
            imageSource: "asset:///images/ic_reload.png"
            ActionBar.placement: ActionBarPlacement.OnBar

            shortcuts: [
                Shortcut {
                    key: "r"
                }
            ]

            onTriggered: {
                root.load();
            }
        }
    ]

    function load() {
        var text = app.bootLog();
        if (text === "") {
            logLabel.text = qsTr("Nothing yet: the log appears once a tweak is turned on.");
        } else {
            logLabel.text = text;
        }
    }

    onCreationCompleted: {
        root.load();
    }

    ScrollView {
        scrollRole: ScrollRole.Main

        Container {
            horizontalAlignment: HorizontalAlignment.Fill
            topPadding: ui.du(dimens.pad)
            leftPadding: ui.du(dimens.pad)
            rightPadding: ui.du(dimens.pad)
            bottomPadding: ui.du(15)

            Label {
                id: logLabel
                multiline: true
            }
        }
    }
}
