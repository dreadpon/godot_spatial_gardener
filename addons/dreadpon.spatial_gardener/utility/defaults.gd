tool


#-------------------------------------------------------------------------------
# A list of default variables
#-------------------------------------------------------------------------------


const Toolshed = preload("../toolshed/toolshed.gd")
const Toolshed_Brush = preload("../toolshed/toolshed_brush.gd")




# A default Toolshed
# This belongs in toolshed.gd, but until 3.5 calling new() from a static function isn't possible
static func DEFAULT_TOOLSHED():
	return Toolshed.new([
		Toolshed_Brush.new(Toolshed_Brush.BrushType.PAINT, 1.0, 10.0),
		Toolshed_Brush.new(Toolshed_Brush.BrushType.ERASE, 1.0, 10.0),
		Toolshed_Brush.new(Toolshed_Brush.BrushType.SINGLE, 1.0, 1.0),
		Toolshed_Brush.new(Toolshed_Brush.BrushType.REAPPLY, 1.0, 10.0)
	])
