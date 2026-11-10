# Tweaker

System tweaks for rooted BlackBerry 10 phones (root v4). One Cascades app, no headless service until a tweak needs a
process of its own. The first tweak is the emoji font.

## Layout

| Path | What |
|---|---|
| `src/`, `assets/` | Momentics' own: `applicationui`, `main`, the QML |
| `core/` | the app's classes, listed by `core/core.pri` and not by Momentics: `Settings`, `Changelog`, `EmojiFont` |
| `boot/tweaker-boot.sh` | the root side, one file: the app's actions and the boot start |

From bb-shared: L10n, `dimens`, Loader, the settings rows, the coffee card, `root/RootScript` (the call of `__root`).
The built-in fonts come from `E:\dev\blackberry\emoji-font\`, outside the repo: `NotoColorEmoji-telegram.ttf` (the default style) and
`NotoColorEmoji-109.ttf`.

## Building

From `momentics-projects`:

```bash
bash bb-shared/tools/build-bar.sh -e production Tweaker
```

## The root side

`boot/tweaker-boot.sh`, see the header of the file and `bb-shared/BB10-ROOT-AUTOSTART.md`.

| On the phone | What |
|---|---|
| `/var/addons/tweaker/init/start.sh` | the script itself; the firmware runs it at every boot |
| `/var/addons/tweaker/on/emoji-font` | the tweak is on |
| `/var/addons/tweaker/fonts/NotoColorEmoji.ttf` | the font in use |
| `/var/addons/tweaker/lists/SlatePro-*_Color.cfr` | the system's 8 composite font descriptions with the emoji component's character list widened, made on the phone by `sed` |
| `/var/addons/tweaker/on/system-theme` | `black` or `white`: the theme set again at every boot |
| `/var/addons/tweaker/on/hub-theme` | `black` or `white`: the Hub and email, a choice apart |
| `/var/addons/tweaker/theme-dark/` | the dark copies of the Hub's QML and icons and of the cards' first pages, linked over the system's |
| `/var/addons/tweaker/boot-guard` | exists for 60 s after applying: the boot-loop breaker |
| `/accounts/1000/shared/misc/tweaker-boot.txt` | the log; Settings > Boot log shows it |
| `/accounts/1000/shared/misc/tweaker-off` | a file or folder here: nothing is applied at boot |

A new tweak is a function in the script, a marker in `on/`, a class in `core/` and a row in `TweaksPage`.

## How the emoji got fixed

The newer emoji were cut by the character lists in the `.cfr` files (`bb-shared/BB10-SYSTEM-EMOJI.md`, section 2), not by the font or
`libWTLE.so.1`: the engine asks no font about a character outside its list. Above U+1F680 the list is opened to U+1FAFF; below U+1F000 it
names exactly what the font has, because a wide range could get in the way of the components after it.

A process that was running before the link keeps the old font and lists until it restarts: the boot script restarts the Hub, other
apps take them when opened again. The navigator and the keyboard start before the hook and are not restarted.

The trace that found it: `bb-shared/debug/text-engine-trace.c`.

## Certificates

`certs/mozilla.db` is Mozilla's list with the attributes the phone's certificate manager keeps for each certificate (`tools/make-certs.sh`, in
WSL, when `cacert.pem` in bb-shared is refreshed). Which of the system's roots are expired is decided on the phone, by their dates: the sets differ
(125 on a Passport with 10.3.3, 119 on a Z10 with 10.3.2). BlackBerry's own are kept, and a clock that cannot be right removes nothing.

The manager keeps its stores in SQLite, `certstore.db` under `/var/certdb`; files added to `/var/certmgr` change nothing. The button adds the
roots to `web_trusted` (and to `shared_trusted` where it exists: these two are what a manual import writes to) and removes the expired ones
from `rim_trusted`, in place, through `boot/certstore-tool` (`tools/build-certstore-tool.sh`). The records are byte for byte what the manager
writes itself. `web_trusted` appears with a phone's first manual import: a Z10 on 10.3.2 had none, and such a phone keeps the roots in `rim_trusted`. The manager keeps these files open and asks them at every request, so a change made through SQLite is served at once. Swapping
the file with `mv` is not: it stays on the old one until a reboot. Once written, nothing depends on Tweaker: no link, no boot step.

Three traps on root v4. As root the tool is refused ("Operation not permitted"), as the store's own user (`on -u 110:110`) it runs; started
from the app even that is refused until the tool's path has gone through `/proc/boot/pathtrust`, as in Tunnel's boot script. SQLite
cannot open a file on `/tmp` (disk I/O error), so the script works in `/var/tmp/tweaker-certs`, which a reboot clears anyway. A process without
an app's groups does not see `web_trusted` at all; for a check run as `on -u 100991000:10099,1000,1005`.

Measured on .93 (root v4, 2026-11-10) as an app, TLS 1.2 forced: `valid-isrgrootx2.letsencrypt.org` and Amazon's three test sites fail with
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
The boot script restarts the Hub once, after the theme has stopped the Cascades host and with everything linked. The light choice removes the links.

## State

On .93 (root v4, 2026-11-10): the app, `__root` from a GUI process, the font and the lists turned on, the Hub taking them, a real reboot
with the hook bringing them back; the certificates from the app's button (build 27). On .54's own ksh: every path of the script, the system's files stock again after turning off.

Production build 13 on .93: changing the style restarts the Hub. Not checked on a phone yet: build 15's drop-down and preview, the older
symbols (❤ ⭐). Lists already linked are not remade: turning the tweak off and on once, or a reboot, brings a new list.
