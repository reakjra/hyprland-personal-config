
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

> In `steam` we go to `settings` > `Compatibility` > `Enable compatibility` > `GE-Proton10-8`

> When running a game that is not Linux-native remember to `right-click on it` > `Proprierties` > `Compatibility` > Check `Force the use of a specific Steam play compatibility tool` and select `GE-Proton10-8`


> In `Bottles` click the `+` to create a new bottle. Select the `gaming` type, select `GE-Proton10-8` runner and let it initialize.

# Non-Steam Games

> essentially, I'd use steam as the main library of all the games. For all the games that have .exe(s) it should be simple as adding the .exe into steam's library and forcing game compatibility.

> Since the game's ugly, go to [SteamGridDB](https://www.steamgriddb.com/) where you can find all the icons, banners, artworks of the games you want. Download them, I reccomend to create an `Icons` folder inside each game's directory where you´d put the game's banners. On steam, right click on the game, click `manage` and find out how to change every banner available. If you go to proprierties and click the little grey icon it'll let you change the small icon of the game. Mind that it may require to restart steam to see the changes.

# Adding a Bottles' game on Steam

> Essentially the same. However, you need to use `bottles-cli` to run the game. 

1. Add a random app to the Steam's library, doesn´t matter what, since after that, you're gonna erase the `target` and `start in` fields.
   
   
3. This is the standard command to run an application through bottles-cli:
   ```sh
   bottles-cli run -b "<bottle_name>" -e "<directory>"
   ```
   
   
4. We're gonna take as example Zenless Zone Zero. Mind I've downloaded it in: `/home/<username>/nvme1n1p6/ZenlessZoneZero Game/`
   > NOTE: Keep in mind that bottles needs to reach the `Z:` drive in this case, since the game is not in the Bottle virtual `C:` drive. I don´t know if with flatpak version works easily as that.
   Addressing where our .exe game is, we change the Steam's application `target` to:
   ```sh
   bottles-cli run -b "ge-proton10-8" -e "Z:\\home\\reakjra\\nvme1n1p6\\ZenlessZoneZero Game\\ZenlessZoneZero.exe"  
   ```
   > NOTE: We're not going to force compatibility since Bottles will handle everything.

