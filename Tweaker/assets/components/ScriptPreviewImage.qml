import bb.cascades 1.4

// One example of the rare alphabets page: a name as the phone draws it now ("before", empty boxes) or with the fonts
// ("after"). The pictures are white, tinted here to the theme's text colour.
ImageView {
    id: root

    // The example, as the pictures are named: "name" or "math".
    property string example: ""
    // "before" or "after".
    property string kind: "after"

    imageSource: "asset:///images/preview/scripts/" + root.example + "-" + root.kind + ".png"
    horizontalAlignment: HorizontalAlignment.Fill
    preferredHeight: ui.du(6)
    scalingMethod: ScalingMethod.AspectFit
    filterColor: root.kind === "before" ? ui.palette.secondaryTextOnPlain : ui.palette.textOnPlain
}
