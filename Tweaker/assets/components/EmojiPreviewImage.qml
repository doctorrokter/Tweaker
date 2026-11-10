import bb.cascades 1.4

// One emoji of the preview on the emoji font page, as the chosen style draws it.
ImageView {
    id: root

    // The code point in hex, as the picture is named.
    property string code: ""
    // "telegram" or "noto".
    property string emojiStyle: "telegram"

    imageSource: "asset:///images/preview/" + root.emojiStyle + "/" + root.code + ".png"
    preferredHeight: ui.du(11)
    scalingMethod: ScalingMethod.AspectFit

    layoutProperties: StackLayoutProperties {
        spaceQuota: 1
    }
}
