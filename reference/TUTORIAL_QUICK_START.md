# [Part 1] Quick-Start Tutorial

**[[Part 2] In-Depth Look ->](TUTORIAL_IN_DEPTH.md)**

## Table of contents
- [Plugin Setup](#plugin-setup)
- [What we're working with](#what-were-working-with)
- [Setting up a Gardener](#setting-up-a-gardener)
- [Creating your first plant](#creating-your-first-plant)
- [Configuring octrees](#configuring-octrees)
- [Variety](#variety)
- [Collision](#collision)
- [Setting up bushes and grass](#setting-up-bushes-and-grass)
- [Aligning to surface normals](#aligning-to-surface-normals)
- [Final steps](#final-steps)

## Plugin Setup
You should have Godot engine installed; if not, you can download it from the official website. 

![001 Godot stable download]()

Recommended version is 3.4.2 and can be easily found on Godot’s GitHub, however, most 3.x versions should be supported. Godot 4 is not supported at the moment.

![002 Godot older downloads]()

Grab a copy of the showcase project from GitHub. Open the main repository page, go to `Releases`, find the latest version and download the `godot_spatial_gardener_demo.zip`. 

![003 Actions to download plugin]()

Save, unpack and launch the project. If editor screams errors at you, it’s probably reimporting the assets and should be fine.

![004 Editor screaming]()

Make sure the plugin is enabled by going to `Project -> Project Settings -> Plugins -> Spatial Gardener` and ticking the `Enable` checkbox.

![005 Enabling plugin]()

## What we're working with

This project comes with a few things besides the plugin itself. In the `demo` folder you’ll see a bunch of files used to build two demo scenes at the very bottom: `showcase.tscn` and `playground.tscn`. 

![006 Demo folder]()

`showcase.tscn` is a full-blown demonstration level that you can play to test the plugin in-game. Play around if you got the time!

`playground.tscn` is where you’re going to work, so open it. This will be our main scene, so you can set it as default in `Project -> Project Settings -> Application -> Run -> Main Scene`.

![007 Setting a main scene]()

To work with the Spatial Gardener you’ll need some level geometry with collision. Here we have an island and two buildings with auto-generated static physics bodies. Take a look at their collision layers.

First layer, `gameplay` is used for game collision such as interaction with the player. The second, `painting` is reserved for foliage painting. Notice how landscape interacts with this layer, but buildings do not. I assume you don’t want to paint on buildings, but it’s up to your artistic choice.

![008 Comparing level collision layers]()

## Setting up a Gardener

Go to the scene tree and add a node called `Gardener`. It will handle the entire drawing process. 

![009 Adding a Gardener]()

Every Gardener maintains a subtree of nodes that are essential for its functionality. You can have however many Gardeners you need, but you should not add or remove any descendants.

![010 Gardener scene tree overview]()

Select your Gardener, and choose its working directory. All your plants and brushes will be saved here. 

Now choose collision layers that our Gardener interacts with. Disable `gameplay` layer and enable `painting`. Now we can paint on landscape objects, but ignore buildings.

![011 Gardener setup]()

Because of some engine quirks, you can see a transform gizmo of your Gardener. It can't be hidden, but it will ignore all your inputs. Instead, your mouse will control a foliage brush.

![012 Gardener transform gizmo]()

## Creating your first plant

Now, to the Gardener panel. Top side is for brush settings, everything else is for plants. In the middle there’s a box with the plus sign button. Click it to create a plant. Now click the plant itself, and you’ll see a list of all its properties.

![013 Gardener side panel with a plant]()

To paint a plant, you mostly need only two basic things: a mesh and a desired density. For the mesh, `LOD Variants` is what you'll use. A bit of theory first.

For plants to look good, they need a lot of polygons and high-res textures. There’s usually hundreds if not thousands of plants in a level. Multiply these and you get a molten Graphics Card. But, we rightfully assume that players can’t see shit in the distance, so it’s fine for faraway plants to have less detail. This concept is called ‘Level of Detail’ or LOD for short. We make 2, 3, 4 separate models, each simpler than the last. And then switch between them depending on the distance.

That’s what `LOD Variants` are for. Add three variants. Now go to `demo -> playground -> plants -> pine` and find three meshes named `plants_tree_pine_lod.mesh`. You should assign them in order of simplification: drag  `plants_tree_pine_lod0.mesh` to the first LOD variant, `plants_tree_pine_lod1.mesh` to second and  `plants_tree_pine_lod2.mesh` to third. 

![014 LOD variants setup with mesh names]()

Next, the density. Set ‘Plants Per 100 Units’ to something small like 15. It defines how many plants to place in a 100x100 units square. This number is very approximate and can be off by around thirty percent. Not to mention circular brush shape does not account for corners. To get the feel of the density, you should play with this number a bit.

![015 setting density]()

Problems may arise at low density and small brush size. If you have obviously too many plants – increase the brush size. Lets use something like 75. You can also drag the Right Mouse Button to quickly set it.

![016 Comparing low desnsity at small brush and big brush]()

Now lets paint. Tick the paint box for our trees, press Left Mouse Button and drag across the island. To center camera on the brush, press `Q` on your keyboard.

![017 Selecting trees for painting]()

That’s it, we now have trees.

![018 Finished tree painting]()

## Configuring octrees

If you go to the `Gardener Debug Viewer` at the top and select `View First Active Plant`, you can see how trees are referenced in 3D space. This structure is called an octree and it optimizes iteration over thousands of spatial objects. This is needed to switch our LODs according to camera distance. 

![019 Debug viewer menu and octree preview]()

Set `LOD Max Distance` to 100, and zoom your camera in and out. Observe how the tree meshes change.

![Trees of different LOD]()

Click `Configure Octrees`. Default values here are meant for something more dense, like bushes. It assumes one hundred objects can fit into one ‘cube’. For trees, lets change `Max Chunk Capacity` to a more reasonable 10 and click `Apply`.

![021 Rebuilding octree]()

By default octree generates in the center of our Gardener and expands outwards. As a result, we have a lot of empty space. Optimize it with `Recenter Octree`. It will perform more predictably from now on.

![022 Octree before and after recentering]()

## Variety

Now let’s add some variety with randomized scale and rotation. But first, choose the `Erase` brush and clear ourselves a little patch for testing.

![023 Cleaned up tree patch]()

`Random Scale Range` generates a random scale for our object. Go to the second column and set the `X` value to 1.5. All other values in the second column turned to 1.5 as well, because of the constraint above, the `Scaling Type`. `Uniform` ensures proportions of an object will be preserved. 

![024 Scale property setup]()

Now when we paint, our trees will get a slightly randomized size within these bounds.

Next comes the `Random Rotation`. `Y` rotation, our Yaw, is by default set to 180 degrees. It means our trees already have a full-circle randomized rotation. But trees rarely grow straight up, so lets add some random Pitch and Roll. Set both to 5 degrees.

![025 Rotation property setup]()

To apply changes, you can erase and repaint your trees, but you can also just reapply transforms. Choose the `Reapply` brush and drag over all your trees.

![026 Mid-drag of reaplying trees]()

## Collision

Last thing: collision. If you click on `LOD Variants`, you'll see two properties: `Mesh` and `Spawned Spatial`. `Spawned Spatial` can be any spatial scene you'd like. In our case, it's a premade static physics body. Find `body_plants_tree_pine.tscn` and drag it over `Spawned Spatial`. Collision shapes should appear in the editor.

![027 Dragging collision body and colision shapes]()

Finally, cleanup any overlaps or weird placements and lets move on to bushes and grass.

## Setting up bushes and grass

Add 2 `LOD Variants` for bushes, set it’s density to 100 and `LOD Max Distance` to 50. Set it’s scale to 2 and 3.

For grass it’s gonna be 3 variants, density of 4000 and `LOD Max Distance` of 30. Gove it the same scale as bushes, and set `LOD Kill Distance` to 50. That way, when your camera moves far away, grass will disappear entirely.

![028 Side by side bush grass until scale]()

## Aligning to surface normals

Key difference here is that bushes and grass usually align to the ground. You’d want to orient your foliage to the terrain normal, a vector that represents surface orientation in 3D space.

In grass settings, set `Primary Up-Vector` to `Normal`. Grass will now align to the surface underneath.

![029 Grass vectors setup and align with lines and text]()

In the bush settings keep `Primary Up-Vector` as `World Y`, but set `Secondary Up-Vector` to `Normal`. Set `Up-Vector Blending` to 0.3. Now, the ‘up’ direction of your bushes will be in-between these two.

In terms of level design, this means our bushes will mostly point upwards, while slightly aligning to the surface.

![030 Bush vectors setup and align with lines and text]()

## Final steps

In Spatial Gardener you can paint with several plant types simultaneously. Deselect trees, select bushes with grass and paint all over your terrain. Overlap detection is not supported, so you should clean up any jarring overlaps manually. 

![031 Cleaning up overlaps]()

All that’s left is to optimize your octrees. Rebuild bushes with a `Max Chunk Capacity` of 50 and grass with 500. Then recenter both.

![032 Before after octree comparison]()

Here we go. Your level is ready for playing. Launch your scene and give it a go. Congratulations, you’re now able to set up a plant and paint it on your terrain. 

![033 Island overview and in-game view]()

**[[Part 2] In-Depth Look ->](TUTORIAL_IN_DEPTH.md)**