# Tweaker

System tweaks for BlackBerry 10 phones with the system kit (kit v4). One Cascades app, no headless service until a tweak needs a
process of its own. The first tweak is the emoji font.

## Layout

| Path | What |
|---|---|
| `src/`, `assets/` | Momentics' own: `applicationui`, `main`, the QML |
| `core/` | the app's classes, listed by `core/core.pri` and not by Momentics: `Settings`, `Changelog`, `EmojiFont`, `ScriptFonts` |
| `boot/tweaker-boot.sh` | the system side, one file: the app's actions and the boot start |
| `scriptfonts/` | the rare alphabets' data, made by `tools/script-fonts.js`: `components.cfr-part` (their place in the lists), `phone-coverage.txt`, `REPORT.md`, `samples.txt`, and `OFL.txt`; the fonts themselves are in `E:\dev\blackberry\noto-scripts\`, outside the repo |
| `tools/script-fonts.js`, `tools/unicode/Blocks.txt` | chooses the fonts and writes what is above (see "Rare alphabets") |
| `assets/images/preview/scripts/` | the rare alphabets page's pictures: two names as the phone draws them now and with the fonts |

From bb-shared: L10n, `dimens`, Loader, the settings rows, the coffee card, `root/RootScript` (the call of `__root`).
The built-in fonts come from `E:\dev\blackberry\emoji-font\`, outside the repo: `NotoColorEmoji-telegram.ttf` (the default style) and
`NotoColorEmoji-109.ttf`.

## Building

From `momentics-projects`:

```bash
bash bb-shared/tools/build-bar.sh -e production Tweaker
```

## The system side

`boot/tweaker-boot.sh`, see the header of the file and `bb-shared/BB10-SYSTEM-AUTOSTART.md`.

| On the phone | What |
|---|---|
| `/var/addons/tweaker/init/start.sh` | the script itself; the firmware runs it at every boot |
| `/var/addons/tweaker/on/emoji-font` | the tweak is on |
| `/var/addons/tweaker/fonts/NotoColorEmoji.ttf` | the font in use |
| `/var/addons/tweaker/lists/SlatePro-*_Color.cfr` | the system's 8 composite font descriptions as the tweaks that are on want them, made on the phone by `sed` from the system's at every change and boot: the emoji component's list widened, the rare alphabets' components put in |
| `/var/addons/tweaker/on/script-fonts` | the rare alphabets tweak is on |
| `/var/addons/tweaker/script-fonts/` | its fonts, linked one by one into `/base/usr/fonts/font_repository/monotype/`, and `components.cfr-part` |
| `/var/addons/tweaker/on/system-theme` | `black` or `white`: the theme set again at every boot |
| `/var/addons/tweaker/on/hub-theme` | `black` or `white`: the Hub and email, a choice apart |
| `/var/addons/tweaker/theme-dark/` | the dark copies of the Hub's QML and icons and of the cards' first pages, linked over the system's |
| `/var/addons/tweaker/boot-guard` | exists for 60 s after applying: the boot-loop breaker |
| `/accounts/1000/shared/misc/tweaker-boot.txt` | the log; Settings > Boot log shows it |
| `/accounts/1000/shared/misc/tweaker-off` | a file or folder here: nothing is applied at boot |

A new tweak is a function in the script, a marker in `on/`, a class in `core/` and a row in `TweaksPage`.

## What restarts when (the owner's rule, 2026-11-19)

Every change in the app works at once, is kept as a marker in `on/`, and the boot start applies it again. What has to restart:

| Change | Cascades host | Hub | The system's apps (phone, Settings, calendar, notifications, file picker) |
|---|---|---|---|
| Emoji font: on, off, style, own file | stopped | restarted | at once with no call, else once the screen is off |
| Rare alphabets: on, off | stopped | restarted | the same |
| System theme | stopped | not touched: the Hub keeps its own theme | the same |
| Hub theme | not needed | restarted with its email cards | - |
| Boot start | stopped ONCE, after the theme, the Hub's files, both fonts and the lists are all set | restarted ONCE | ONCE, once the screen is off and there is no call |

One change at a time: every change from the app and the boot start take `/var/addons/tweaker/lock` (a folder with the run's pid);
a second change waits for the first, up to 120 s, so two quick taps on different tweaks cannot remake the lists at once. A lock whose
run is gone (killed, a reboot) is taken over. Proven on .93 (2026-11-19): rare alphabets and the emoji font started a second apart,
the second waited 10 s, both lists right.

The host is stopped, not started: the system starts it again for the next app, and from then on every app reads the new theme
and lists. Apps open at the time keep the old ones until they are closed and opened again. The navigator (status bar, home screen)
and the keyboard start before the boot start and are not restarted: they keep the system's font and lists.

## How the emoji got fixed

The newer emoji were cut by the character lists in the `.cfr` files (`bb-shared/BB10-SYSTEM-EMOJI.md`, section 2), not by the font or
`libWTLE.so.1`: the engine asks no font about a character outside its list. Above U+1F680 the list is opened to U+1FAFF; below U+1F000 it
names exactly what the font has, because a wide range could get in the way of the components after it.

A process that was running before the link keeps the old font and lists until it restarts: the boot script restarts the Hub. The navigator
and the keyboard start before the hook and are not restarted.

**Cascades apps do NOT take the lists by being opened again** (found 2026-11-19 on .151, wiped, the font tweak on, the theme tweak not
used): every Cascades app is forked from the Cascades host (`/bin/cascades /dev/cascades`, see the theme below), which read the stock
`.cfr` lists when it started - at boot, before the hook - and every app forked from it inherits them, while the font FILE is opened late,
so it is Tweaker's. The picture: the older emoji in the new font's style, everything past U+1F6C5 an empty box (Telega's emoji picker:
🤣 🫠 🥰 🤩 🥲), in an app installed and started hours after the tweak. A reboot does not cure it (the host starts before the hook again).
Stopping the host does: the owner switched the theme tweak there and back, reopened the app - every emoji drew. On .93 it never showed
because the theme tweak is on there and stops the host after linking. Since 1.1.0 the font tweak stops the host itself after it has
linked the font and the lists - when turned on (`font-on`) and at boot - and the Hub restarts after it, as with the theme. Apps already
open keep the stock lists until they are closed and opened again.

The trace that found it: `bb-shared/debug/text-engine-trace.c`.

## Rare alphabets

Names written in "fancy text" use letters of other scripts that look like ours: 𐌺᧘ᥲʙᥙᥲᴛуρᥲ reads "Клавиатура" with Gothic, Tai
Le and New Tai Lue letters, 𝓑𝓵𝓪𝓬𝓴𝓑𝓮𝓻𝓻𝔂 is the Mathematical Alphanumeric block. Examples on the page and here are made up: never a real
person's or channel's name (the owner, 2026-11-19). They are real letters, so Unicode
normalisation does nothing for them, and the stock phone draws empty boxes: no component of the composite lists names them.

The first version had 16 fonts for the fancy text kinds; then Egyptian hieroglyphs (𓆉 𓆏 𓃰) came as boxes in a chat, and the owner
asked for the whole gap at once (2026-11-19): every block the phone lacks, filled from Noto, the set Android draws with.

**The set.** `tools/script-fonts.js make <a folder of Noto *-Regular.ttf> --copy-to E:\dev\blackberry\noto-scripts` reads each font's
cmap and gives it the characters it has that neither the phone (`phone-coverage.txt`, from the Passport's `SlatePro-Regular_Color.cfr`
by `coverage`) nor a font before it has; below U+0300 nothing is taken. Order: each script's own font by name, then Symbols, Symbols 2,
Math, Music and Noto Sans as the last gap filler. Of the 206 Noto families (`github.com/notofonts/notofonts.github.io`, `fonts/<family>/hinted/ttf/`,
downloaded to `E:\dev\blackberry\noto-all\` on 2026-11-19), out are: the scripts the phone draws itself with its own shaping (Arabic,
Hebrew, the Indic ones it has, Thai: no word may mix two fonts), the Serif twin where a Sans exists, the joined Adlam and N'Ko (their
Unjoined fonts are in), test and display variants, and three on purpose: SignWriting (5 MB), Tangut (3 MB), Duployan (1.5 MB). Result:
147 fonts, 11.9 MB, 18 712 characters; `REPORT.md` lists each font with the blocks it fills, `samples.txt` a line of each to paste into
a chat and look at on the phone, and `assets/scriptsamples.json` the same for the app. To refresh after a Unicode or Noto release:
download again, run `make`, rebuild; nothing else changes.

**"What it adds".** A button under the pictures pushes `ScriptSamplesPage`: every script with its letters as live text, drawn by the
phone, so it doubles as the check on the phone itself. The pictures above it are PNGs and show the same whatever is on; the emoji font
shows at once because its file is opened late, while the new components live in the character lists a Cascades app takes from its
host when it starts. So a Tweaker started before the fonts were turned on or off still draws the old way: the app keeps the time of
its last change (`scriptFonts/appliedAtMs`) and the page asks to close and open Tweaker again (`needsReopen`). A card would always be a
fresh process, but a new invoke target can need a reinstall, and uninstalling Tweaker wipes its system side at the next boot.

Each font's component goes after `</LanguagePreferredList>`, before Pictographs MT and DejaVu Sans, and names only what the font adds:
what draws today keeps its look. All 8 weights name the same Regular files. 147 more components were taken by the engine on .93 with no
complaint in the log (2026-11-19); the lists are 48 KB each.

**Not covered.** Scripts whose letters join or reorder (Khmer, Myanmar, Tibetan, Mongolian, Javanese...) get glyphs, but whether the
system's engine builds their syllables is for the eye on the phone (`samples.txt`). The status bar, the home screen and the keyboard
never take any of it: they start before the boot start.

The fonts are linked one by one into the system's font folder, where `locationHint` looks. The lists are shared with the emoji tweak:
`apply_lists` takes our links off, makes each list afresh from the system's (the emoji range if that tweak is on, the components if this
one is) and links them again, or leaves the system's when neither is on. It restarts what the emoji font does ("What restarts when").

## Certificates

`certs/mozilla.db` is Mozilla's list with the attributes the phone's certificate manager keeps for each certificate (`tools/make-certs.sh`, in
WSL, when `cacert.pem` in bb-shared is refreshed). Which of the system's roots are expired is decided on the phone, by their dates: the sets differ
(125 on a Passport with 10.3.3, 119 on a Z10 with 10.3.2). BlackBerry's own are kept, and a clock that cannot be right removes nothing.

The manager keeps its stores in SQLite, `certstore.db` under `/var/certdb`; files added to `/var/certmgr` change nothing. The button adds the
roots to `web_trusted` (and to `shared_trusted` where it exists: these two are what a manual import writes to) and removes the expired ones
from `rim_trusted`, in place, through `boot/certstore-tool` (`tools/build-certstore-tool.sh`). The records are byte for byte what the manager
writes itself. `web_trusted` appears with a phone's first manual import: a Z10 on 10.3.2 had none, and such a phone keeps the roots in `rim_trusted`. The manager keeps these files open and asks them at every request, so a change made through SQLite is served at once. Swapping
the file with `mv` is not: it stays on the old one until a reboot. Once written, nothing depends on Tweaker: no link, no boot step.

Three traps on kit v4. As the system user the tool is refused ("Operation not permitted"), as the store's own user (`on -u 110:110`) it runs; started
from the app even that is refused until the tool's path has gone through `/proc/boot/pathtrust`, as in Tunnel's boot script. SQLite
cannot open a file on `/tmp` (disk I/O error), so the script works in `/var/tmp/tweaker-certs`, which a reboot clears anyway. A process without
an app's groups does not see `web_trusted` at all; for a check run as `on -u 100991000:10099,1000,1005`.

Measured on .93 (kit v4, 2026-11-10) as an app, TLS 1.2 forced: `valid-isrgrootx2.letsencrypt.org` and Amazon's three test sites fail with
the phone's own roots and pass after the update, with 121 roots in `web_trusted` and 88 of 125 left in `rim_trusted`, at once and after a
reboot. Google, GitHub, Telegram and Microsoft pass before and after.

**The limit is not the certificates.** The system's `libssl.so.2` (1.0.2g) turns TLS 1.1 and 1.2 off in every new context (default options
`0x1b000004`): a client that does not turn them back on stays at TLS 1.0, and nearly every site refuses it before any certificate is
looked at. Which system apps do turn them on is not known.

## System theme

From https://github.com/damianolampisti00/bb10-dark-theme: the method and the recolouring rules (MIT), and `theme/hub_icons`, the Hub's
icons lightened (BlackBerry's artwork, for use on your own device, so not for a store upload). `defaultTheme` in PPS
`/pps/services/deviceproperties` (`white` or `black`) is read by the Cascades host, `/bin/cascades /dev/cascades`, when it starts, and every app is
forked from that host. The system resets the value at every boot, so the boot script sets it again.

The script writes the value, stops the host and restarts the always-running apps that ask for no theme of their own. Measured on .93, 2026-11-10:
the host did not come back within a minute with nothing to start, and the next app started brought it, so it is not waited for. The file picker
ignores TERM, so what is still there after 3 s gets `kill -9`. At boot the apps restart only with the screen off and no call.

The Hub with email and the rest of the system are two choices, `system-theme` and `hub-theme` in the script: every combination was run on .93.

An app whose manifest names `CASCADES_THEME` keeps that theme: dark for Clock, Calculator, Camera, Pictures, bright for Contacts, Chat, BBM.
The Hub, the email viewer and composer and the attachments card name bright too. Their files on disk are never edited: on .93 a Hub with edited
files did not start at two reboots. The dark choice makes copies in `/var/addons/tweaker/theme-dark` (the Hub's QML recoloured, because white
backgrounds and dark text are hardcoded, and its 103 icons) and links them in memory over the system's, again at every boot, so a reboot always
starts from the untouched package. The manifest cannot be linked: the launcher opens it without following links and refuses the app (errno 90,
in `sloginfo`). So the first page of each app gets a property of ours whose binding calls `Application.themeSupport.setVisualStyle(VisualStyle.Dark)`.
The boot script restarts the Hub once, after everything is linked and the Cascades host is stopped (see "What restarts when"). The light choice removes the links.

## State

On .93 (kit v4, 2026-11-10): the app, `__root` from a GUI process, the font and the lists turned on, the Hub taking them, a real reboot
with the hook bringing them back; the certificates from the app's button (build 27). On .54's own ksh: every path of the script, the system's files stock again after turning off.

Production build 13 on .93: changing the style restarts the Hub. Not checked on a phone yet: build 15's drop-down and preview, the older
symbols (❤ ⭐).

1.1.0, build 42 on .93 (2026-11-19), the owner's eye "Все применилось": rare alphabets turned off and on from the app, the system theme
there and back, then a real reboot. The log shows each change in the app stopping the host once and restarting what the table in "What
restarts when" says, and the boot start linking both fonts and the lists, stopping the host once (the theme was already the default
white), restarting the Hub once and the system's apps once, when the screen went off two minutes later. The lists are remade at every
change and boot.

1.1.0, build 44 on .93 (2026-11-19): the full set of 147 fonts and the "What it adds" list, the owner's eye "Всё хорошо": no boxes, the
joining scripts built right. A Z10 on 10.3.2, the owner's eye: the fonts work there, and after a reboot everything is right; once,
after quick changes in the app before the lock (build 45), the Hub did not restart. Not checked: the field phone .151, removing
Tweaker with the fonts on.
