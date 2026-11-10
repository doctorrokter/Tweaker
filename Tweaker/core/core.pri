# core - Tweaker's own C++ (docs/TWEAKS.md). Listed HERE, not by Momentics: config.pri is the IDE's and covers
# only src/ (Syno's core.pri and Tunnel's client.pri do the same). Every file name must be unique across the
# project: qmake builds into one flat object directory.

TWEAKER_CORE_DIR = $$PWD

INCLUDEPATH += $$TWEAKER_CORE_DIR
DEPENDPATH += $$TWEAKER_CORE_DIR

HEADERS += \
    $$TWEAKER_CORE_DIR/Settings.hpp \
    $$TWEAKER_CORE_DIR/Changelog.hpp \
    $$TWEAKER_CORE_DIR/EmojiFont.hpp \
    $$TWEAKER_CORE_DIR/Certificates.hpp \
    $$TWEAKER_CORE_DIR/SystemTheme.hpp

SOURCES += \
    $$TWEAKER_CORE_DIR/Settings.cpp \
    $$TWEAKER_CORE_DIR/Changelog.cpp \
    $$TWEAKER_CORE_DIR/EmojiFont.cpp \
    $$TWEAKER_CORE_DIR/Certificates.cpp \
    $$TWEAKER_CORE_DIR/SystemTheme.cpp

# bb::data::JsonDataAccess reads the release notes.
LIBS += -lbbdata
