# Character assets

**Kenney — Animated Characters Protagonists**, CC0 1.0.

Primary source: https://kenney.nl/assets/animated-characters-protagonists
License: [assets/character/LICENSE.txt](assets/character/LICENSE.txt)

Used: characterMedium.fbx, skaterMaleA.png, and idle/run/jump FBX clips. The project calls the character Scout; that is a project nickname, not an upstream asset name. Runtime scaling gives a wider silhouette and slightly larger head. Additional movement poses are authored in Shmovement; no original-game animation tracks are used.

The download helper reads only the five named archive members and verifies their SHA-256 hashes. Hashes are corroborated by the corresponding LFS pointers in the public [asset mirror](https://github.com/series-ai/jam-ready-assets/tree/e93aa129978daafda85f3c907eebc8f1807ec43f/kenney-animated-characters-protagonists/3D/characters). Files are downloaded from Kenney, not from that mirror.

Reference decompilation code is research material, not vendored game source. The optional test harness downloads hash-verified files from n64decomp/sm64 at the revision in `tools/parity/sources.json`, then compiles selected original routines into an ignored, test-only oracle. The oracle and downloaded source are excluded from the game and project bundle. No Nintendo models, textures, animation keyframes, level layouts, audio, or ROM data are included in the game.
