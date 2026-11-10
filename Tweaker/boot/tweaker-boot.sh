#!/bin/sh
#
# tweaker-boot.sh - Tweaker's root side, one file run in two ways (bb-shared/BB10-ROOT-AUTOSTART.md).
#
# From the app, through the root wrapper, this file fed to a shell on stdin:
#     /bin/ksh -s install  '<this file>' < '<this file>'             the boot start in place
#     /bin/ksh -s font-on  '<this file>' '<a font>' < '<this file>'  the font copied in, linked, the Hub restarted
#     /bin/ksh -s font-off '<this file>' < '<this file>'             the link and the font gone, the Hub restarted
#     /bin/ksh -s certs-update '<this file>' '<a folder>' '<the store tool>' < '<this file>'  the roots imported, the expired ones removed
#     /bin/ksh -s system-theme '<this file>' black|white < '<this file>'  the theme of everything that takes the system's
#     /bin/ksh -s hub-theme '<this file>' black|white '<light icons>' < '<this file>'  the Hub and email, apart from the rest
# The app reads the output: a line reason=<text> when something failed, and as the last line
# result=ok (done), same (nothing to do) or failed.
#
# At boot, by the firmware, as /var/addons/tweaker/init/start.sh, with any other arguments or none: applies
# what is on, in the background of the boot, and returns at once.
#
# Fed through stdin the file is being read while it runs: a tool that reads stdin eats the rest of it, so
# every one that could is given < /dev/null. Written for the phone's /bin/sh (PD KSH 5.2.14); the tools are the
# firmware's. There is no head, tr, cmp or rmdir.
#
# The system's own font is never changed: /base is read-only. The link over it lives in memory and is made again
# at every boot, so without this script a reboot gives the phone back as it was.
#
# Safety (the same rules as Tunnel's boot script):
#   - Off switch, no root needed: a file or a folder named tweaker-off in the shared misc folder (File Manager,
#     the PC over USB). While it is there nothing is applied at boot.
#   - Boot-loop breaker: a guard file before applying, removed after $SETTLE s or on a clean stop. If the phone
#     went down within those seconds, the next boot applies nothing, once.
#   - The app uninstalled: on two looks in a row, /apps readable and neither the package nor its sandbox left,
#     $ADDON goes altogether. An empty or unreadable /apps says nothing.
#   - Nothing here is run from the shared storage. A font chosen there is copied in as data.
#
# Log: misc/tweaker-boot.txt in the shared storage, $LOG_SPARE while misc cannot be written yet. No "started"
# line for a boot means the script did not run.

PATH=/bin:/usr/bin:/sbin:/usr/sbin
export PATH

ADDON=/var/addons/tweaker
START=$ADDON/init/start.sh
ON=$ADDON/on
FONTS=$ADDON/fonts
OUR_FONT=$FONTS/NotoColorEmoji.ttf
SYSTEM_FONT=/base/usr/fonts/font_repository/monotype/NotoColorEmoji.ttf
# The composite font descriptions that say which characters the emoji font may draw: the system's stop at U+1F6C5.
SYSTEM_LISTS=/base/usr/fonts/font_repository/monotype
OUR_LISTS=$ADDON/lists
LIST_NAMES="SlatePro-Regular_Color.cfr SlatePro-Medium_Color.cfr SlatePro-Light_Color.cfr SlatePro-Bold_Color.cfr SlatePro-Italic_Color.cfr SlatePro-MediumItalic_Color.cfr SlatePro-LightItalic_Color.cfr SlatePro-BoldItalic_Color.cfr"
# The certificate manager's own databases and its user. A manual import writes to the first two; shared_trusted exists
# only on a phone that has had one.
WEB_STORE=/var/certdb/personal/certdb/certmgr/web_trusted/certstore.db
SHARED_STORE=/var/certdb/personal/certdb/nto/shared_trusted/certstore.db
SYSTEM_STORE=/var/certdb/global/certdb/nto/rim_trusted/certstore.db
STORE_USER=110:110
# A folder that user can read, on a real file system: SQLite cannot work on /tmp.
CERTS_WORK=/var/tmp/tweaker-certs
PATHTRUST=/proc/boot/pathtrust
# The system's theme: back to its default at every boot.
THEME_PPS=/pps/services/deviceproperties
# The dark copies of the Hub's QML and icons and of the first page of its cards, linked in memory over the system's. The system's own
# files stay untouched: with an edited package the Hub does not start at boot. The manifests, which name the bright theme, cannot be
# linked: the launcher refuses a MANIFEST.MF that is a link. So the first page of each asks for the dark style itself.
THEME_DARK=$ADDON/theme-dark
DARK_STYLE_PAGES="sys.pim.messages:MessageList.qml sys.pim.messages:mainwaitscreen.qml sys.pim.email.card:Viewer.qml sys.pim.email.composer.card:compose.qml sys.pim.attachments.card:Attachments.qml"
THEME_TMP=/tmp/tweaker-theme.tmp
GUARD=$ADDON/boot-guard
SETTLE=60
APPS=/apps
APPDATA=/accounts/1000/appdata
OFF=/accounts/1000/shared/misc/tweaker-off
LOG=/accounts/1000/shared/misc/tweaker-boot.txt
LOG_SPARE=$ADDON/tweaker-boot.txt
LOG_LIMIT=65536 # bytes; a bigger log moves to *.old.txt

