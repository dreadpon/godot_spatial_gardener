tool


#-------------------------------------------------------------------------------
# A list of default variables
#-------------------------------------------------------------------------------


const Toolshed = preload("../toolshed/toolshed.gd")
const Toolshed_Brush = preload("../toolshed/toolshed_brush.gd")




# A default Toolshed
# TODO: this belongs in toolshed.gd, but for now calling new() from a static function isn't possible
# This seems to be the most recent pull request, but it's almost a year old and still isn't merged yet...
#	https://github.com/godotengine/godot/pull/54457
static func DEFAULT_TOOLSHED():
	return Toolshed.new([
		Toolshed_Brush.new(Toolshed_Brush.BrushType.PAINT, 1.0, 10.0),
		Toolshed_Brush.new(Toolshed_Brush.BrushType.ERASE, 1.0, 10.0, 100.0),
		Toolshed_Brush.new(Toolshed_Brush.BrushType.SINGLE, 1.0, 1.0),
		Toolshed_Brush.new(Toolshed_Brush.BrushType.REAPPLY, 1.0, 10.0, 100.0)
	])
