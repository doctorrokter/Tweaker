import bb.cascades 1.4
import bb.platform 1.3
import "../shared"

/*
 * HelpSheet - the About / Help sheet (app menu -> Help), laid out like every app of ours: BBTelega's is the reference.
 * Native Header sections, `dimens` spacing, default text sizes, the colours of the Cascades palette.
 */
Sheet {
    id: root

    onOpened: {
        coffee.animated = true;
    }

    onClosed: {
        coffee.animated = false;
    }

    Page {
        titleBar: TitleBar {
            title: qsTr("About") + Retranslate.onLocaleOrLanguageChanged

            dismissAction: ActionItem {
                title: qsTr("Close") + Retranslate.onLocaleOrLanguageChanged

                onTriggered: {
                    root.close();
                }
            }
        }

        actionBarAutoHideBehavior: ActionBarAutoHideBehavior.HideOnScroll
        actionBarVisibility: ChromeVisibility.Overlay

        ScrollView {
            scrollRole: ScrollRole.Main

            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                bottomPadding: ui.du(dimens.pad)

                Header {
                    title: qsTr("About") + Retranslate.onLocaleOrLanguageChanged
                }

                Container {
                    layout: StackLayout {
                        orientation: LayoutOrientation.LeftToRight
                    }
                    leftPadding: ui.du(dimens.pad)
                    rightPadding: ui.du(dimens.pad)
                    topMargin: ui.du(dimens.gap)
                    bottomMargin: ui.du(dimens.gap)

                    Label {
                        text: qsTr("Author: ") + Retranslate.onLocaleOrLanguageChanged
                    }

                    Label {
                        text: "Mikhail Chachkouski"
                        textStyle.color: ui.palette.primary
                        textStyle.fontWeight: FontWeight.W500

                        gestureHandlers: [
                            TapHandler {
                                onTapped: {
                                    githubInvoke.trigger(githubInvoke.query.invokeActionId);
                                }
                            }
                        ]
                    }
                }

                Container {
                    leftPadding: ui.du(dimens.pad)
                    rightPadding: ui.du(dimens.pad)
                    bottomMargin: ui.du(dimens.gap)

                    Label {
                        text: qsTr("App: ") + Retranslate.onLocaleOrLanguageChanged + Application.applicationName
                    }

                    Label {
                        topMargin: 0
                        text: qsTr("Version: ") + Retranslate.onLocaleOrLanguageChanged + Application.applicationVersion
                        textStyle.color: ui.palette.secondaryTextOnPlain
                    }

                    Label {
                        topMargin: 0
                        text: qsTr("OS: ") + Retranslate.onLocaleOrLanguageChanged + platform.osVersion
                        textStyle.color: ui.palette.secondaryTextOnPlain
                    }
                }

                Header {
                    title: qsTr("Good to know") + Retranslate.onLocaleOrLanguageChanged
                }

                Container {
                    topMargin: ui.du(dimens.gap)
                    leftPadding: ui.du(dimens.pad)
                    rightPadding: ui.du(dimens.pad)

                    Label {
                        text: qsTr("What Tweaker is") + Retranslate.onLocaleOrLanguageChanged
                        textStyle.color: ui.palette.primary
                        textStyle.fontWeight: FontWeight.W500
                    }

                    Label {
                        topMargin: 0
                        multiline: true
                        text: qsTr("System tweaks for BlackBerry 10 phones with root v4.") + Retranslate.onLocaleOrLanguageChanged
                    }
                }

                Container {
                    topMargin: ui.du(dimens.gap)
                    leftPadding: ui.du(dimens.pad)
                    rightPadding: ui.du(dimens.pad)

                    Label {
                        text: qsTr("Emoji font") + Retranslate.onLocaleOrLanguageChanged
                        textStyle.color: ui.palette.primary
                        textStyle.fontWeight: FontWeight.W500
                    }

                    Label {
                        topMargin: 0
                        multiline: true
                        text: qsTr("Newer emoji in every app: the Telegram or Noto style, or a font file of your own. Turned off, the phone is as it was.") + Retranslate.onLocaleOrLanguageChanged
                    }
                }

                Container {
                    topMargin: ui.du(dimens.gap)
                    leftPadding: ui.du(dimens.pad)
                    rightPadding: ui.du(dimens.pad)

                    Label {
                        text: qsTr("Certificates") + Retranslate.onLocaleOrLanguageChanged
                        textStyle.color: ui.palette.primary
                        textStyle.fontWeight: FontWeight.W500
                    }

                    Label {
                        topMargin: 0
                        multiline: true
                        text: qsTr("Mozilla's current root certificates go into the phone's own store and expired ones are removed. They stay after a reboot and without Tweaker.") + Retranslate.onLocaleOrLanguageChanged
                    }
                }

                Container {
                    topMargin: ui.du(dimens.gap)
                    leftPadding: ui.du(dimens.pad)
                    rightPadding: ui.du(dimens.pad)

                    Label {
                        text: qsTr("System theme") + Retranslate.onLocaleOrLanguageChanged
                        textStyle.color: ui.palette.primary
                        textStyle.fontWeight: FontWeight.W500
                    }

                    Label {
                        topMargin: 0
                        multiline: true
                        text: qsTr("Light or dark, for the Hub and email and for the rest of the system separately. After the phone starts, the chosen theme comes back by itself a little later. Some apps, Contacts for one, keep their own look.") + Retranslate.onLocaleOrLanguageChanged
                    }
                }

                Container {
                    topMargin: ui.du(dimens.gap)
                    leftPadding: ui.du(dimens.pad)
                    rightPadding: ui.du(dimens.pad)

                    Label {
                        text: qsTr("If something goes wrong") + Retranslate.onLocaleOrLanguageChanged
                        textStyle.color: ui.palette.primary
                        textStyle.fontWeight: FontWeight.W500
                    }

                    Label {
                        topMargin: 0
                        multiline: true
                        text: qsTr("Create a file or a folder named tweaker-off in the misc folder of the phone's storage and restart the phone: while it is there, Tweaker applies nothing.") + Retranslate.onLocaleOrLanguageChanged
                    }
                }

                Header {
                    title: qsTr("Built with") + Retranslate.onLocaleOrLanguageChanged
                }

                Container {
                    topMargin: ui.du(dimens.gap)
                    leftPadding: ui.du(dimens.pad)
                    rightPadding: ui.du(dimens.pad)
                    bottomMargin: ui.du(dimens.gap)

                    Label {
                        text: "Noto Color Emoji"
                        textStyle.color: ui.palette.primary
                        textStyle.fontWeight: FontWeight.W500

                        gestureHandlers: [
                            TapHandler {
                                onTapped: {
                                    notoInvoke.trigger(notoInvoke.query.invokeActionId);
                                }
                            }
                        ]
                    }

                    Label {
                        topMargin: 0
                        multiline: true
                        text: qsTr("The Noto emoji style, by Google. SIL Open Font License 1.1.") + Retranslate.onLocaleOrLanguageChanged
                    }
                }

                Container {
                    leftPadding: ui.du(dimens.pad)
                    rightPadding: ui.du(dimens.pad)
                    bottomMargin: ui.du(dimens.gap)

                    Label {
                        text: "Mozilla CA certificates"
                        textStyle.color: ui.palette.primary
                        textStyle.fontWeight: FontWeight.W500

                        gestureHandlers: [
                            TapHandler {
                                onTapped: {
                                    mozillaInvoke.trigger(mozillaInvoke.query.invokeActionId);
                                }
                            }
                        ]
                    }

                    Label {
                        topMargin: 0
                        multiline: true
                        text: qsTr("The list of trusted root certificates. Mozilla Public License 2.0.") + Retranslate.onLocaleOrLanguageChanged
                    }
                }

                Container {
                    leftPadding: ui.du(dimens.pad)
                    rightPadding: ui.du(dimens.pad)
                    bottomMargin: ui.du(dimens.gap)

                    Label {
                        text: "bb10-dark-theme"
                        textStyle.color: ui.palette.primary
                        textStyle.fontWeight: FontWeight.W500

                        gestureHandlers: [
                            TapHandler {
                                onTapped: {
                                    darkThemeInvoke.trigger(darkThemeInvoke.query.invokeActionId);
                                }
                            }
                        ]
                    }

                    Label {
                        topMargin: 0
                        multiline: true
                        text: qsTr("How the dark theme is applied, and the Hub's icons for it. MIT License; the icons are BlackBerry's artwork.") + Retranslate.onLocaleOrLanguageChanged
                    }
                }

                Divider {
                    bottomMargin: ui.du(dimens.gap)
                }

                Container {
                    leftPadding: ui.du(dimens.pad)
                    rightPadding: ui.du(dimens.pad)

                    BuyMeACoffee {
                        id: coffee
                        animated: false
                        pad: dimens.pad
                        gap: dimens.gap
                    }
                }
            }
        }
    }

    attachedObjects: [
        PlatformInfo {
            id: platform
        },
        Invocation {
            id: githubInvoke
            query {
                uri: "https://github.com/doctorrokter"
                invokeActionId: "bb.action.OPEN"
                invokeTargetId: "sys.browser"
            }
        },
        Invocation {
            id: notoInvoke
            query {
                uri: "https://github.com/googlefonts/noto-emoji"
                invokeActionId: "bb.action.OPEN"
                invokeTargetId: "sys.browser"
            }
        },
        Invocation {
            id: mozillaInvoke
            query {
                uri: "https://curl.se/docs/caextract.html"
                invokeActionId: "bb.action.OPEN"
                invokeTargetId: "sys.browser"
            }
        },
        Invocation {
            id: darkThemeInvoke
            query {
                uri: "https://github.com/damianolampisti00/bb10-dark-theme"
                invokeActionId: "bb.action.OPEN"
                invokeTargetId: "sys.browser"
            }
        }
    ]
}