mode=boot
case "$1" in
    install | font-on | font-off | certs-update | system-theme | hub-theme)
        mode=$1
        mkdir -p "$ADDON" < /dev/null 2> /dev/null
        ;;
esac

TAG="$mode $$"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S' 2> /dev/null) [$TAG] $*" 2> /dev/null >> "$LOG"
}

trim_log() {
    if [ "$LOG" = /dev/null ]; then
        return 0
    fi
    set -- $(ls -ln "$LOG" 2> /dev/null < /dev/null)
    case "$5" in
        '' | *[!0-9]*)
            return 0
            ;;
    esac
    if [ "$5" -gt "$LOG_LIMIT" ]; then
        mv -f "$LOG" "${LOG%.txt}.old.txt" < /dev/null
    fi
    return 0
}

# The empty line between runs doubles as the test that the log can be written.
if ! echo "" 2> /dev/null >> "$LOG"; then
    LOG=$LOG_SPARE
    if ! echo "" 2> /dev/null >> "$LOG"; then
        LOG=/dev/null
    fi
fi
trim_log
# From here on the shell's own error messages go to the log, not to the caller. exec is a special built-in: a
# redirection that fails on it ends the shell, so the file is tried with true first.
if { true >> "$LOG"; } 2> /dev/null; then
    exec 2>> "$LOG"
fi
log "started: $0, arguments: $*"

# Tells the app, ends the run.
fail() {
    log "failed: $*"
    echo "reason=$*"
    echo "result=failed"
    exit 0
}

# $1 into $2 with mode $3, whole or not there: a copy under *.new, then mv. Not when the same file is there
# already: copied says which it was. Returns 1 with copy_error set.
copy_whole() {
    copied=
    if [ -f "$2" ] && [ "$(cksum < "$1")" = "$(cksum < "$2")" ]; then
        return 0
    fi
    rm -f "$2.new" < /dev/null
    if copy_error=$( { cp "$1" "$2.new" && chmod "$3" "$2.new" && mv -f "$2.new" "$2"; } 2>&1 < /dev/null ); then
        copied=1
        return 0
    fi
    rm -f "$2.new" < /dev/null
    return 1
}

