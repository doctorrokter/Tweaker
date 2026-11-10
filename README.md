# Tweaker

System tweaks for rooted BlackBerry 10 phones: newer emoji in every app, up-to-date root certificates, a light or dark system theme.

**Published as is. There is no support: issues and pull requests are closed on purpose. Take it, fork it, do
whatever you want with it.**

## What is here

- `Tweaker/` - the Cascades app and the script it runs as root. `Tweaker/README.md` says how the app is used,
  `Tweaker/docs/TWEAKS.md` holds the design notes.
- `bb-shared/` - only the part of the author's shared BlackBerry 10 library that Tweaker builds with.

The two folders have to stay side by side: the project finds `bb-shared` by a relative path.

## Building

    cd Tweaker
    bash ../bb-shared/tools/build-bar.sh -e production

That needs the BlackBerry 10 Native SDK 10.3.1, which is not here. The default paths in the scripts are the author's: set
`QNX_HOST` and `QNX_TARGET`.

**The two emoji fonts are not here.** The package takes them from `Tweaker/fonts/`, under these names:
`NotoColorEmoji-telegram.ttf` and `NotoColorEmoji-109.ttf`. Both are colour bitmap fonts in the format of Noto Color Emoji. Without
them the package does not build.

The preview pictures of the Telegram style, `Tweaker/assets/images/preview/telegram/<code>.png`, are not here either. Without them
that preview is empty; the app works.

Running it needs a phone with root v4.

## License

MIT, see `LICENSE`. What is by others keeps its own terms: see `THIRD-PARTY.md`.

Telegram is a trademark of Telegram FZ-LLC. This project is not made by them.
