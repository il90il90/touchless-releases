# Shizuku for Touchless

`shizuku.apk` is the official, unmodified Shizuku build by RikkaApps
([github.com/RikkaApps/Shizuku](https://github.com/RikkaApps/Shizuku), Apache License 2.0).
Touchless's **Settings › Shizuku › Install Shizuku** downloads it from here, so a phone without a Google Play account can
install it.

| | |
|---|---|
| Version | 13.6.0 (r1086.2650830c), from the official v13.6.0 release |
| SHA-256 | `6e273ab0e991c4e79bc8b1bbb9b9dd739ccac1a8712a541a214078886b7b790f` |
| Signer (`CN=Rikka`) certificate SHA-256 | `268b5590e868fb08bae7e0ac413564cd1ff88f5ccff74af9dbd0dc918e30db30` |

Touchless installs it only when its package is `moe.shizuku.privileged.api`, it is signed by Rikka's certificate above
and it isn't older than the Shizuku bundled in the app. To update: replace `shizuku.apk` with the new official release
APK (keep the file name) and update this table. No Touchless release is needed.
