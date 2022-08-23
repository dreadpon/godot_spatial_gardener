# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
