# bb-shared - shared BB10 code, pulled into each project with:
#     include(../bb-shared/bb-shared.pri)
# in the project's .pro (a real shared module, not copy-paste). This copy holds only the parts Tweaker uses.

# Where this module sits, for the few paths an app writes itself (the coffee card's lupdate line):
# the same spelling in every app, however deep the app is nested.
BB_SHARED_DIR = $$PWD

# --- Language layer (L10n): header-only, works in GUI and headless service alike. Links bbsystem:
#     "system" is the device's UI language, asked of bb::system::LocaleHandler. Linked HERE, not
#     left to each app - a Cascades app is a .so, and a missing library there links clean and then
#     dies before main(). ---
INCLUDEPATH += $$PWD/l10n
HEADERS += $$PWD/l10n/L10n.hpp
LIBS += -lbbsystem

# --- DEPENDPATH for every bb-shared folder: without it qmake writes NO dependency on our headers,
#     so changing one leaves every app's objects "up to date" and the next build packs the OLD code. ---
DEPENDPATH += $$PWD/l10n

# --- UI helpers (AdvancedContainer, Loader): need Cascades AND are OPT-IN. A GUI project that wants them
#     adds `CONFIG += bb_shared_ui` before include(../bb-shared/bb-shared.pri), then calls
#     bbshared::registerUiTypes() at startup and `import bb.shared 1.0` in QML. ---
bb_shared_ui {
    # AdvancedContainer draws its pictures with QPainter and hands them to Cascades as bb::ImageData (libbb).
    QT += gui
    LIBS += -lbb
    INCLUDEPATH += $$PWD/ui
    DEPENDPATH += $$PWD/ui
    HEADERS += \
        $$PWD/ui/AdvancedContainer.hpp \
        $$PWD/ui/Loader.hpp \
        $$PWD/ui/BbSharedUi.hpp
    SOURCES += \
        $$PWD/ui/AdvancedContainer.cpp \
        $$PWD/ui/Loader.cpp
}

# --- Dimens (`dimens.pad` / `dimens.gap` / `dimens.wide`): the spacing every app lays its pages out with -
#     2 du on a normal phone, 3 du on a Passport. OPT-IN: `CONFIG += bb_shared_dimens`, then
#     bbshared::installDimensContext() for each QML document. Reads the display, so it links bbdevice itself. ---
bb_shared_dimens {
    INCLUDEPATH += $$PWD/ui
    DEPENDPATH += $$PWD/ui
    HEADERS += \
        $$PWD/ui/Dimens.hpp \
        $$PWD/ui/BbSharedDimens.hpp
    SOURCES += \
        $$PWD/ui/Dimens.cpp
    LIBS += -lbbdevice
}

# --- RootScript (root/RootScript.*): a shell script of the app's package run as root through the root wrapper
#     of a rooted phone, its verdict read from the last line. QtCore only, GUI and headless service alike.
#     OPT-IN: `CONFIG += bb_shared_root`. ---
bb_shared_root {
    INCLUDEPATH += $$PWD/root
    DEPENDPATH += $$PWD/root
    HEADERS += \
        $$PWD/root/RootScript.hpp
    SOURCES += \
        $$PWD/root/RootScript.cpp
}

# --- "Buy me a coffee" (ui/qml/BuyMeACoffee.qml, ui/images, SharedClipboard): the support card of every
#     app's Help sheet, kept once here instead of a copy per app. OPT-IN, and it NEEDS bb_shared_ui
#     (registerUiTypes() registers its SharedClipboard, under the BBSHARED_COFFEE define, and
#     AdvancedContainer - the card's plates). Two steps stay in the app - packing ui/images and listing
#     the QML for its lupdate, which reads every scope of a project whatever CONFIG says. ---
bb_shared_coffee {
    INCLUDEPATH += $$PWD/ui
    DEPENDPATH += $$PWD/ui
    DEFINES += BBSHARED_COFFEE
    HEADERS += \
        $$PWD/ui/SharedClipboard.hpp
    SOURCES += \
        $$PWD/ui/SharedClipboard.cpp
    OTHER_FILES += \
        $$PWD/ui/qml/BuyMeACoffee.qml \
        $$PWD/ui/images/ic_coffee_cup.png \
        $$PWD/ui/images/ic_coffee_steam.png \
        $$PWD/ui/images/ic_copy.png
}
