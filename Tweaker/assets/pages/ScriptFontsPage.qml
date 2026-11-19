import bb.cascades 1.4
import bb.shared 1.0
import "../components"

// Fonts for letters of rare alphabets (core/ScriptFonts): on or off, with two names as the phone draws them now and
// with the fonts. Anything that went wrong stays on screen in red, as it is.
Page {
    id: root

    // A change that failed leaves scriptFonts as it was, and the toggle has to follow that too.
    property int finished: scriptFonts.finishedCount

    // The list of everything the fonts add (ScriptSamplesPage), pushed by main.qml.
    signal samplesRequested()

    onFinishedChanged: {
        fontsToggle.checked = scriptFonts.enabled;
    }

    titleBar: TitleBar {
        title: qsTr("Rare alphabets") + Retranslate.onLocaleOrLanguageChanged
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

            Container {
                horizontalAlignment: HorizontalAlignment.Fill

                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }

                Label {
                    verticalAlignment: VerticalAlignment.Center
                    multiline: true
                    text: qsTr("Letters of rare alphabets in every app") + Retranslate.onLocaleOrLanguageChanged

                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                }

                ToggleButton {
                    id: fontsToggle
                    verticalAlignment: VerticalAlignment.Center
                    checked: scriptFonts.enabled
                    enabled: scriptFonts.rootAvailable && ! scriptFonts.busy

                    onCheckedChanged: {
                        if (checked === scriptFonts.enabled) {
                            return;
                        }
                        if (checked) {
                            scriptFonts.turnOn();
                        } else {
                            scriptFonts.turnOff();
                        }
                    }
                }
            }

            Label {
                topMargin: ui.du(dimens.gap)
                multiline: true
                text: qsTr("Names and messages are often written with letters of other alphabets that look like ours, with hieroglyphs or symbols: Gothic, Tai, Cherokee, Egyptian hieroglyphs, mathematical letters. The phone has no fonts for many of them and shows empty boxes. Tweaker adds free Noto fonts for nearly 150 scripts and symbol sets to every app.") + Retranslate.onLocaleOrLanguageChanged
            }

            Label {
                topMargin: ui.du(dimens.gap)
                text: qsTr("Now") + Retranslate.onLocaleOrLanguageChanged
                textStyle.color: ui.palette.secondaryTextOnPlain
            }

            ScriptPreviewImage {
                example: "name"
                kind: "before"
            }

            ScriptPreviewImage {
                example: "math"
                kind: "before"
            }

            Label {
                topMargin: ui.du(dimens.gap)
                text: qsTr("With these fonts") + Retranslate.onLocaleOrLanguageChanged
                textStyle.color: ui.palette.secondaryTextOnPlain
            }

            ScriptPreviewImage {
                example: "name"
                kind: "after"
            }

            ScriptPreviewImage {
                example: "math"
                kind: "after"
            }

            Button {
                topMargin: ui.du(dimens.gap)
                horizontalAlignment: HorizontalAlignment.Fill
                text: qsTr("What it adds: %1").arg(scriptFonts.sampleCount) + Retranslate.onLocaleOrLanguageChanged

                onClicked: {
                    root.samplesRequested();
                }
            }

            Loader {
                active: scriptFonts.enabled && ! scriptFonts.linked && ! scriptFonts.busy

                Label {
                    topMargin: ui.du(dimens.gap)
                    multiline: true
                    text: qsTr("On, not applied yet") + Retranslate.onLocaleOrLanguageChanged
                    textStyle.color: ui.palette.primary
                    textStyle.fontWeight: FontWeight.W500
                }
            }

            Loader {
                active: scriptFonts.busy

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
                active: scriptFonts.error !== ""

                Label {
                    topMargin: ui.du(dimens.gap)
                    multiline: true
                    text: scriptFonts.error
                    textStyle.color: Color.Red
                }
            }

            Label {
                topMargin: ui.du(dimens.gap)
                multiline: true
                text: qsTr("Other apps pick up the fonts once you close and reopen them.") + Retranslate.onLocaleOrLanguageChanged
                textStyle.color: ui.palette.secondaryTextOnPlain
            }
        }
    }
}
