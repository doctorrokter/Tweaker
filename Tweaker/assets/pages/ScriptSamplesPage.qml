import bb.cascades 1.4
import bb.shared 1.0

// Every script and symbol set the rare alphabets fonts add (core/ScriptFonts.samples(), from assets/scriptsamples.json),
// each with a few of its letters drawn by the phone itself: empty boxes while the fonts are off, letters once they are on.
Page {
    id: root

    // What the list cannot show by itself; "" for nothing.
    function hintText() {
        if (! scriptFonts.enabled) {
            return qsTr("While the fonts are off, the phone shows empty boxes here.");
        }
        if (scriptFonts.needsReopen) {
            return qsTr("Close Tweaker and open it again to see the letters here.");
        }
        return "";
    }

    onCreationCompleted: {
        samplesModel.append(scriptFonts.samples());
    }

    titleBar: TitleBar {
        title: qsTr("What it adds") + Retranslate.onLocaleOrLanguageChanged
    }

    actionBarAutoHideBehavior: ActionBarAutoHideBehavior.HideOnScroll
    actionBarVisibility: ChromeVisibility.Overlay

    Container {
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill

        Loader {
            active: root.hintText() !== ""

            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                topPadding: ui.du(dimens.gap)
                leftPadding: ui.du(dimens.pad)
                rightPadding: ui.du(dimens.pad)

                Label {
                    multiline: true
                    text: root.hintText() + Retranslate.onLocaleOrLanguageChanged
                    textStyle.color: ui.palette.primary
                    textStyle.fontWeight: FontWeight.W500
                }
            }
        }

        ListView {
            id: samplesList
            scrollRole: ScrollRole.Main

            dataModel: ArrayDataModel {
                id: samplesModel
            }

            listItemComponents: [
                ListItemComponent {
                    StandardListItem {
                        title: ListItemData.sample
                        description: ListItemData.name
                    }
                }
            ]
        }
    }
}
