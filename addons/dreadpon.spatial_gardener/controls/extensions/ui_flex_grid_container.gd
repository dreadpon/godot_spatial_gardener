tool
extends GridContainer


#-------------------------------------------------------------------------------
# A grid that automatically changes number of columns based on it's max width
# For now works only when inside a ScrollContainer with both size flags set to SIZE_EXPAND_FILL
# lol
#-------------------------------------------------------------------------------

# TODO make this independent from a ScrollContainer or replace with someone else's solution




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init():
	set_meta("class", "UI_FlexGridContainer")


func _ready():
	connect("resized", self, "on_resized")
	get_parent().connect("resized", self, "on_resized")


func _enter_tree():
	on_resized()




#-------------------------------------------------------------------------------
# Resize
#-------------------------------------------------------------------------------


func on_resized():
	recalc_columns()


func recalc_columns():
	var target_size := get_parent_area_size()
	var factual_size := rect_size
	
	if columns > 1 && factual_size.x > target_size.x:
		columns -= 1
	
	var biggest_child_size := Vector2.ZERO
	for child in get_children():
		if child.rect_size.x > biggest_child_size.x:
			biggest_child_size.x = child.rect_size.x
		if child.rect_size.y > biggest_child_size.y:
			biggest_child_size.y = child.rect_size.y
	
	if biggest_child_size.x * (columns + 1) + get_constant("hseparation") * columns < target_size.x:
		columns += 1
