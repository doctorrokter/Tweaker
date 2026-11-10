# Tweaker

System tweaks for BlackBerry 10 phones with root v4. The first one: modern emoji in every app, in the Telegram or Noto style or from a
font file of your own. How it works and where everything is on the phone: [docs/TWEAKS.md](docs/TWEAKS.md). The store's texts:
[STORE.md](STORE.md).

## Building

Sits next to `bb-shared`, and needs the two emoji fonts in `../../blackberry/emoji-font/` (`NotoColorEmoji-telegram.ttf`,
`NotoColorEmoji-109.ttf`): they are made by `bb-shared/tools/emoji_font.py` and kept out of git. From the folder holding this project:

```bash
bash bb-shared/tools/build-bar.sh -e production Tweaker
```

`certs/` is made from bb-shared's `cacert.pem` by `tools/make-certs.sh` (it needs openssl: run it in WSL), when that list is refreshed.

## Art

`bb-shared/tools/gen-art.js`, from this folder. The glyph is the stock BB10 `ic_settings`, in `tools/`.

```bash
node ../bb-shared/tools/gen-art.js --colors "#6b4400,#a87000@55%,#e3a612" --glyph tools/ic_settings.png --radius 0.5 --icon-scale 0.56 --glyph-shadow 0.4 --glyph-heading 90
```

BlackBerry World's `store_icon.png` and `store_banner.png`, not packed into the bar:

```bash
node ../bb-shared/tools/gen-art.js --colors "#6b4400,#a87000@55%,#e3a612" --glyph tools/ic_settings.png --radius 0.5 --icon-scale 0.56 --glyph-shadow 0.4 --glyph-heading 90 --only store --title Tweaker --banner-colors "#100b05,#241808@50%,#4f3506"
```
