# 🌸 Waybar (HyDE) 🌸

> I think HyDE uses `~/.local/share/waybar/layouts/hyprdots` to save waybar's configurations, so back it up there your own. 
Furthermore, keep mind the CSS is personalized through the theme, Es. `Kuroi Hana/Configs/.configs/hyde/themes/Kuroi Hana/waybar.theme`. And, to update everything, use waybar.py command in the terminal, particularly waybar.py -G to update the `include.json` files to add a customized .jsonc from `~/.local/share/waybar/modules`.
For a dropdown menu it uses XML, which can be added to `~/.local/share/waybar/menus`


## 🌸 Files
> NOTE: any update made with waybar should be followed by `waybar.py -G` command to apply the changes.


> `reakjra.jsonc`. This one modules the waybar's look, like pills, icons, etc. etc. This goes in:
```sh
~/.local/share/waybar/layouts/hyprdots/<reakjra.jsonc>
```

> `/menus/<menu>.xml` are files to make a waybar's menu, they are strictly used by `/modules/<module>.jsonc` files. 
```sh
~/.local/share/waybar/menus/<menu.xml>
```

> `/modules/<module>.jsonc` files are basically the things you see in the waybar. Like the clock, the app icons, the RAM usage, etc. etc. these files contains the information about how they behave and what they do
```sh
~/.local/share/waybar/modules/<module.jsonc>
```
