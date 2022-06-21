# [Part 2] In-Depth Look

**[<- [Part 1] Quick-Start Tutorial](TUTORIAL_QUICK_START.md)**

## Table of contents
- [Gardener](#gardener)
- [Scene tree structure](#scene-tree-structure)
- [Brushes](#brushes)
- [Plants](#plants)
- [Gardener Debug Viewer](#gardener)
- [Project Settings](#project-settings)
- [Recording Godot with OBS](#recording-godot-with-obs)
- [We're done!](#were-done)

## Gardener

We’ll start with the Gardener itself.

![001 Gardener properties]()

- `Work Directory` is the main place to save your plant and brush configurations. It’s meant to ease reusing plants across different Gardeners. However, Godot’s resource system is pretty wonky at times. I had to work around some of it’s quirks when saving and loading resources. So, you shouldn’t tinker with it besides the intended way covered in this tutorial.
- `Collision Mask` was already explained. It’s very important to set it up correctly, or you might end up with something like this:
- Next, the `Transforms`. Gardeners should work fine with custom translations and rotations. It’s not something I tested much, so it’s better to leave it at world origin and instead recenter the octree.

## Scene tree structure

Next up, the scene tree structure.

![002 Gardener scene tree expanded]()

- First is the `Gardener` – a high-level manager that handles input, lifecycle of different functions and communications between them.
- Second comes the `Arborist`. It manages octrees and foliage placement in response to brush painting.
- Next is¬ a long list of `Multimesh` nodes. They are unordered, and handled by Arborist’s octrees. Each multimesh represents a ‘cube’ you’ve seen in `Gardener Debug Viewer`, called an octree node. They handle the instancing of meshes on GPU.
- Finally we have `StaticBody` nodes. They are added if you have a `Spawned Spatial` assigned.

You shouldn’t manually edit this list, so it’s better to keep your Gardeners folded.

## Brushes

Now the brushes. 

![003 Brush properties]()

You can switch between them by clicking, or pressing buttons 1 to 4 on your keyboard. Both properties can be quickly edited: `Size` by holding Right Mouse Button and dragging, and ‘Strength’ by holding Shift + Right Mouse Button.

- `Paint` brush adds foliage. It’s `Strength` multiplies plant density. At 0.5 strength you’ll get half the density.
- `Erase` removes foliage. `Strength` defines how much foliage is removed in relation to current density in the settings. A value of 0.5 will make your foliage approximately half as dense.
- `Single` is used to place individual objects like trees or props.
- `Reapply` updates individual transforms of already placed plants. It doesn’t affect density, octree configuration or LOD settings.

## Plants

As for plant UI, I’m pretty sure you can’t create a second inspector window in Godot. Or reuse any of the inspector UI really. So I had to rebuild the entire property management system to ensure basic editor functionality can work inside custom Control nodes. So it might behave differently from the native Inspector.

![004 Plant properties fully expanded]()

The plant list is simple. You can add, delete plants, and select them for painting with a checkbox.

- `LOD Variants` is a list of Level of Detail meshes in order of their simplification. Inside, you can set the `Mesh` and `Spawned Spatial`. You can add, delete or clear variant’s properties. For ease of use, you can drag’n’drop both the meshes and spatials without opening the variant.

    ![005 Comparing drag'n'drop functionality]()

- At `LOD Max Distance` threshold, lowest LOD is shown. LODs in between are chosen at equal intervals.
- At `LOD Kill Distance` threshold, meshes and spawned spatials are removed entirely, to reduce the machine  load.
- `Octree configuration` sets two things: a maximum number of plants in each node and a minimum size of that node. To understand what’s going on here, I advise you read an article on gamedev.net.
    - If a node exceeds it’s capacity, it will subdivide into 8 smaller nodes. But it won’t subdivide less than it’s minimum size. Instead, it will keep adding objects over it’s capacity limit. If your nodes seem to overflow with objects – check the scale you’re working in. Perhaps you need to scale everything up or reduce the minimum node size.
- `Plants Per 100 Units` represents how many objects you’ll have in a 100x100 units square. But many things affect the final result. 
    - First - your brush is circular, not square. Naturally, the corners are cut off.
    
        ![006 Cut off corners]()

    - Next, when you paint, your brush creates a virtual 2D grid. It then places the objects on that grid and applies a random offset, so it looks more natural. As grid moves and rotates, grid cells tend to overlap a lot and this usually results in increased density of up to 30%-50%. If you really need these numbers to be accurate, you can do a pass with `Erase` brush set to 0 strength. This will remove any excess objects.

        ![007 2D grid, jitter and brush mid-move]()

    - If you ever worked with foliage, you probably know that sometimes it’s placed procedurally using a distribution function such as blue noise. Spatial Gardener doesn’t support that and is meant for manually painting any surface, not just a heightmap terrain. So most of the 2D placement solutions don’t apply here.
- `Scaling type` defines the scaling constraint. With `Uniform` it keeps the original proportions. `Free` usually creates wonky objects, but allows all axes to scale independently. Last three options define a plane in 3D space and constraint only that plane, leaving the third axis independent. Most used one is probably `Lock XZ`: it gives proportional horizontal scale, but allows varying vertical scale.

    ![008 Horizontal lock variety demo]()

- `Random Scale Range` defines bounds for choosing a random scale. If a scaling constraint is active, only the first property can be edited, the rest will follow automatically.
- `Up-Vectors`. They define which direction is the ‘top side’ of our object. You can choose a world-space vector, normal of the surface or define a custom vector. You can also blend between the `Primary` and `Secondary` vectors by a given `Blending` factor.
- Same goes for `Forward-Vectors`. They define which direction is ‘forward’ for an object. This is mainly used to make vines that point outwards from the surface. Keep in mind that `Up-Vector` still takes precedence.

    ![009 Vines with lines drawn and text]()

- `Random Offset Range Y` offsets the object vertically by a random value. It’s used to cover the bottom side of an object, like roots of a tree. If the object is scaled, say, twice the size, this value will be doubled too.

    ![010 Tree vertical offset]()

- `Random Jitter Fraction` offsets an object from the original grid. Default value of 0.6 keeps it natural-looking, but prevents overlaps between neighbors.

    ![011 Comparing 3 jitter settings]()

- `Random Rotations` are ranges for choosing random rotations, from 0 to 180 degrees in each direction. By default, rotation on `Y` axis is fully randomized.
- `Allowed Slope Range` prevents object placement on inclined or vertical surfaces. Limit this to 45 degrees, and you’ll prevent placement on a steep terrain.

    ![012 Brush over steep slope]()

## Gardener Debug Viewer

Next, a debugging tool called `Gardener Debug Viewer`. It visualizes the underlying octrees. 

![013 Full view of debug viewer with menu and members]()

- You can choose to display the `First Active Plant` or `All Active Plants` at once. 
- Besides showing `Octree Nodes`, it can show individual `Node Members`, to inspect hidden objects, for example.

## Project Settings

And finally, the plugin settings. Go to `Project -> Project Settings` and scroll until you see `Dreadpon Spatial Gardener`.
- In `Input and UI` you can: toggle undo-redo for editing plant properties, change useful keybinds and change the range for each slider in the UI.

    ![014 Plugin settings input and ui]()

- In `Debug` you can assign a key to dump information about the scene to console for inspection. This doesn’t work in-game, but works in-editor. You can also activate logging of various functions, or set the member size for `Gardener Debug Viewer`.

    ![015 Plugin settings debug]()

## Recording Godot with OBS

As a closing remark: if you ever want to record my plugin in action, know that OBS recording of Godot in fullscreen can be painful. The easiest way is to add `Game Capture` source, set it to `Capture specific window` and make sure `Window` is chosen correctly.

![016 OBS setup]()

## We're done!

That covers most of the things you need to know about this plugin. You are welcome to get a look through the code itself, as it contains some useful insights here and there. However, you shouldn’t call plugin functions from your own code. There’s currently no separate interface to integrate Gardeners in your gameplay logic, and they’re best kept separate. More so, if you have active gardeners you shouldn’t edit the plugin’s code. This will lead to data corruption and loss.

Thanks for following through. I hope you now understand how Spatial Gardener works. 

![017 Beautiful shot of painted terrain]()

Please share your thoughts in the comments and feel free to drop by on Discord or GitHub. Since I find foliage painting quite useful for modern 3D games, I’m open to suggestions and collaboration.

Farewell and good luck!

**[<- [Part 1] Quick-Start Tutorial](TUTORIAL_QUICK_START.md)**