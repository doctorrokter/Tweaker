import bb.cascades 1.4
import bb.cascades.pickers 1.0
import bb.shared 1.0
import "../components"

// The emoji font tweak (core/EmojiFont): on or off, a built-in style or the user's own file. Anything that went wrong
// stays on screen in red, as it is.
Page {
    id: root

    // A change that failed leaves emojiFont as it was, and the controls the user moved have to follow that too.
    property int finished: emojiFont.finishedCount
    // The drop-down is being set from the state, not by the user.
    property bool syncingStyle: false
    // The style the preview shows: it follows the drop-down at once, before the font is applied.
    property string previewStyle: "telegram"

    onFinishedChanged: {
        fontToggle.checked = emojiFont.enabled;
        root.syncStyle();
    }

    onCreationCompleted: {
        root.syncStyle();
    }

    // 0 = Telegram, 1 = Noto, nothing while the user's own file is in use.
    function syncStyle() {
        root.syncingStyle = true;
        if (emojiFont.customFileName !== "") {
            styleDropDown.resetSelectedIndex();
        } else if (emojiFont.style === "noto") {
            styleDropDown.selectedIndex = 1;
        } else {
            styleDropDown.selectedIndex = 0;
        }
        root.previewStyle = emojiFont.style;
        root.syncingStyle = false;
    }

    // Only what the controls do not show already.
    function noticeText() {
        if (emojiFont.foreignLink !== "") {
            return qsTr("The system font is replaced by something else: %1").arg(emojiFont.foreignLink);
        }
        if (emojiFont.enabled && ! emojiFont.linked) {
            return qsTr("On, not applied yet");
        }
        if (emojiFont.enabled && emojiFont.customFileName !== "") {
            return qsTr("Now: %1").arg(emojiFont.customFileName);
        }
        return "";
    }

    titleBar: TitleBar {
        title: qsTr("Emoji font") + Retranslate.onLocaleOrLanguageChanged
    }

    actionBarAutoHideBehavior: ActionBarAutoHideBehavior.HideOnScroll
    actionBarVisibility: ChromeVisibility.Overlay

    actions: [
        ActionItem {
            title: qsTr("Choose a font file") + Retranslate.onLocaleOrLanguageChanged
            imageSource: "asset:///images/ic_doctype_generic.png"
            ActionBar.placement: ActionBarPlacement.Signature
            enabled: emojiFont.rootAvailable && ! emojiFont.busy

            shortcuts: [
                Shortcut {
                    key: "c"
                }
            ]

            onTriggered: {
                fontPicker.open();
            }
        }
    ]

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
                    text: qsTr("New emoji in every app") + Retranslate.onLocaleOrLanguageChanged

                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                }

                ToggleButton {
                    id: fontToggle
                    verticalAlignment: VerticalAlignment.Center
                    checked: emojiFont.enabled
                    enabled: emojiFont.rootAvailable && ! emojiFont.busy

                    onCheckedChanged: {
                        if (checked === emojiFont.enabled) {
                            return;
                        }
                        if (checked) {
                            emojiFont.turnOn();
                        } else {
                            emojiFont.turnOff();
                        }
                    }
                }
            }

            // Driven by selectedIndex: selected / selectedValue are flaky on the device.
            DropDown {
                id: styleDropDown
                topMargin: ui.du(dimens.gap)
                title: qsTr("Emoji style") + Retranslate.onLocaleOrLanguageChanged
                enabled: emojiFont.rootAvailable && ! emojiFont.busy

                Option {
                    text: "Telegram"
                    value: "telegram"
                }

                Option {
                    text: "Noto"
                    value: "noto"
                }

                onSelectedIndexChanged: {
                    if (! selectedOptionSet) {
                        return;
                    }
                    var chosen = "telegram";
                    if (selectedIndex === 1) {
                        chosen = "noto";
                    }
                    root.previewStyle = chosen;
                    if (root.syncingStyle) {
                        return;
                    }
                    if (chosen === emojiFont.style && emojiFont.customFileName === "") {
                        return;
                    }
                    emojiFont.chooseStyle(chosen);
                }
            }

            // Pictures of the two built-in styles: there is none of the user's own file.
            Loader {
                active: emojiFont.customFileName === ""

                Container {
                    horizontalAlignment: HorizontalAlignment.Fill
                    topMargin: ui.du(dimens.gap)

                    layout: StackLayout {
                        orientation: LayoutOrientation.LeftToRight
                    }

                    EmojiPreviewImage {
                        code: "1f602"
                        emojiStyle: root.previewStyle
                    }

                    EmojiPreviewImage {
                        code: "1f60d"
                        emojiStyle: root.previewStyle
                    }

                    EmojiPreviewImage {
                        code: "1f914"
                        emojiStyle: root.previewStyle
                    }

                    EmojiPreviewImage {
                        code: "2764"
                        emojiStyle: root.previewStyle
                    }

                    EmojiPreviewImage {
                        code: "1f44d"
                        emojiStyle: root.previewStyle
                    }

                    EmojiPreviewImage {
                        code: "1f525"
                        emojiStyle: root.previewStyle
                    }

                    EmojiPreviewImage {
                        code: "1f389"
                        emojiStyle: root.previewStyle
                    }
                }
            }

            Loader {
                active: root.noticeText() !== ""

                Label {
                    topMargin: ui.du(dimens.gap)
                    multiline: true
                    text: root.noticeText() + Retranslate.onLocaleOrLanguageChanged
                    textStyle.color: ui.palette.primary
                    textStyle.fontWeight: FontWeight.W500
                }
            }

            Loader {
                active: emojiFont.busy

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
                active: emojiFont.error !== ""

                Label {
                    topMargin: ui.du(dimens.gap)
                    multiline: true
                    text: emojiFont.error
                    textStyle.color: Color.Red
                }
            }

            Label {
                topMargin: ui.du(dimens.gap)
                multiline: true
                text: qsTr("Other apps pick up the font once you close and reopen them.") + Retranslate.onLocaleOrLanguageChanged
                textStyle.color: ui.palette.secondaryTextOnPlain
            }
        }
    }

    attachedObjects: [
        FilePicker {
            id: fontPicker
            type: FileType.Other
            mode: FilePickerMode.Picker
            title: qsTr("Choose a font file") + Retranslate.onLocaleOrLanguageChanged

            filter: [
                "*.ttf"
            ]

            onFileSelected: {
                if (selectedFiles.length > 0) {
                    emojiFont.useFile(selectedFiles[0]);
                }
            }
        }
    ]
}