# This file into the place the firmware starts it from.
install_hook() {
    case "$1" in
        /*)
            ;;
        *)
            fail "not a full path: $1"
            ;;
    esac
    if [ ! -f "$1" ]; then
        fail "no such file: $1"
    fi
    if ! folder_error=$( { mkdir -p "$ADDON/init" "$ON" "$FONTS" && chmod 755 "$ADDON" "$ADDON/init" "$ON" "$FONTS"; } 2>&1 < /dev/null ); then
        fail "cannot make $ADDON: $folder_error"
    fi
    if ! copy_whole "$1" "$START" 755; then
        fail "cannot write $START: $copy_error"
    fi
    if [ -n "$copied" ]; then
        log "install: copied to $START"
    fi
    hook_copied=$copied
}

# Our font over the system's. A link of someone else's (the boot loader's, an earlier one) goes first: ln -sP does
# not replace one. Returns 1 with link_error set.
link_font() {
    listing=$(ls -l "$SYSTEM_FONT" 2>&1 < /dev/null)
    case "$listing" in
        *" -> $OUR_FONT"*)
            log "font: the link is there already"
            return 0
            ;;
        l*)
            log "font: another link goes first: $listing"
            if ! link_error=$(rm -f "$SYSTEM_FONT" 2>&1 < /dev/null); then
                return 1
            fi
            ;;
    esac
    if ! link_error=$(ln -sP "$OUR_FONT" "$SYSTEM_FONT" 2>&1 < /dev/null); then
        return 1
    fi
    listing=$(ls -l "$SYSTEM_FONT" 2>&1 < /dev/null)
    case "$listing" in
        *" -> $OUR_FONT"*)
            log "font: linked"
            return 0
            ;;
    esac
    link_error="the link is not there after ln: $listing"
    return 1
}

# Our link off. A link of someone else's stays.
unlink_font() {
    listing=$(ls -l "$SYSTEM_FONT" 2>&1 < /dev/null)
    case "$listing" in
        *" -> $OUR_FONT"*)
            if ! link_error=$(rm -f "$SYSTEM_FONT" 2>&1 < /dev/null); then
                return 1
            fi
            log "font: unlinked"
            ;;
    esac
    return 0
}

# Our copies of the descriptions, with the emoji range opened up to U+1FAFF, each made from the system's own file. A
# file already linked is ours: the system's cannot be read through the link and there is nothing to make. Returns 1 with
# list_error set; the '.' in the patterns stands for the backslash of Ὠ0.
make_lists() {
    if ! list_error=$( { mkdir -p "$OUR_LISTS" && chmod 755 "$OUR_LISTS"; } 2>&1 < /dev/null ); then
        return 1
    fi
    for list_name in $LIST_NAMES; do
        system_list=$SYSTEM_LISTS/$list_name
        our_list=$OUR_LISTS/$list_name
        case "$(ls -l "$system_list" 2>&1 < /dev/null)" in
            *" -> $our_list"*)
                continue
                ;;
        esac
        if ! grep 'u1f680-.u1f6c5' "$system_list" > /dev/null 2>&1 < /dev/null || ! grep 'u231a-.u231b' "$system_list" > /dev/null 2>&1 < /dev/null; then
            list_error="$list_name has no emoji range this script knows"
            return 1
        fi
        rm -f "$our_list.new" < /dev/null
        # Below U+1F000 exactly what the font has, not a wide range: components after this one serve the rest.
        if ! list_error=$( { sed -e '/name="Noto Color Emoji"/,/\/ComponentDef/s/u1f680-\\u1f6c5/u1f680-\\u1faff/' -e '/name="Noto Color Emoji"/,/\/ComponentDef/s/\[\\u231a-\\u231b\].*\[\\u3030\]/[\\ua9] [\\uae] [\\u203c] [\\u2049] [\\u20e3] [\\u2122] [\\u2139] [\\u2194-\\u2199] [\\u21a9-\\u21aa] [\\u231a-\\u231b] [\\u2328] [\\u23cf] [\\u23e9-\\u23f3] [\\u23f8-\\u23fa] [\\u24c2] [\\u25aa-\\u25ab] [\\u25b6] [\\u25c0] [\\u25fb-\\u25fe] [\\u2600-\\u2604] [\\u260e] [\\u2611] [\\u2614-\\u2615] [\\u2618] [\\u261d] [\\u2620] [\\u2622-\\u2623] [\\u2626] [\\u262a] [\\u262e-\\u262f] [\\u2638-\\u263a] [\\u2640] [\\u2642] [\\u2648-\\u2653] [\\u265f-\\u2660] [\\u2663] [\\u2665-\\u2666] [\\u2668] [\\u267b] [\\u267e-\\u267f] [\\u2692-\\u2697] [\\u2699] [\\u269b-\\u269c] [\\u26a0-\\u26a1] [\\u26a7] [\\u26aa-\\u26ab] [\\u26b0-\\u26b1] [\\u26bd-\\u26be] [\\u26c4-\\u26c5] [\\u26c8] [\\u26ce-\\u26cf] [\\u26d1] [\\u26d3-\\u26d4] [\\u26e9-\\u26ea] [\\u26f0-\\u26f5] [\\u26f7-\\u26fa] [\\u26fd] [\\u2702] [\\u2705] [\\u2708-\\u270d] [\\u270f] [\\u2712] [\\u2714] [\\u2716] [\\u271d] [\\u2721] [\\u2728] [\\u2733-\\u2734] [\\u2744] [\\u2747] [\\u274c] [\\u274e] [\\u2753-\\u2755] [\\u2757] [\\u2763-\\u2764] [\\u2795-\\u2797] [\\u27a1] [\\u27b0] [\\u27bf] [\\u2934-\\u2935] [\\u2b05-\\u2b07] [\\u2b1b-\\u2b1c] [\\u2b50] [\\u2b55] [\\u3030] [\\u303d] [\\u3297] [\\u3299]/' < "$system_list" > "$our_list.new" && chmod 644 "$our_list.new"; } 2>&1 ); then
            return 1
        fi
        if ! grep 'u1f680-.u1faff' "$our_list.new" > /dev/null 2>&1 < /dev/null || ! grep 'u2763-.u2764' "$our_list.new" > /dev/null 2>&1 < /dev/null; then
            list_error="$list_name was not changed"
            rm -f "$our_list.new" < /dev/null
            return 1
        fi
        if ! list_error=$(mv -f "$our_list.new" "$our_list" 2>&1 < /dev/null); then
            return 1
        fi
    done
    return 0
}

# Our copies over the system's. Returns 1 with list_error set.
link_lists() {
    for list_name in $LIST_NAMES; do
        system_list=$SYSTEM_LISTS/$list_name
        our_list=$OUR_LISTS/$list_name
        case "$(ls -l "$system_list" 2>&1 < /dev/null)" in
            *" -> $our_list"*)
                continue
                ;;
        esac
        if ! list_error=$(ln -sP "$our_list" "$system_list" 2>&1 < /dev/null); then
            return 1
        fi
        case "$(ls -l "$system_list" 2>&1 < /dev/null)" in
            *" -> $our_list"*)
                ;;
            *)
                list_error="the link over $list_name is not there after ln"
                return 1
                ;;
        esac
    done
    log "font: the character lists linked"
    return 0
}

# Our links off and our copies gone. Returns 1 with list_error set.
unlink_lists() {
    for list_name in $LIST_NAMES; do
        system_list=$SYSTEM_LISTS/$list_name
        case "$(ls -l "$system_list" 2>&1 < /dev/null)" in
            *" -> $OUR_LISTS/$list_name"*)
                if ! list_error=$(rm -f "$system_list" 2>&1 < /dev/null); then
                    return 1
                fi
                ;;
        esac
    done
    rm -rf "$OUR_LISTS" < /dev/null
    log "font: the character lists unlinked"
    return 0
}

# One run of the store tool, as the store's own user. Its last line says it finished. Returns 1 with certs_error set.
run_certstore_tool() {
    tool_output=$(on -u "$STORE_USER" "$CERTS_WORK/certstore-tool" "$@" 2>&1 < /dev/null)
    log "certs: $1 $2: $tool_output"
    case "$tool_output" in
        *"objects now:"*)
            return 0
            ;;
    esac
    certs_error="$1 $2: $tool_output"
    return 1
}

# Mozilla's roots ($1/mozilla.db) into the stores a manual import writes to, the expired ones out of the system's, found
# by their dates on this phone. $2 is the store tool. Each change is one transaction in the certificate manager's own database: seen at once, there
# after a reboot, with nothing of ours needed afterwards. Run again, it does only what is left. Returns 1 with certs_error set.
update_certs() {
    rm -rf "$CERTS_WORK" < /dev/null
    if ! certs_error=$( { mkdir -p "$CERTS_WORK" && cp "$1/mozilla.db" "$2" "$CERTS_WORK"/ && chmod 755 "$CERTS_WORK" "$CERTS_WORK/certstore-tool" && chmod 644 "$CERTS_WORK/mozilla.db"; } 2>&1 < /dev/null ); then
        return 1
    fi
    # As in Tunnel's boot script: run from the app, the tool is refused without this. Each result goes to the log.
    for trust_path in "$CERTS_WORK" "$CERTS_WORK/certstore-tool"; do
        trust_output=$("$PATHTRUST" "!$trust_path" < /dev/null 2>&1)
        log "pathtrust $trust_path: status $?, $trust_output"
    done
    # The user's store appears with the first manual import: a phone that has had none keeps the roots in the system's own.
    import_store=$WEB_STORE
    if [ ! -f "$WEB_STORE" ]; then
        import_store=$SYSTEM_STORE
        log "certs: this phone has no user store yet, importing into the system's"
    fi
    if ! run_certstore_tool import "$import_store" "$CERTS_WORK/mozilla.db"; then
        return 1
    fi
    if [ -f "$SHARED_STORE" ]; then
        if ! run_certstore_tool import "$SHARED_STORE" "$CERTS_WORK/mozilla.db"; then
            return 1
        fi
    fi
    run_certstore_tool remove-expired "$SYSTEM_STORE"
}

# The process every Cascades app is forked from: it reads the theme when it starts.
cascades_host() {
    pidin arg 2> /dev/null < /dev/null | awk '$2 == "/bin/cascades" && $3 == "/dev/cascades" {print $1; exit}'
}

# Apps that run all the time and take the system's theme.
theme_app_pids() {
    pidin arg 2> /dev/null < /dev/null | awk '$2 ~ /^app\/native\/(libphone|libsettings|libsys\.pim\.calendar|NotificationsCard|libsys\.filepicker)/ {print $1}'
}

# The Hub and its cards: their files change with the theme, so they restart only when it is chosen, not at boot.
hub_app_pids() {
    pidin arg 2> /dev/null < /dev/null | awk '$2 ~ /^app\/native\/(libsys\.pim\.messages|EmailCard|EmailComposeCard|AttachmentsCard)/ {print $1}'
}

# The folder of an installed package, into package_found: /apps/<id>.* also matches a package whose name only begins
# with <id>. Returns 1 when there is none.
find_package() {
    for package_found in /apps/"$1".*; do
        if [ -d "$package_found" ] && grep "^Package-Name: $1" "$package_found/META-INF/MANIFEST.MF" 2> /dev/null < /dev/null | grep -v "^Package-Name: $1\.[a-z]" > /dev/null; then
            return 0
        fi
    done
    package_found=
    return 1
}

# The dark copies, made once from the system's files while nothing of ours is linked over them. Only what differs is kept.
# $1 is the Hub's assets, $2 the light icons. Returns 1 with theme_error set.
prepare_dark_files() {
    if [ -e "$THEME_DARK/ready" ]; then
        return 0
    fi
    rm -rf "$THEME_DARK" < /dev/null
    if ! theme_error=$(mkdir -p "$THEME_DARK/assets" "$THEME_DARK/cards" 2>&1 < /dev/null); then
        return 1
    fi
    cd "$1" || return 1
    for hub_file in $(find . -name "*.qml" < /dev/null); do
        hub_file=${hub_file#./}
        if ! theme_error=$( { sed -e '/[Bb]ackground\|bgColor\|bg_color\|BgColor/s/Color\.White/Color.create("#121212")/g' \
                    -e '/[Bb]ackground\|bgColor\|bg_color\|BgColor/s/"#[fF][fF][fF][fF][fF][fF]"/"#121212"/g' \
                    -e '/[Bb]ackground\|bgColor\|bg_color\|BgColor/s/"#[fF][aA][fF][aA][fF][aA]"/"#1a1a1a"/g' \
                    -e '/[Bb]ackground\|bgColor\|bg_color\|BgColor/s/"#[fF]0[fF]0[fF]0"/"#1e1e1e"/g' \
                    -e '/[Bb]ackground/s/"#[cC][aA][cC][aA][cC][aA]"/"#3a3a3a"/g' \
                    -e '/[Bb]ackground/s/"#[cC]6[cC]6[cC]6"/"#3a3a3a"/g' \
                    -e '/[Bb]ackground/!s/"#191919"/"#e8e8e8"/g' \
                    -e '/[Bb]ackground/!s/"#262626"/"#f2f2f2"/g' \
                    -e '/[Bb]ackground/!s/"#323232"/"#e6e6e6"/g' \
                    -e '/[Bb]ackground/!s/"#555555"/"#b8b8b8"/g' \
                    -e '/[Bb]ackground/!s/"#646464"/"#a8a8a8"/g' \
                    "$hub_file" > "$THEME_TMP"; } 2>&1 < /dev/null ); then
            return 1
        fi
        if [ "$(cksum < "$THEME_TMP")" != "$(cksum < "$hub_file")" ]; then
            dark_file=$THEME_DARK/assets/$hub_file
            if ! theme_error=$( { mkdir -p "${dark_file%/*}" && cp "$THEME_TMP" "$dark_file"; } 2>&1 < /dev/null ); then
                return 1
            fi
        fi
    done
    rm -f "$THEME_TMP" < /dev/null
    cd "$2" || return 1
    for hub_file in $(find . -name "*.png" < /dev/null); do
        hub_file=${hub_file#./}
        if [ -f "$1/$hub_file" ]; then
            dark_file=$THEME_DARK/assets/$hub_file
            if ! theme_error=$( { mkdir -p "${dark_file%/*}" && cp "$hub_file" "$dark_file"; } 2>&1 < /dev/null ); then
                return 1
            fi
        fi
    done
    for dark_page in $DARK_STYLE_PAGES; do
        if ! add_dark_style "${dark_page%%:*}" "${dark_page##*:}"; then
            return 1
        fi
    done
    if ! theme_error=$( { chmod -R 755 "$THEME_DARK" && : > "$THEME_DARK/ready"; } 2>&1 < /dev/null ); then
        return 1
    fi
    log "theme: the dark copies are made"
    return 0
}

# The app's first page asks for the dark style: a property of our own on the top-level object, so nothing the page declares
# is declared twice. $1 is the package, $2 the page. A page that is not as expected is left alone and logged. Returns 1 with theme_error set.
add_dark_style() {
    if ! find_package "$1"; then
        log "theme: $1 is not installed"
        return 0
    fi
    page_file=$package_found/native/assets/$2
    if [ "$1" = sys.pim.messages ]; then
        dark_file=$THEME_DARK/assets/$2
        if [ -f "$dark_file" ]; then
            page_file=$dark_file
        fi
    else
        dark_file=$THEME_DARK/cards/$1/$2
    fi
    if [ ! -f "$page_file" ] || [ "$(grep -c '^[A-Z][A-Za-z]* *{' "$page_file" < /dev/null)" != 1 ]; then
        log "theme: $1 $2 has no single top-level object, left as it is"
        return 0
    fi
    if ! theme_error=$( { sed 's/^[A-Z][A-Za-z]* *{/& property bool tweakerDarkStyle: Application.themeSupport.setVisualStyle(VisualStyle.Dark) === undefined;/' "$page_file" > "$THEME_TMP" && mkdir -p "${dark_file%/*}" && cp "$THEME_TMP" "$dark_file" && rm -f "$THEME_TMP"; } 2>&1 < /dev/null ); then
        return 1
    fi
    return 0
}

# $1 linked over $2, in memory. Already linked is fine. Returns 1 with theme_error set.
link_dark_file() {
    case "$(ls -l "$2" 2>&1 < /dev/null)" in
        *" -> $1"*)
            return 0
            ;;
    esac
    if ! theme_error=$(ln -sP "$1" "$2" 2>&1 < /dev/null); then
        return 1
    fi
    case "$(ls -l "$2" 2>&1 < /dev/null)" in
        *" -> $1"*)
            return 0
            ;;
    esac
    theme_error="the link over $2 is not there after ln"
    return 1
}

# The dark copies over the system's files. $1 is the Hub's assets. Returns 1 with theme_error set.
link_hub_dark() {
    cd "$THEME_DARK/assets" || return 1
    for hub_file in $(find . -type f < /dev/null); do
        hub_file=${hub_file#./}
        if ! link_dark_file "$THEME_DARK/assets/$hub_file" "$1/$hub_file"; then
            return 1
        fi
    done
    for dark_card in "$THEME_DARK"/cards/*; do
        if [ -d "$dark_card" ] && find_package "${dark_card##*/}"; then
            cd "$dark_card" || return 1
            for hub_file in $(find . -type f < /dev/null); do
                hub_file=${hub_file#./}
                if ! link_dark_file "$dark_card/$hub_file" "$package_found/native/assets/$hub_file"; then
                    return 1
                fi
            done
        fi
    done
    log "theme: the Hub's dark files are linked"
    return 0
}

