<p align="center">
    <img width="256px" src="https://i.postimg.cc/cCR75L44/logo.png" alt="Plugin logo" />
    <h1 align="center">
        A Godot plugin for painting foliage and props on any 3D surface
    </h1>
</p>

![Animated cover](https://i.postimg.cc/tCq8TMBf/cover-gif-lossy.gif)

## What is it for?

It's meant to simplify foliage placement in a natural-feeling way without having to use heightmap terrain or writing procedural placement algorithms.

It can also handle thousands of foliage instances without completely tanking the FPS (with an reasonable setup).

This is a single player plugin and works best with finite medium-sized scenes. Think platformers, shooters, adventure games, anything with a hand-made level.

[![Video preview](https://i.postimg.cc/VsRnZDRn/trailer-thubmnail-360p-ext-compressed.jpg)](https://youtu.be/o_59aTeljpg)

## Stability

Current stable release requires at Godot v3.5.

Want a test-drive? Go to [Releases](https://github.com/dreadpon/godot_spatial_gardener/releases) and get the most recent windows build: `godot_spatial_gardener_showcase_windows_x64.zip`.

![Test-drive](https://i.postimg.cc/cLjzF4dy/showcase-gif-lossy.gif)

## Installation

This plugin is installed the same way as other Godot plugins.

Download the code by clicking green `Code` button and then `Download ZIP`. Unpack it anywhere you like.

Copy the folder `addons/dreadpon.spatial_gardener/` to `res://addons/` in your Godot project and enable it from `Project -> Project Settings -> Plugins`.

![Paint 1](https://i.postimg.cc/rmQFHYgr/paint-1.jpg)

## Tutorial

For a detailed guide you can refer to my tutorial.

It comes in two formats, depending on your preference:

- **[<img src="https://i.postimg.cc/1Xd30ySv/yt-icon-rgb.png" width="16" style="margin-right:4px"/> Video (recommended)](https://youtube.com/playlist?list=PLtsfK5HW0bX-TKR8eO_uKEguii8w9dGIh)**
- **[<img src="https://i.postimg.cc/KzF6WwQx/text-icon.png" width="16" style="margin-right:4px"/> Text](reference/TUTORIAL_ROOT.md)**

Text tutorial is the most up-to-date, but video better illustrates each step due to being a video, duh.

## Contribution

If you want to report a bug or request a feature, you should do so on GitHub using `Issues`.

**[Refer here for more](reference/CONTRIBUTION.md)** details.

## Sponsor this project

You're welcome to support me on:

- **[<img src="https://i.postimg.cc/QCfW2L37/Digital-Patreon-Logo-Fiery-Coral.png" width="16" style="margin-right:4px"/> Patreon](https://www.patreon.com/dreadpon)**
- **[<img src="https://i.postimg.cc/Hkc7hPPJ/Color.png" width="16" style="margin-right:4px"/> Boosty](https://boosty.to/dreadpon)**

This will help make updates for this plugin and embark on any new projects I set my eyes on.

Or join me on my Discord:

- **[<img src="https://i.postimg.cc/0yn7THYP/Discord-Logo-Color.png" width="16" style="margin-right:4px"/> Discord](https://discord.gg/CzRSk8E)**

## Branding

You can use 'Spatial Gardener' logos on the basis of 'fair use' whenever you mention this plugin (e.g. in a video review/tutorial).

As long as you don't modify them in any way, claim as your own or redistribute/resell you should be fine.

**[You can download them here.](https://www.mediafire.com/file/a7a6xoa73mu9e44/spatial_gardener_logos.zip/file)**

## Third-Party Credits

### Algorithms and code architecture

- ***The main inspiration for algorithms behind this plugin - [***mux213***](https://www.reddit.com/user/mux213/) and their [writeup](https://www.reddit.com/r/godot/comments/bfdgc1/experimenting_with_rendering_a_large_asteroid/)***
- Ideas for UI and sphere brush implementations - [***Unreal Engine Team***](https://github.com/EpicGames/UnrealEngine)
- An article that helped me understand the basics of octrees - [Introduction to Octrees by ***Eric Nevala***](https://www.gamedev.net/tutorials/programming/general-and-gameplay-programming/introduction-to-octrees-r3529/)
- A plugin I inspected to understand Godot's plugin-making - [***Zylann's*** HeightMap Terrain](https://github.com/Zylann/godot_heightmap_plugin)
- A 3D selection system tutorial - [3D Selection Tutorial by ***Jonathan Kreuzer***](http://www.3dkingdoms.com/selection.html)
- A basic 3D frustum culling tutorial - [Frustum Culling by ***Dion Picco*** ](https://www.flipcode.com/archives/Frustum_Culling.shtml)

### 3D models

- Locomotive and train carts (used as base meshes) - [Low Poly Wild West Train Diorama by ***Jorma Rysky***](https://sketchfab.com/3d-models/low-poly-wild-west-train-diorama-ac701e3b40794872beeebb6251bf09e0)
- Buildings, caudron, crate, barrel - [eval Village Pack by ***Quaternius***](https://quaternius.com/packs/evalvillage.html)
- Long island - [Animated Rhino Loop on Floating Fantasy Islands by ***LasquetiSpice***](https://sketchfab.com/3d-models/animated-rhino-loop-on-floating-fantasy-islands-dbf8f1da9e594937985b03a037501df1)
- Small islands - [Interdimensional Floating Islands by ***Artbake Graphics***](https://sketchfab.com/3d-models/interdimensional-floating-islands-0742e636aa9a40b5865436511e3595cf)
- Sphere-like island 1, clouds - [Low Poly Flying Island by ***Mohamed Fsili***](https://sketchfab.com/3d-models/low-poly-flying-island-49c22c7d4f3249688a000fc526b84a76)
- Sphere-like island 2, clouds - [Low Poly Island by ***davevink***](https://sketchfab.com/3d-models/low-poly-island-98960ad16eae47b993b0351609e2907b)
- Apple tree, wheat, carrot - [Ultimate Crops Pack by ***Quaternius***](https://quaternius.com/packs/ultimatecrops.html)
- Daisies - [Environoment Pack V.1 by ***Zsky***](https://zsky2000.itch.io/environoment-pack-v1)
- Grass - ***Dreadpon (me :3)***
- Grass tall, rocks - [Low Poly Nature Pack by ***sjolle***](https://sjolle.itch.io/low-poly-nature-pack)
- Liana, moss, bush, bush 1 - [Free Mid Poly Stylized Swamp Remastered by ***EmacEArt***](https://opengameart.org/content/free-mid-poly-stylized-swamp-remastered)
- Rocks, tree pine - [Big LowPoly Environment Pack by ***zisongb***](https://opengameart.org/content/big-lowpoly-environment-pack)
- Tree generic - [Free Low Poly Forest by ***purepoly***](https://sketchfab.com/3d-models/free-low-poly-forest-6dc8c85121234cb59dbd53a673fa2b8f)
- Curved tree - [FREE Remastered - Free Mid Poly Meadows by ***EmacEArt***](https://opengameart.org/content/free-remastered-free-mid-poly-meadows)
- Planet - [Planet by ***P6c6970***](https://sketchfab.com/3d-models/planet-12b9bc3d77984683a39dce16c7ba5a9f)
- Default Blender monkey - [Suzanne by ***SLiD3***](https://www.artstation.com/slid3)

### Audio

- Jump, land, step rock, step wood - [12 Player Movement SFX by ***leohpaz***](https://opengameart.org/content/12-player-movement-sfx)
- Step dirt - [4 dry snow steps by ***qubodup***](https://opengameart.org/content/4-dry-snow-steps)
- Steam engine - [Steam boiler sound loop by ***bart***](https://opengameart.org/content/steam-boiler-sound-loop)
- Rails - [Roller coaster by ***Bruce Burbank***](https://freesound.org/people/Bruce%20Burbank/sounds/136596/)
- Birds singing - [Peaceful ambiance in pine forest by ***dobroide***](https://freesound.org/people/dobroide/sounds/22384/)
- Wind blowing - [Wind blowing gusting through french castle tower by ***Astounded***](https://freesound.org/people/Astounded/sounds/483479/)
- Trailer music - [Where We Wanna Go by ***Patrick Patrikios***](https://www.youtube.com/watch?v=EGhPElIATSI)

### Artwork

- Tree sprites - [Tree Collection v2.6 - Bleed's Game Art by ***Bleed***](https://opengameart.org/content/tree-collection-v26-bleeds-game-art)
- Surface normal illustration - [Curved surface showing the unit normal vectors by ***Chetvorno***](https://commons.wikia.org/wiki/File:Normal_vectors_on_a_curved_surface.svg)
- Button prompts - [FREE Keyboard and controllers prompts pack by ***xelu***](https://opengameart.org/content/free-keyboard-and-controllers-prompts-pack)
