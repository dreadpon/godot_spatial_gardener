# [Part 1] Quick-Start Tutorial

**[Tutorial Overview](TUTORIAL_ROOT.md)**

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
You should have Godot engine installed; if not, you can download it from the [official website](https://godotengine.org/download).

Most recent plugin version requires [Godot 4.2 that can be easily found on Godot's GitHub](https://github.com/godotengine/godot/tree/4.2-stable).

To start with, grab a copy of the demo project from [GitHub](https://github.com/dreadpon/godot_spatial_gardener). Open the page, go to `Releases`, find the latest version and download the `godot_spatial_gardener_demo_<version>.zip`.

**NOTE:** be SURE to grab the version which says `Latest` near it's title.

![t_pt1_plugin_demo_download](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_plugin_demo_download.jpg)

Save, unpack and launch the project. Wait for Godot to Import all the assets. If editor screams errors at you, it's probably reimporting the assets and should be fine soon.

![t_pt1_editor_screaming](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_editor_screaming.jpg)

Make sure the plugin is enabled by going to `Project -> Project Settings -> Plugins -> Spatial Gardener` and ticking the `Enable` checkbox.

![t_pt1_enabling_plugin](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_enabling_plugin.jpg)

## What we're working with

This project comes with a few things besides the plugin itself. In the `demo` folder you'll see a bunch of files used to build two demo scenes at the very bottom: `showcase.tscn` and `playground.tscn`.

![t_pt1_demo_folder](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_demo_folder.jpg)

`showcase.tscn` is a full_blown demonstration level that you can play to test the plugin in_game. Feel free to play around!

`playground.tscn` is where you're going to work, so open it. This will be our main scene, so you can set it as default in `Project -> Project Settings -> Application -> Run -> Main Scene`.

![t_pt1_setting_main_scene](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_setting_main_scene.jpg)

To work with the Gardener you'll need some level geometry with collision. Here we have an island and two buildings with auto_generated static physics bodies. Take a look at their collision layers.

First layer, `gameplay` is used for game collision such as interaction with the player. The second, `painting` is reserved for foliage painting.

![t_pt1_collision_layers](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_collision_layers.jpg)

Notice how landscape interacts with this layer, but buildings do not. I assume you don't want to paint on buildings, but it's really up to your artistic choice.

![t_pt1_island_building_layers](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_island_building_layers.jpg)

## Setting up a Gardener

Go to the scene tree and add a node called `Gardener`. It will handle the entire drawing process.

![t_pt1_adding_gardener](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_adding_gardener.jpg)

Every Gardener maintains a subtree of nodes that are essential for its functionality. You can have however many Gardeners you need, but you should not add or remove any descendants.

![t_pt1_gardener_scene_tree](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_gardener_scene_tree.jpg)

Select your Gardener, and choose its working directory in `demo -> playground -> work_directory`. All your plants and brushes will be saved there.

Now choose collision layers that our Gardener interacts with. Disable `gameplay` layer and enable `painting`. Now we can paint on landscape objects, but ignore buildings.

![t_pt1_gardener_setup](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_gardener_setup.jpg)

Because of some engine quirks, you can see a transform gizmo of your Gardener. It can't be hidden, but it will ignore all your inputs. Instead, your mouse will control a foliage brush.

![t_pt1_gardener_gizmo](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_gardener_gizmo.jpg)

## Creating your first plant

Now, go to the Gardener panel. Top side is for brush settings, everything else is for plants. In the middle there's a box with the plus sign button. Click it to create a new plant. Now click the plant itself, and you'll see a list of all its properties.

![t_pt1_side_panel](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_side_panel.jpg)

To paint a plant, you need two basic things: a mesh and a desired density. For the mesh, `LOD Variants` is what you'll use. A bit of theory first.

For plants to look good, they need a lot of polygons and high-res textures. There's usually hundreds if not thousands of plants in a level. Multiply these and you get a molten Graphics Card. But, we rightfully assume that players can't see that well in the distance, so it's fine for faraway plants to have less detail. This concept is called 'Level of Detail' or LOD for short. We make 2, 3, 4 separate models, each simpler than the last. And then switch between them depending on the distance.

![t_pt1_lod_primer]()

That's what `LOD Variants` are for. Add three variants. Now go to `demo -> playground -> plants -> pine` and find three meshes named `plants_tree_pine_lod.mesh`. You should assign them in order of simplification: drag  `plants_tree_pine_lod0.mesh` to the first LOD variant, `plants_tree_pine_lod1.mesh` to second and `plants_tree_pine_lod2.mesh` to third.

![t_pt1_assign_lod](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_assign_lod.jpg)

Next, the density. Set `Plants Per 100 Units` to something small like 15. It defines how many plants to place in a 100x100 units square. This number is very approximate and can be off by around thirty percent. Not to mention circular brush shape does not account for corners. To get the feel of the density, you really should play with this number a bit.

Problems may arise at low density and small brush size. If you have obviously too many plants – try increasing the brush size.

![t_pt1_compare_low_desnity](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_compare_low_desnity.jpg)

We will use something like 75. You can also drag the `Side Mouse Button 1` to quickly set it. Or even go to project settings and remap this to a different mouse button? say, `Right Mouse Button` (the path is `Project -> Project Settings -> Dreadpon Spatial Gardener -> Input and UI -> Brush Prop Edit Button`).

Now lets paint. Tick the paint box for our trees, press `Left Mouse Button` and drag across the island. To center camera on the brush, press `Q` on your keyboard.

![t_pt1_select_trees_painting](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_select_trees_painting.jpg)

That's it, we now have trees.

![t_pt1_finished_tree_painting](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_finished_tree_painting.jpg)

## Configuring octrees

If you go to the `Gardener Debug Viewer` at the top and select `View Selected Plant` (while having a plant open in the sidepanel), you can see how trees are referenced in 3D space. This structure is called an octree and it optimizes iteration over thousands of spatial objects. This is needed to switch our LODs according to camera distance.

![t_pt1_debug_viewer](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_debug_viewer.jpg)

Set `LOD Max Distance` to 100, and zoom your camera in and out. Observe how the tree meshes change.

![t_pt1_different_lods](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_different_lods.jpg)

Click `Configure Octrees`. Default values here are meant for something more dense, like bushes. It assumes 75 objects can fit into one 'cube'. Lets change `Max Chunk Capacity` to a more reasonable 10 and click `Apply`.

![t_pt1_configuting_octree](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_configuting_octree.jpg)

Notice how the density of debug cubes increased.

Also, by default octree generates in the center of our Gardener and expands outwards as you paint. As a result, we have a lot of empty space. Optimize it with `Recenter Octree`. It will perform more predictably from now on.

![t_pt1_recentering_octree](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_recentering_octree.jpg)

## Variety

Now let's add some variety with randomized scale and rotation. But first, choose the `Erase` brush and clear ourselves a little patch for testing.

![t_pt1_erasing_patch](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_erasing_patch.jpg)

`Random Scale Range` generates a random scale for our object. Go to the second column and set the `X` value to 1.5. All other values in this column turned to 1.5 as well, because of the constraint above, the `Scaling Type`. `Uniform` ensures proportions of an object will be preserved.

Now when we paint, our trees will get a slightly randomized size within these bounds.

![t_pt1_scale_applied](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_scale_applied.jpg)

Next comes the `Random Rotation`. `Random Rotation Y`, our Yaw, is by default set to 180 degrees. It means our trees already have a full_circle randomized rotation. But trees often don't grow completely straight up, so lets add some random Pitch (`Random Rotation X`) and Roll (`Random Rotation Z`). Set both to 5 degrees.

To apply changes, you can erase and repaint your trees, but you can also just reapply transforms. Choose the `Reapply` brush and drag over all your trees.

![t_pt1_mid_reapply](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_mid_reapply.jpg)

## Collision

Last thing: collision. If you click on `LOD Variants`, you'll see two properties in fact: `Mesh` and `Spawned Spatial`. `Spawned Spatial` can be any spatial scene you'd like. In our case, it's a premade static physics body.

![t_pt1_inside_lod_variant](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_inside_lod_variant.jpg)

Find `body_plants_tree_pine.tscn` and drag it over `Spawned Spatial` for each of the variants.

![t_pt1_assigning_collision](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_assigning_collision.jpg)

Collision shapes should appear in the editor.

![t_pt1_finished_collision](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_finished_collision.jpg)

Finally, cleanup any overlaps or weird placements and lets move on to bushes and grass.

## Setting up bushes and grass

Add 2 plants, select the first one and add 2 `LOD Variants` for bushes, set their density to 100 and `LOD Max Distance` to 50. Set their's `Random Scale Range` to 2 and 3.

For grass it's gonna be 3 variants, density of 4000 and `LOD Max Distance` of 30. Give it the same `Random Scale Range`  as the bushes, and set `LOD Kill Distance` to 50. That way, when your camera moves far away, grass will disappear entirely.

![t_pt1_setting_up_bushes_grass](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_setting_up_bushes_grass.jpg)

## Aligning to surface normals

Key difference here is that bushes and grass usually align to the ground. You'd want to orient your foliage to the terrain normal, a vector that represents surface orientation in 3D space.

![t_pt1_surface_normal](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_surface_normal.jpg)

In grass settings, set `Primary Up-Vector` to `Normal`.

![t_pt1_setting_grass_up_vector](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_setting_grass_up_vector.jpg)

Grass will now fully align to the surface underneath.

![t_pt1_finished_grass_up_vector](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_finished_grass_up_vector.jpg)

In the bush settings keep `Primary Up-Vector` as `World Y`, and make sure `Secondary Up-Vector` is set to `Normal`. Set `Up-Vector Blending` to 0.3. Now, the 'up' direction of your bushes will be in-between these two.

![t_pt1_setting_bush_up_vector](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_setting_bush_up_vector.jpg)

In terms of environment design, this means our bushes will mostly point upwards, while slightly aligning to the surface.

![t_pt1_finished_bush_up_vector](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_finished_bush_up_vector.jpg)

## Final steps

In Spatial Gardener you can paint with several plant types simultaneously. Deselect trees, select bushes with grass and paint them. If you can't see your grass, temporarily disable `LOD Kill Distance` by setting it to -1.

![t_pt1_select_bush_grass_painting](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_select_bush_grass_painting.jpg)

Overlap detection is not supported, so you should clean up any jarring overlaps manually.

All that's left is to optimize your octrees. Rebuild bushes with a `Max Chunk Capacity` of 50 and grass with 500. Then recenter both.

Here we go. Your level is ready for playing.

![t_pt1_finished_all_painting](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_finished_all_painting.jpg)

Launch your scene and give it a go. Congratulations, you're now able to set up a plant and paint it on your terrain!

![t_pt1_walking_in_level](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut1_walking_in_level.jpg)

**[[Part 2] In-Depth Look ->](TUTORIAL_IN_DEPTH.md)**
