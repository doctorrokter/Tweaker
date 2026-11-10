APP_NAME = Tweaker

CONFIG += qt warn_on cascades10

include(config.pri)

# --- Build environment: development (default) or production ------------------
# Chosen at build time by bb-shared/tools/build-bar.sh, which exports BBT_ENV (`-e production` for the build that
# ships to users, development otherwise). production compiles every qDebug() call site out.
BBT_ENV = $$(BBT_ENV)
BBT_ENV = $$replace(BBT_ENV, \\r, )
isEmpty(BBT_ENV): BBT_ENV = development
equals(BBT_ENV, production) {
    DEFINES += QT_NO_DEBUG_OUTPUT
    message("Tweaker: PRODUCTION build - qDebug() compiled out")
} else {
    message("Tweaker: development build ($$BBT_ENV)")
}

# Shared BB10 code: the L10n language layer; `dimens`, the spacing of the service pages; Loader and the settings rows;
# the Help sheet's "Buy me a coffee" card; running a script as root.
# bb-shared sits next to this project.
CONFIG += bb_shared_dimens bb_shared_ui bb_shared_coffee bb_shared_root
include(../bb-shared/bb-shared.pri)

# -lbbcascadespickers: bb.cascades.pickers (FilePicker) for "Choose a font file".
LIBS += -lbb -lbbsystem -lbbcascadespickers

# The app's own classes: listed by core.pri, not by Momentics.
include(core/core.pri)

# For this project's lupdate: the pages in the asset folders and the coffee card, whose strings go into OUR catalog.
lupdate_inclusion {
    SOURCES += \
        $$PWD/assets/*.qml \
        $$PWD/assets/pages/*.qml \
        $$PWD/assets/sheets/*.qml \
        $$PWD/core/*.cpp \
        $$BB_SHARED_DIR/ui/qml/BuyMeACoffee.qml
}

# A Cascades app is a SHARED OBJECT: without this an undefined symbol links silently and the app dies before main()
# on the device, with nothing in the log (KB 2.8).
QMAKE_LFLAGS += -Wl,--no-undefined
