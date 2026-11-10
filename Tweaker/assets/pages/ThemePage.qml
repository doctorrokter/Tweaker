import bb.cascades 1.4
import bb.shared 1.0

// The theme of the Hub and of the rest of the system, each on its own (core/SystemTheme). Anything that went wrong stays on screen
// in red, as it is.
Page {
    id: root

    // A change that failed leaves the state as it was, and the control the user moved has to follow that too.
    property int finished: systemTheme.finishedCount

    onFinishedChanged: {
        hubControl.selectedIndex = systemTheme.hubDark ? 1 : 0;
        systemControl.selectedIndex = systemTheme.systemDark ? 1 : 0;
    }

    titleBar: TitleBar {
        title: qsTr("System theme") + Retranslate.onLocaleOrLanguageChanged
    }

    actionBarAutoHideBehavior: ActionBarAutoHideBehavior.HideOnScroll
    actionBarVisibility: ChromeVisibility.Overlay

    ScrollView {
        scrollRole: ScrollRole.Main

        Container {
            horizontalAlignment: HorizontalAlignment.Fill
            topPadding: ui.du(dimens.pad)
            leftPadding: ui.du(dimens.pad)
            rightPadding: ui.du(dimens.pad)
            bottomPadding: ui.du(15)

            Label {
                text: qsTr("Hub and email") + Retranslate.onLocaleOrLanguageChanged
                textStyle.base: SystemDefaults.TextStyles.PrimaryText
            }

            SegmentedControl {
                id: hubControl
                horizontalAlignment: HorizontalAlignment.Fill
                enabled: systemTheme.rootAvailable && ! systemTheme.busy

                Option {
                    text: qsTr("Light") + Retranslate.onLocaleOrLanguageChanged
                    selected: ! systemTheme.hubDark
                }

                Option {
                    text: qsTr("Dark") + Retranslate.onLocaleOrLanguageChanged
                    selected: systemTheme.hubDark
                }

                onSelectedIndexChanged: {
                    var wantDark = selectedIndex === 1;
                    if (wantDark !== systemTheme.hubDark) {
                        systemTheme.setHubDark(wantDark);
                    }
                }
            }

            Label {
                topMargin: ui.du(dimens.pad)
                text: qsTr("The rest of the system") + Retranslate.onLocaleOrLanguageChanged
                textStyle.base: SystemDefaults.TextStyles.PrimaryText
            }

            SegmentedControl {
                id: systemControl
                horizontalAlignment: HorizontalAlignment.Fill
                enabled: systemTheme.rootAvailable && ! systemTheme.busy

                Option {
                    text: qsTr("Light") + Retranslate.onLocaleOrLanguageChanged
                    selected: ! systemTheme.systemDark
                }

                Option {
                    text: qsTr("Dark") + Retranslate.onLocaleOrLanguageChanged
                    selected: systemTheme.systemDark
                }

                onSelectedIndexChanged: {
                    var wantDark = selectedIndex === 1;
                    if (wantDark !== systemTheme.systemDark) {
                        systemTheme.setSystemDark(wantDark);
                    }
                }
            }

            Loader {
                active: systemTheme.busy

                Container {
                    topMargin: ui.du(dimens.gap)

                    layout: StackLayout {
                        orientation: LayoutOrientation.LeftToRight
                    }

                    ActivityIndicator {
                        verticalAlignment: VerticalAlignment.Center
                        running: true
                    }

                    Label {
                        verticalAlignment: VerticalAlignment.Center
                        text: qsTr("Working...") + Retranslate.onLocaleOrLanguageChanged
                    }
                }
            }

            Loader {
                active: systemTheme.error !== ""

                Label {
                    topMargin: ui.du(dimens.gap)
                    multiline: true
                    text: systemTheme.error
                    textStyle.color: Color.Red
                }
            }
        }
    }
}
