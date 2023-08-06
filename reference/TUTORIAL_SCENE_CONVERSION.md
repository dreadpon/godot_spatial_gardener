# Scene conversion

**[Tutorial Overview](TUTORIAL_ROOT.md)**

<br>

## Table of contents
- [Regular conversion](#regular-conversion)
- [Alternative conversion](#alternative-conversion)
- [Good ol' JSON](#good-ol-json)
- [Dealing with failed conversions](#dealing-with-failed-conversions)

<br>

## Regular conversion

To convert scenes in your project to a new version, you need to update the plugin (by replacing the contents of `addons/dreadpon.spatial_gardener`) and start up your project.

**NOTE:** plugin does not handle conversion between Godot 3.x and Godot 4.0. However, during demo project conversion Godot's automatic scene converter actually handled all data conversion correctly and all plants' data was retained. You might be lucky as well. If not, check out [Good ol' JSON](#good_ol_json) for a more manual approach to conversion. If conversion between Godot 4.x versions ever becomes relevant, this document will be updated.

Steps:
1. Plugin will automatically discover potential candidates for a conversion and show a popup, asking for confirmation.
	- ![convert_popup_found.jpg](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/scene_conversion/cnvrsn_convert_popup_found.jpg)]
	- **NOTE:** in case it didn't, make sure your plugin is enabled and project setting `dreadpons_spatial_gardener/plugin/scan_for_outdated_scenes` is set to `true`. Then relaunch your project. If this didn't help, refer to [Alternative conversion](#alternative_conversion).
2. By default, conversion will create backups of your scenes with the `.backup` extension. 
	- This can be disabled with `Create backup duplicates` checkbox.
3. Spatial Gardener will check for outdated scenes on each start up of your project. 
	- This can be disabled (to speed up the loading process) with `Don't ask me again` checkbox.
4. Select the scenes you'd like to convert and press `Convert` button. 
	- The editor will freeze for a while: the best way to keep track of your progress is by launching the editor from console (or by running `Godot_v***-stable_win64_console.cmd` included in the official download).
	- The process takes about 1-10 minutes per scene, depending on it's size.
5. You will receive a popup once conversion is done. 
	- Make sure to move backups elsewhere before committing to source control.
6. If it failed, you will probably see errors in your console. 
	- Before opening an Issue on GitHub, try consulting the [Alternative conversion](#alternative_conversion), [Good ol' JSON](#good_ol_json) or [Dealing with failed conversions](#dealing_with_failed_conversions).

<br>

## Alternative conversion

This method can be helpful if automatic scanning failed to recognize a scene in need of conversion. If actual errors occured, try fixing the conversion by consulting the [Good ol' JSON](#good_ol_json) or [Dealing with failed conversions](#dealing_with_failed_conversions).

Steps:
1. Make sure the plugin is updated to the most recent version
2. Copy your scenes to `addons/dreadpon.spatial_gardener/scene_converter/input_scenes` folder.
	- Make sure they have a plain text scene file format (`.tscn`).
	- The scene converter automatically makes backups of your scenes. But you should make your own, in case anything goes wrong.
3. Editor might scream that there are resources missing. This is expected.
	- You might see a message that some plugin scripts are missing. Ignore, since some things *did* get removed in a plugin.
	- That's why you should *not* open these scenes for now.
4. Open the scene found at `addons/dreadpon.spatial_gardener/scene_converter/scene_converter.tscn`.
5. Launch it (F6 by default): it will start the conversion process.
	- The process takes about 1-10 minutes per scene, depending on it's size.
6. If any errors occured, you'll be notified in the console.
	- The editor will freeze for a while: the best way to keep track of your progress is by launching the editor from console (or by running `Godot_v***-stable_win64_console.cmd` included in the official download).
7. If conversion was successful, grab your converted scenes from `addons/dreadpon.spatial_gardener/scene_converter/output_scenes` folder and move them to their intended places.
8. You should be able to launch your converted scenes now.
	- Optionally, you might have to relaunch the project and re_enable the plugin.
	- Make sure to move backups elsewhere before committing to source control.

If you got this far, you should probably open an issue on GitHub.

<br>

## Good ol' JSON

New to Spatial Gardener v.1.1.1 is the ability to export plant placement data as JSON.

Steps:
1. First, backup all the scenes you're planning to convert.
2. Download the Spatial Gardener v.1.1.1 if you were using one of the previous versions. It is compatible with scenes made in these previous versions, and is made purely for enabling JSON exporting. All subsequent versions have breaking changes compared to pre v1.1.1.
3. Open the scene you'd like to convert.
4. For each `Gardener` and each plant in this scene, go to plant settings, scroll to the bottom and press `Export Transforms` (`Export Plant Data` in v.1.3.0 and up).
	- ![export.jpg](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/scene_conversion/cnvrsn_export.jpg)
5. Select the folder, set file name and press `Save`.
	- You should probably export outside of your project directory.
	- At this point you should have a bunch of individual JSON files. E.g. if you have 2 Gardeners in your scene, 3 plants each, you would have 6 JSON files.
6. Upgrade Spatial Gardener to the version, when NEXT storage specification change occured
	- Storage v.1: plugin v.1.0.0 - v.1.1.1
	- Storage v.2: plugin v.1.2.0 - now
7. Open your scenes. The editor will scream errors, that's fine.
8. Clear your `Gardener`s by deleting them or the `Arborist` nodes.
9. Save and re_open the scene. Recreate the `Gardener`s in case you deleted them.
10. For each `Gardener` and each plant in the scene, go to plant settings, scroll to the bottom and press `Import Transforms` (`Import Plant Data` in v.1.3.0 and up).
	- ![import.jpg](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/scene_conversion/cnvrsn_import.jpg)
11. Select the files you exported previously and click `Open`.
12. Once you do that for every file, your scene should have your plants in the same positions.
13. Repeat steps 6-12 until you end up at the most recent plugin version.
13. You might need to `Rebuild` and `Recenter` your octrees after converting, because Octree data will be inevitably lost.
	- ![rebuild_rcenter_octree.jpg](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/scene_conversion/cnvrsn_rebuild_recenter_octree.jpg)

New in Spatial Gardener fot Godot 4.x (v.1.3.0 and up) is the ability to Export/Import entire `Greenhouses` (resources, used to describe plant data) and their respective plant transforms. This allows to have only one JSON file per `Gardener`:
1. Make sure you don't update to an incompatible plugin version yet
2. Backup all the scenes you're planning to convert.
3. Open the scene you'd like to convert.
4. For each `Gardener` select any plant, go to plant settings and scroll to the bottom and press `Export Greenhouse Data`.
	- ![export.jpg](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/scene_conversion/cnvrsn_export2.jpg)
5. Select the folder, set file name and press `Save`.
	- You should probably export outside of your project directory.
	- At this point you should have a bunch of individual JSON files. E.g. if you have 2 Gardeners in your scene, 3 plants each, you would have 2 JSON files.
6. Upgrade Spatial Gardener to next version, when NEXT storage specification change occured
	- Storage v.3: plugin v.1.3.0 - now
	- **NOTE:** there is currently no storage spec changes for plugin versions for Godot 4.x, but this might change in the future.
7. Open your scenes. The editor will scream errors, that's fine.
8. Clear your `Gardener`s by deleting them or the `Arborist` nodes.
9. Save and re_open the scene. Recreate the `Gardener`s in case you deleted them.
10. For each `Gardener` add at least one "dummy" plant, go to plant settings and scroll to the bottom and press `Import Greenhouse Data`.
	- ![import.jpg](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/scene_conversion/cnvrsn_import2.jpg)
11. Select the files you exported previously and click `Open`.
12. Once you do that for every file, your scene should have your plant data carried over from a previous version + all plant positions you painted.
13. Repeat steps 6-12 until you end up at the most recent plugin version.
13. You might need to `Rebuild` and `Recenter` your octrees after converting, because Octree data will be inevitably lost.
	- ![rebuild_rcenter_octree.jpg](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/scene_conversion/cnvrsn_rebuild_recenter_octree2.jpg)

If this fails too, proceed to the last resort: [Dealing with failed conversions](#dealing_with_failed_conversions).

<br>

## Dealing with failed conversions

**NOTE:** information below is relevant for Godot 3.x. Godot 4.x versions of this plugin currently use the same storage methods described, but you are unlikely to need to use them.

### The obvious

First thing you should do is inspect the console. If you have enough experience with Godot, you might be able to troubleshoot yourself. In case Godot crashes, it's logs can be found at `user://` directory.
- `C:\Users\<user name>\AppData\Roaming\Godot\app_userdata\<project name>\logs` on Windows by default

If you changed your logging settings somehow, scene converter also stores converter-specific logs at `user://sg_tscn_conversion_<timestamp>.txt` (but they will lack the verbosity of editor logs).
- `C:\Users\<user name>\AppData\Roaming\Godot\app_userdata\<project name>\sg_tscn_conversion_<timestamp>.txt` on Windows by default

If that's not enough, you might want to try and convert manually (or at least fix the mistakes that converter made).

For that you'll need to understand which data is converted and how.

### Converter overview

1. First we have the parser.
	- It goes over the entire `.tscn` file and finds individual "tokens" that represent functional units of the scene file. They include property names, property values, bracket symbols, strings, numbers and more.
	- It then converts these tokens into individual `Dictionaries` that represent separate `Nodes` or `Resources`.
	- It's a "quick and dirty" parser, and thus can give flawed results. This is the **weakest link** in the conversion process.

2. Then we have the versioned converters.
	- They go over said `Dictionaries` and convert the data to fit a particular storage version of the plugin.

3. And finally, the scene is reassembled once again from the adapted `Dictionaries`.

You might want to compare two scene files: before conversion and after. Perhaps there is some data *unrelated* to `Spatial Gardener` that is missing or corrupted? I recommend using a [VSCode's built-in comparison tool for that](https://vscode.one/diff_vscode/).

You can then manually patch the missing/corrupted data.

If the damage is too big, try Godot's `Save branch as scene` on the *original*, unconverted scene. By saving some parts of it to separate files, you reduce the complexity that the converter has to work with. You can even go as far as saving the `Gardener` node itself to a separate scene, so it's the only thing present at all! This should greatly simplify parser's task.

In case it's not working, you might want to understand how the data itself is converted.

### Storage v.1 -> Storage v.2

This is gonna get code-ey. Let's compare how two versions store their data (click to enlarge).

![storage_v-1-storage_v-2.jpg](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/scene_conversion/cnvrsn_storage_v.1.0.0-storage_v.2.0.0.jpg)

*v.1 on the left, v.2 on the right*

Before, each plant's position was stored in a specialized object called `PlacementTransform`. Storing the info even for 3 plants took a huge amount of space (huge chunk in red on the left).

Then, `PlacementTransform`s were referenced in a `members` variable of each owning `OctreeNode` (lone red line on the left).

Each `PlacementTransform` had 4 variables:
1. `placement` - the initial position of a plant calculated during painting.
2. `surface_normal` - the normal vector of the surface on which plant resides.
3. `transform` - the actual final transform of a plant. **NOTE:** the `origin` can be different than the `placement` value, due to vertical offset that can be present on each plant (defined in the plant settings panel).
4. `octree_octant` - which part of the big cube the plant resides in. (In case you know what Octrees are: octant is one of the 8 possible sub-nodes an Octree Node can have)

Several things changed with the new version:
1. Storage was changed from dedicated objects (`PlacementTransform`s) to more lightweight Pool Arrays (green chunk on the right).
2. Separate `transform` storage was removed entirely. Since Spatial Gardener uses multimeshes to render plants, all transform values were stored on `MultiMesh` objects anyway, which resulted in duplicated data.
3. Since plants could only be offset on the vertical axis, there was no need to store separate `PlacementTransform.placement`. We could take the plants `Transform` and simply store an offset from `Transform.origin` along the `surface_normal` vector.
	- ![offset.jpg](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener_media/main/scene_conversion/cnvrsn_offset.jpg)

If you wish to manually transfer each plant, you'll need to do the following:
1. For every `OctreeNode` in the scene, add three members: `member_origin_offsets`, `member_surface_normals` and `member_octants`.
2. Find the node, referenced in `OctreeNode.MMI_name`. It should have a long array `MultiMesh.transform_array`.
3. Go over each `SubResource` reference in the `OctreeNode.members` property:
	1. Add individual floats for `PlacementTransform.surface_normal` to `OctreeNode.member_surface_normals`.
	2. Add integers for `PlacementTransform.octree_octant` to `OctreeNode.member_octants`.
	3. Find the corresponding transform for this plant in `MultiMesh.transform_array`. `Transform` type consists of 12 floats, with last 3 representing a `Transform.origin` location in 3D space. For the first plant in the comparison above, that would be `... -39.8068, 3.69196, -33.4478, ...`.
	4. Use the expression below to calculate origin offset:
		```
		var difference = MultiMesh.transform_array[plant_index].origin - Transform.origin
		var origin_offset = PlacementTransform.surface_normal.dot(difference.normalized()) * difference.length()
		```
	5. Add `origin_offset` to `OctreeNode.member_octants`.
	- **NOTE:** it's important to preserve the original order!
4. Delete the `OctreeNode.members` property.
5. Delete all the processed `PlacementTransform` resources.
6. You should be good to go.

Again, it's a good idea to open on issue on GitHub if you got this far.


### Storage v.2 -> Storage v.3

This is where a change from Godot 3.x to Godot 4.x occured. The storage didn't actually change, but due to Godot's own compatability breaking changes/renames, two formats cannot be used interchangeably. 

Read previous paragraph to get an idea of how the storage works (and account for Godot 4.x renames).
