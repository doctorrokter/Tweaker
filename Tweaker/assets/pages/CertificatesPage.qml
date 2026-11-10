import bb.cascades 1.4
import bb.shared 1.0

// Brings the phone's root certificates up to date (core/Certificates). Anything that went wrong stays on screen in red, as it is.
Page {
    id: root

    titleBar: TitleBar {
        title: qsTr("Certificates") + Retranslate.onLocaleOrLanguageChanged
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
                multiline: true
                text: (certificates.upToDate ? qsTr("Up to date") : qsTr("Not updated")) + Retranslate.onLocaleOrLanguageChanged
                textStyle.fontWeight: FontWeight.W500
            }

            Button {
                topMargin: ui.du(dimens.gap)
                horizontalAlignment: HorizontalAlignment.Fill
                text: qsTr("Update certificates") + Retranslate.onLocaleOrLanguageChanged
                enabled: certificates.rootAvailable && ! certificates.busy

                onClicked: {
                    certificates.updateCertificates();
                }
            }

            Loader {
                active: certificates.busy

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
                active: certificates.error !== ""

                Label {
                    topMargin: ui.du(dimens.gap)
                    multiline: true
                    text: certificates.error
                    textStyle.color: Color.Red
                }
            }

            Label {
                topMargin: ui.du(dimens.gap)
                multiline: true
                text: qsTr("Imported into the phone's own certificate store, expired ones are removed. They stay after a reboot and without Tweaker.") + Retranslate.onLocaleOrLanguageChanged
                textStyle.color: ui.palette.secondaryTextOnPlain
            }
        }
    }
}