# Only a link that goes to our copies is removed, never a file.
unlink_dark_file() {
    case "$(ls -l "$1" 2>&1 < /dev/null)" in
        *" -> $THEME_DARK/"*)
            rm -f "$1" < /dev/null
            ;;
    esac
}

# Our links off. $1 is the Hub's assets.
unlink_hub_dark() {
    if [ ! -d "$THEME_DARK" ]; then
        return 0
    fi
    cd "$THEME_DARK/assets" || return 0
    for hub_file in $(find . -type f < /dev/null); do
        hub_file=${hub_file#./}
        unlink_dark_file "$1/$hub_file"
    done
    for dark_card in "$THEME_DARK"/cards/*; do
        if [ -d "$dark_card" ] && find_package "${dark_card##*/}"; then
            cd "$dark_card" || return 0
            for hub_file in $(find . -type f < /dev/null); do
                hub_file=${hub_file#./}
                unlink_dark_file "$package_found/native/assets/$hub_file"
            done
        fi
    done
    log "theme: the Hub's dark files are unlinked"
}

# The theme set and the host stopped; the system starts it again when the next app needs it, so it is not waited for.
# theme_changed says whether anything was to do. Returns 1 with theme_error set.
apply_theme() {
    theme_changed=
    if grep "^defaultTheme::$1\$" "$THEME_PPS" > /dev/null 2>&1 < /dev/null; then
        log "theme: already $1"
        return 0
    fi
    if ! theme_error=$( { echo "defaultTheme::$1" >> "$THEME_PPS"; } 2>&1 < /dev/null ); then
        return 1
    fi
    host_pid=$(cascades_host)
    if [ -n "$host_pid" ]; then
        kill "$host_pid"
        waited=0
        while [ "$(cascades_host)" = "$host_pid" ] && [ "$waited" -lt 10 ]; do
            sleep 1 < /dev/null
            waited=$((waited + 1))
        done
    fi
    theme_changed=1
    log "theme: $1, the Cascades host stopped (it was $host_pid)"
    return 0
}

# Asked nicely first: the file picker ignores that. $1 is the list of pids.
restart_pids() {
    for app_pid in $1; do
        kill -TERM "$app_pid"
    done
    sleep 3 < /dev/null
    for app_pid in $1; do
        kill -9 "$app_pid" 2> /dev/null
    done
}

restart_theme_apps() {
    restart_pids "$(theme_app_pids)"
    log "theme: the apps restarted"
}

phone_is_idle() {
    [ "$(sed -n 's/^phone_state:://p' /pps/services/phone/public/status 2> /dev/null < /dev/null)" = idle ]
}

# Nothing closes in someone's hands: the apps go once the screen is off and there is no call, for up to 12 hours. In the
# background, so that the boot start returns at once.
restart_theme_apps_later() {
    (
        exec < /dev/null > /dev/null 2>> "$LOG" 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&-
        tries=0
        while [ "$tries" -lt 720 ]; do
            brightness=$(sed -n 's/^CurrentBrightness:n://p' /pps/services/backlight/display0/state)
            case "$brightness" in
                0 | 0.0 | 0.00 | 0.000)
                    if phone_is_idle; then
                        restart_theme_apps
                        exit 0
                    fi
                    ;;
            esac
            tries=$((tries + 1))
            sleep 60
        done
        log "theme: the screen did not go off in 12 hours, the apps were not restarted"
    ) &
}

