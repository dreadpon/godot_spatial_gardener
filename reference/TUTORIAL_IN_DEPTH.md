# [Part 2] In-Depth Look

**[Tutorial Overview](TUTORIAL_ROOT.md)**

**[<- [Part 1] Quick-Start Tutorial](TUTORIAL_QUICK_START.md)**

## Table of contents
- [Gardener](#gardener)
- [Scene tree structure](#scene-tree-structure)
- [Brushes](#brushes)
- [Plants](#plants)
- [Gardener Debug Viewer](#gardener-debug-viewer)
- [Project Settings](#project-settings)
- [We're done!](#were-done)

## Gardener

We'll start with the Gardener itself.

![t_pt2_gardener_properties](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_gardener_properties.jpg)

- `Work Directory` is the main place to save your plant and brush configurations. It's meant to ease reusing plants across different Gardeners. It's worth to mention that Godot's resource system is pretty wonky at times. I had to work around some of it's quirks when saving and loading resources. So, you shouldn't tinker with it besides the intended way covered in this tutorial.
- `Collision Mask` was already explained. It's very important to set it up correctly, or you might end up with something like this:

![t_pt2_improper_collision_layers](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_improper_collision_layers.jpg)

- Next, the `Transforms`. Gardeners should work fine with custom translations and rotations. It's not something I tested much, so it's better to leave it at world origin and instead recenter the octree.

## Scene tree structure

Next up, the scene tree structure.

![t_pt2_gardener_scene_tree](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_gardener_scene_tree.jpg)

- First is the `Gardener` – a high-level manager that handles input, lifecycle of different functions and communications between them.
- Second comes the `Arborist`. It manages octrees and foliage placement in response to brush painting.
- Then you have a MultiMesh container for each of the plant types.
- Next is a long list of `MultiMeshInstance3D` nodes. They are unordered, and handled by Arborist's octrees. Each multimesh represents a 'cube' you've seen in `Gardener Debug Viewer`, called an octree node. MultiMeshes handle the instancing of meshes on GPU.
- Finally we have `StaticBody` nodes, which were spawned if you had a `Spawned Spatial` assigned.

You shouldn't manually edit this list, so it's better to keep your Gardeners folded.

## Brushes

Now the brushes.

![t_pt2_brush_props](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_brush_props.jpg)

You can switch between them by clicking, or pressing buttons 1-4 on your keyboard. 

- `Paint` brush adds foliage. It's `Strength` multiplies plant density. At 0.5 strength you'll get half the density.
- `Erase` removes foliage. `Strength` defines how much foliage is removed related to current density in the settings. A value of 0.5 will make your foliage approximately half as dense. It's a bit wonky though, as density isn't 100% precise in this plugin.
- `Single` is used to place individual objects like trees or props.
- `Reapply` updates individual transforms of already placed plants. It doesn't affect density, octree configuration or LOD settings.

Both size and strength can be quickly edited: `Size` by holding `Side Mouse Button 1` and dragging, and `Strength` by holding `Shift` + `Side Mouse Button 1`.

`Erase` and `Reapply` brushes can also be switched into `Projection` `Overlap Mode`. Whereas `Volume` brushes stick to terrain, `Projection` brushes live in screen_space and will affect ALL the plants inside it's radius, no matter how far from camera. This is very useful when you move a part of your terrain and need to erase any plants left hanging.

![t_pt2_projection_brush](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_projection_brush.jpg)

You can quickly switch between Volume and Projection brushes by pressing `` ` `` (backtick, left of number `1` on most keyboards).

`Projection` brushes don't have strength, because strength is relative to plant density which is closely tied to physical terrain. Since `Projection` brush is independent from terrain, it can't properly handle density.

By default `Projection` brushes don't affect plants obstructed by terrain. If you want to ignore obstruction checks, set `Passthrough` to `On`. 

![t_pt2_passthrough](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_passthrough.jpg)

## Plants

As for plant UI, I'm pretty sure you can't create a second inspector window in Godot. Or reuse any of the inspector UI really. So I had to rebuild the entire property management system to ensure basic editor functionality can work inside custom Control nodes. So it behaves slihtly differently from the native Inspector.

![t_pt2_plant_props](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_plant_props.jpg)

The plant list is simple. You can add, delete plants, and select them for painting with a checkbox. There's also an editable label on top - you can make it anything you like to ease navigation between plants.

![t_pt2_plant_list.jpg](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_plant_list.jpg)

Now onto individual plant properties.

- `LOD Variants` is a list of 'Level of Detail' meshes in order of their simplification. Inside, you can set the `Mesh` and `Spawned Spatial`. You can add, delete or clear variant's properties. For ease of use, you can drag'n'drop both the meshes and spatials without opening the variant.
   
    You can also set how individual LOD Variants cast their shadows - lower LODs usually don't need them and disabling shadows can greatly improve performance.
- At `LOD Max Distance` threshold, lowest LOD is shown. LODs in between are chosen at equal intervals.
- At `LOD Kill Distance` threshold, meshes and spawned spatials are removed entirely, to reduce machine load.
- `Octree configuration` sets two things: a maximum number of plants in each node and a minimum size of that node. To understand what's going on here, I advise you read an article on [gamedev.net](https://www.gamedev.net/tutorials/programming/general_and_gameplay_programming/introduction_to_octrees_r3529/).
    - If a node exceeds it's capacity, it will subdivide into 8 smaller nodes. But it won't subdivide less than it's minimum size. Instead, it will keep adding objects over it's capacity limit. If your nodes seem to overflow with objects – check the scale you're working in. Perhaps you need to scale everything up or reduce the minimum node size.

        ![t_pt2_octree_overflow](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_octree_overflow.jpg)

- `Plants Per 100 Units` represents how many objects you'll have in a 100x100 units square. But many things affect the final result.
    - First - your brush is circular, not square. Naturally, the corners are cut off.

        ![t_pt2_cut_off_corners](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_cut_off_corners.jpg)

    - Next, when you paint, your brush creates a virtual 2D grid. It then places the objects on that grid and applies a random offset, so it looks more natural. As grid moves and rotates, grid cells tend to overlap a lot and this usually results in increased density of up to 30%. If you really need these numbers to be accurate, you can do a pass with `Erase` brush set to 0 strength. This will remove any excess objects.
    - If you ever worked with foliage, you probably know that sometimes it's placed procedurally using a distribution function such as blue noise. Spatial Gardener doesn't support that and is meant for manually painting any surface, not just a heightmap terrain. So most of the 2D placement solutions don't apply here.

        ![t_pt2_blue_noise](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_blue_noise.jpg)

- `Scaling type` defines the scaling constraint. With `Uniform` it keeps the original proportions. `Free` usually creates wonky objects, but allows all axes to scale independently.

    ![t_pt2_free_scale](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_free_scale.jpg)

    Last three options define a plane in 3D space and constraint only that plane, leaving the third axis independent. Most used one is probably `Lock XZ`: it gives proportional horizontal scale, but allows varying vertical scale.

    ![t_pt2_lockxz_scale](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_lockxz_scale.jpg)

- `Random Scale Range` defines bounds for choosing a random scale. If a scaling constraint is active, only the first property can be edited, the rest will follow automatically.
- `Up-Vectors`. They define which direction is the 'top side' of our object. You can choose a world-space vector, normal of the surface or define a custom vector. You can also blend between the `Primary` and `Secondary` vectors by a given `Blending` factor.

    ![t_pt2_up_vector_demo](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_up_vector_demo.jpg)

- Same goes for `Forward-Vectors`. They define which direction is 'forward' for an object. This is mainly used to make vines that point outwards from the surface. Keep in mind that `Up-Vector` still takes precedence.

    ![t_pt2_forward_vector_demo](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_forward_vector_demo.jpg)

- `Random Offset Range Y` offsets the object vertically by a random value. It's used to cover the bottom side of an object, like roots of a tree. If the object is scaled, say, twice the size, this value will be doubled too.

    ![t_pt2_vertical_offset](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_vertical_offset.jpg)

- `Random Jitter Fraction` offsets an object from the original placement grid. Default value of 0.6 keeps it natural_looking, but prevents overlaps between neighbors.

    ![t_pt2_jitter_demo](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_jitter_demo.jpg)

- `Random Rotations` are ranges for choosing random rotations, from 0 to 180 degrees in each direction. By default, rotation on `Y` axis is fully randomized.
- `Allowed Slope Range` prevents object placement on inclined or vertical surfaces. Limit this to 45 (or 90) degrees, and you'll prevent placement on a steep terrain.

    ![t_pt2_slope_range_demo](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_slope_range_demo.jpg)

- `Import Plant Data` and `Export Plant Data` handle importing and exporting all variables belonging to a current plant as well as transforms of all already placed plants to JSON file. This is useful when migrating versions, as it uses a format independent from Godot itself. Godot 3.5 version of this exports only transforms (no plant data) but is still valid for importing in Godot 4.0.
- `Import Greenhouse Data` and `Export Greenhouse Data` handle importing and exporting all variables belonging to all plants for this `Gardener` as well as transforms of all already placed plants to JSON file. This is used to basically back up the entire `Gardener`. Even though it doesn't technically relate to the currenlty selected plant, it still can be accessed only if you added at least one. This might be improved in future versions. Spatial Gardener for Godot 3.5 does not have these buttons at all.

## Gardener Debug Viewer

Next, a debugging tool called `Gardener Debug Viewer`. It visualizes the underlying octrees.

- You can choose to display the `Selected Plant` (currently open in the sidepanel) or `All Active Plants` at once for the selected Gardener.
- Besides showing `Octree Nodes`, it can show individual `Node Members`, to inspect hidden objects, for example (like grass that exceeds `LOD Kill Distance`).

![t_pt2_debug_viewer_members](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_debug_viewer_members.jpg)

## Project Settings

And finally, the plugin settings. Go to `Project -> Project Settings` and scroll until you see `Dreadpon Spatial Gardener`.

![t_pt2_plugin_settings](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_plugin_settings.jpg)

- In `Painting` are all the tweakable settings related to painting a plant. Most of these are currently related to `Projected` brush, so if you have troubles with precision when `Passthrough` is disabled or your camera has a high `near` clipping plane - you can tweak these.

    ![t_pt2_painting](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_painting.jpg)

- In `Input and UI` you can: toggle undo_redo for editing plant properties, change useful keybinds and change the range for each slider in the UI.

    ![t_pt2_input_ui](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_input_ui.jpg)

- In `Plugin` are all the tweakable settings related to plugin in general. For now it's only settings related to converting scenes from previous plugin versions.

    ![t_pt2_plugin](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_plugin.jpg)

- In `Debug` you can assign a key to dump information about the scene to console for inspection. This doesn't work in_game, but works in_editor. You can also activate logging of various functions, or set the member size for `Gardener Debug Viewer`.

    ![t_pt2_debug](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_debug.jpg)

## We're done!

That covers most of the things you need to know about this plugin. You are welcome to get a look through the code itself, as it contains some useful insights here and there. However, you shouldn't call plugin functions from your own code. There's currently no interface to integrate Gardeners in your gameplay logic, and they're best kept separate. More so, if you have active gardeners you shouldn't edit the plugin's code. **This will lead to data corruption and loss.**

Thanks for following through. I hope you now understand how Spatial Gardener works.

![t_pt2_mid_paint_shot](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/text_tutorial/tut2_mid_paint_shot.jpg)

Please share your thoughts and feel free to drop by on [Discord](https://discord.gg/CzRSk8E). Since I find foliage painting quite useful for modern 3D games, I'm open to suggestions and collaboration.

Farewell and good luck!

**[<- [Part 1] Quick-Start Tutorial](TUTORIAL_QUICK_START.md)**
