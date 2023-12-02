# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

<br/><br/>

## [v1.3.1](https://github.com/dreadpon/godot_spatial_gardener/releases/tag/v1.3.1) - 2023-12-02

### Changed

#### Godot 4.2 port
- Plugin is fully ported to Godot 4.2!

<br/>

### Fixed

#### UX
- Fix Issue #31 'Bad looking orange selection's bounding box when using the brush'

#### Stability
- Fix Issue #32 'Buffer argument is not a valid buffer' error spam 
- Fix ThemeAdapter errors to work with Godot 4.2

<br/><br/>

## [v1.3.0](https://github.com/dreadpon/godot_spatial_gardener/releases/tag/v1.3.0) - 2023-08-08

### Changed

#### Godot 4.1 port
- Plugin is fully ported to Godot 4.1! (should work on 4.0 too)
- Special thanks to [@nan0m](https://github.com/nan0m) and [@nonunknown](https://github.com/nonunknown) who kickstarted the whole porting process
- This change breaks compatability with previous versions (duh). Refer [here](reference/TUTORIAL_SCENE_CONVERSION.md) for a conversion guide

#### UI
- Change default mouse button for adjusting brush size and strength from `MOUSE_BUTTON_RIGHT` to `MOUSE_BUTTON_XBUTTON1` to allow both modes of navigation around the scene available in Godot (`WASD+RMB` and `MMB/Shift+MMB`) (you can still change it back)
- Improve performance when creating side panel UI by removing unnecessary intermediate containers
- Slightly improve plant `Paint`ing performance (by adding them in bulks instead of one-by-one). This does not apply to `Erase`ing plants

<br/>

### Fixed

#### Stability
- Fix memory leaks in `octree-node.gd` stemming from a circular reference between parent and leaf nodes, preventing `octree-node.gd` resources and `Node`s they were referencing from being freed
- Fix memory leaks in UI nodes (and those using them) by manually freeing them in several places throughout the plugin

#### Plant creation
- Fix plant data resetting, which was happening when user created a new Gardener, assigned a working directory and then switched between nodes without saving prior (reported by @Jem)

<br/>

### Known issues
- Godot-wide (not plugin-specific) error when opening a project and having no scene open on startup
	- `ERROR: Index p_idx = -1 is out of bounds (edited_scene.size() = 1).`
	- https://github.com/godotengine/godot/issues/79944
	- No negative effects observed beyond error messages
- Godot-wide (not plugin-specific) error that occurs when `Multimesh` is loaded with `resource_local_to_scene` set to `true` and zero instances assigned
	- `buffer_update: Buffer argument is not a valid buffer of any type.`
	`ERROR: Condition "instance_count > 0" is true.`
	- https://github.com/godotengine/godot/issues/68592
	- This might lag the scene on load and flood the console, but seems to work fine after it is loaded

<br/><br/>

## [v1.2.0](https://github.com/dreadpon/godot_spatial_gardener/releases/tag/v1.2.0) - 2022-12-18

### Changed

#### Gardener
- Optimize Gardener storage to use less space in a .tscn file (up to 50% less) (suggested by [@rick551a](https://github.com/rick551a))
	- This change breaks compatability with previous versions. Refer [here](reference/TUTORIAL_SCENE_CONVERSION.md) for a conversion guide

<br/><br/>

## [v1.1.1](https://github.com/dreadpon/godot_spatial_gardener/releases/tag/v1.1.1) - 2022-12-13
### Added

#### Gardener
- Implement independent plant LODs in instanced scenes, so those far away benefit from optimizations too (suggested by **@Herger**)
- Implement the ability to import/export instance transforms to JSON and back (for a given plant and Gardener)

<br/><br/>

## [v1.1.0](https://github.com/dreadpon/godot_spatial_gardener/releases/tag/v1.1.0) - 2022-08-24
### Added

#### Plant creation
- Add shadow casting setting to individual LOD Variants (from [@flavelius](https://github.com/Flavelius))

#### Plant painting
- Add Projection brush that works in screen-space and can erase plants stuck in mid-air (suggested by [@flavelius](https://github.com/flavelius))

#### UI
- Add editable plant labels in the gardener sidepanel (suggested by [@justinbarrett](https://github.com/justinbarrett))
- Add foldable property sections to gardener sidepanel
- Add automatic hiding of plant vector blending property when both vectors have the same value (and thus blending makes no sense)

#### Testing
- Add automatic property gathering in plant unit tests (greenhouses in `greenhouse_intervals/` should still be edited manually)

<br/>

### Changed

#### Plant painting
- Rework brushes to continue moving beyond the physics body's boundaries (which was annoying when painting on terrain edges)

#### UI
- Rework plant thumbnail interaction buttons (clear, delete) to prevent visual clutter and accidental presses (suggested by [@justinbarrett](https://github.com/justinbarrett))
- Rework gardener sidepanel UI to more closely resemble Godot's native Inspector
- Move gardener sidepanel creation from code to predefined scenes to ease it's management and clean up code
- Change `ThemeAdapter` to use Godot's editor colors and theme classes as a base for custom UI styling

#### Resources
- Streamline property show/hide functionality to utilize Godot's built-in `PropertyUsageFlags`
- Streamline resource saving and loading for Toolshed and Greenhouse

#### Debugging
- Change `DebugViewer` option from "Show first plant selected for painting" to "Show plant selected for property editing"

#### Misc
- Added new information to tutorials to reflect the biggest changes of this version

<br/>

### Fixed

#### UI
- Fix signal name collision on custom and native HSlider objects that blocks plugin from being enabled

#### Gardener
- Workaround an issue where all Gardener's node references (to DebugViewer and Painter) were reset when saving a new empty scene

#### Formatting
- Format files for POSIX compliance and optimize icons (from [@aaronfranke](https://github.com/aaronfranke))
