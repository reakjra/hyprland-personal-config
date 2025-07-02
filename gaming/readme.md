
# 🌸 Gaming-Related Tweaks/Guides 🌸

> Here there's gonna be my fixes, tweaks and implentation for gaming.

[🍼 Bottles & Steam](#bottles-&-steam)

---

## Bottles & Steam

> first we're gonna install Bottles and Steam which are essentially the only 2 tools I use to play.
```sh
sudo pacman -S bottles steam
```

> Once done, we initialize both Steam and Bottles. After that, we're going to install the latest GE-Proton runner. Currently [GE-Proton10-8](https://github.com/GloriousEggroll/proton-ge-custom/releases/tag/GE-Proton10-8)


> After downloading the `GE-Proton10-8.tar.gz` archive, we're gonna extract it and copy the folder in:
```sh
~/.local/share/Steam/compatibilitytools.d
~/.local.share/bottles/runners
```

> In `steam` we go to settings > Compatibility > Enable compatibility > GE-Proton10-8 | When running a game that is not Linux-native remember to right-click on it > Proprierties > Compatibility > Check `Force the use of a specific Steam play compatibility tool` and select `GE-Proton10-8`

> In `Bottles` click the `+` to create a new bottle. Select the `gaming` type, select `GE-Proton10-8` runner and let it initialize.