# The Hub opened the font before the link changed. Stopped, the system starts it again at once, with the new one.
restart_hub() {
    hub_pids=$(pidin arg 2> /dev/null < /dev/null | awk '$2 == "app/native/libsys.pim.messages.so.1.0.0" {print $1}')
    for hub_pid in $hub_pids; do
        kill -TERM "$hub_pid"
        log "font: the Hub restarted (it was $hub_pid)"
    done
}

# Uninstalled for sure: APPS can be read - other packages are there - and neither the package nor its sandbox is
# left. An empty or unreadable APPS says nothing, so no.
app_uninstalled() {
    set -- "$APPS"/*
    if [ ! -e "$1" ]; then
        return 1
    fi
    for left in "$APPS"/doctorrokter.Tweaker.* "$APPDATA"/doctorrokter.Tweaker.*; do
        if [ -e "$left" ]; then
            return 1
        fi
    done
    return 0
}

# The guard goes after SETTLE s, or at once on a clean stop (a reboot from the menu sends a signal, a crash does
# not). Lets go of everything the caller gave it, so the boot start returns at once.
release_guard_later() {
    (
        exec < /dev/null > /dev/null 2>> "$LOG" 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&-
        trap 'rm -f "$GUARD"; log "the boot guard is off: a clean stop"; exit 0' TERM
        # wait, not a plain sleep: the shell runs the trap during wait at once.
        sleep "$SETTLE" &
        wait $!
        rm -f "$GUARD"
        log "the boot guard is off: the phone stayed up for $SETTLE s"
    ) &
}

boot_start() {
    if app_uninstalled; then
        sleep 5 < /dev/null
        if app_uninstalled; then
            log "the app is uninstalled: $ADDON goes"
            rm -rf "$ADDON" < /dev/null
            exit 0
        fi
    fi
    if [ -e "$OFF" ]; then
        log "exit: the off switch is on: $OFF"
        exit 0
    fi
    if [ -e "$GUARD" ]; then
        rm -f "$GUARD" < /dev/null
        log "exit: the last boot went down within $SETTLE s of applying, so nothing this time"
        exit 0
    fi
    if [ ! -e "$ON/emoji-font" ] && [ ! -e "$ON/system-theme" ] && [ ! -e "$ON/hub-theme" ]; then
        log "done: nothing is on"
        exit 0
    fi
    if ! { true > "$GUARD"; } 2> /dev/null; then
        log "exit: the guard cannot be created, so nothing is applied"
        exit 0
    fi
    # The Hub restarts once, last: after the theme has stopped the Cascades host and with everything linked.
    hub_restart=
    if [ -e "$ON/system-theme" ]; then
        if ! IFS= read -r wanted_theme < "$ON/system-theme"; then
            log "theme: cannot read $ON/system-theme"
        elif ! apply_theme "$wanted_theme"; then
            log "theme: cannot set it: $theme_error"
        elif [ -n "$theme_changed" ]; then
            restart_theme_apps_later
        fi
    fi
    if [ -e "$ON/hub-theme" ] && IFS= read -r wanted_hub < "$ON/hub-theme" && [ "$wanted_hub" = black ] && [ -e "$THEME_DARK/ready" ] && find_package sys.pim.messages; then
        if link_hub_dark "$package_found/native/assets"; then
            hub_restart=1
        else
            log "theme: cannot link the Hub's dark files: $theme_error"
        fi
    fi
    if [ -e "$ON/emoji-font" ]; then
        if [ ! -f "$OUR_FONT" ]; then
            log "font: on, but $OUR_FONT is not there"
        elif link_font; then
            if ! make_lists || ! link_lists; then
                log "font: the character lists: $list_error"
            fi
            hub_restart=1
        else
            log "font: cannot link: $link_error"
        fi
    fi
    if [ -n "$hub_restart" ]; then
        restart_hub
    fi
    release_guard_later
    log "done"
    exit 0
}

case "$mode" in
    install)
        install_hook "$2"
        if [ -n "$hook_copied" ]; then
            echo "result=ok"
        else
            echo "result=same"
        fi
        ;;
    font-on)
        install_hook "$2"
        case "$3" in
            /*)
                ;;
            *)
                fail "not a full path: $3"
                ;;
        esac
        if [ ! -f "$3" ]; then
            fail "no such file: $3"
        fi
        if ! copy_whole "$3" "$OUR_FONT" 644; then
            fail "cannot write $OUR_FONT: $copy_error"
        fi
        if ! { true > "$ON/emoji-font"; } 2> /dev/null; then
            fail "cannot write $ON/emoji-font"
        fi
        if ! link_font; then
            fail "cannot link the font: $link_error"
        fi
        if ! make_lists || ! link_lists; then
            fail "cannot open the emoji range: $list_error"
        fi
        restart_hub
        log "done"
        echo "result=ok"
        ;;
    font-off)
        rm -f "$ON/emoji-font" < /dev/null
        if ! unlink_font; then
            fail "cannot take the link off: $link_error"
        fi
        if ! unlink_lists; then
            fail "cannot take the character lists off: $list_error"
        fi
        restart_hub
        # After the Hub: what has the file open keeps reading it, new opens get the system's.
        rm -f "$OUR_FONT" < /dev/null
        log "done"
        echo "result=ok"
        ;;
    system-theme)
        install_hook "$2"
        case "$3" in
            black | white)
                ;;
            *)
                fail "unknown theme: $3"
                ;;
        esac
        if ! { echo "$3" > "$ON/system-theme"; } 2> /dev/null; then
            fail "cannot write $ON/system-theme"
        fi
        if ! apply_theme "$3"; then
            fail "cannot set the theme: $theme_error"
        fi
        if [ -n "$theme_changed" ]; then
            if phone_is_idle; then
                restart_theme_apps
            else
                restart_theme_apps_later
            fi
        fi
        log "done"
        echo "result=ok"
        ;;
    hub-theme)
        install_hook "$2"
        case "$3" in
            black | white)
                ;;
            *)
                fail "unknown theme: $3"
                ;;
        esac
        if [ ! -d "$4" ]; then
            fail "no such folder: $4"
        fi
        if ! find_package sys.pim.messages; then
            fail "the Hub is not installed"
        fi
        hub_assets=$package_found/native/assets
        if [ "$3" = black ]; then
            if ! prepare_dark_files "$hub_assets" "$4"; then
                fail "cannot make the Hub's dark files: $theme_error"
            fi
            if ! link_hub_dark "$hub_assets"; then
                problem=$theme_error
                unlink_hub_dark "$hub_assets"
                fail "cannot link the Hub's dark files: $problem"
            fi
        else
            unlink_hub_dark "$hub_assets"
            rm -rf "$THEME_DARK" < /dev/null
        fi
        if ! { echo "$3" > "$ON/hub-theme"; } 2> /dev/null; then
            fail "cannot write $ON/hub-theme"
        fi
        restart_pids "$(hub_app_pids)"
        log "theme: the Hub restarted"
        log "done"
        echo "result=ok"
        ;;
    certs-update)
        case "$3" in
            /*)
                ;;
            *)
                fail "not a full path: $3"
                ;;
        esac
        if [ ! -f "$3/mozilla.db" ]; then
            fail "no certificates in: $3"
        fi
        if [ ! -f "$4" ]; then
            fail "no such file: $4"
        fi
        if [ ! -f "$SYSTEM_STORE" ]; then
            fail "the phone's certificate store is not there: $SYSTEM_STORE"
        fi
        if ! update_certs "$3" "$4"; then
            rm -rf "$CERTS_WORK" < /dev/null
            fail "$certs_error"
        fi
        rm -rf "$CERTS_WORK" < /dev/null
        log "done"
        echo "result=ok"
        ;;
    *)
        boot_start
        ;;
esac
exit 0
