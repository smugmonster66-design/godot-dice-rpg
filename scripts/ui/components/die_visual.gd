# die_visual.gd - Single draggable die visual
extends PanelContainer

# ============================================================================
# NODE REFERENCES - Found in _ready(), NOT @onready
# ============================================================================
var vbox: VBoxContainer = null
var type_label: Label = null
var value_label: Label = null
var tags_label: Label = null

# ============================================================================
# STATE
# ============================================================================
var die_data: DieResource = null
var can_drag: bool = true
var _initialized: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	custom_minimum_size = Vector2(90, 110)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Find nodes NOW that scene is ready
	vbox = get_node_or_null("VBoxContainer")
	type_label = get_node_or_null("VBoxContainer/TypeLabel")
	value_label = get_node_or_null("VBoxContainer/ValueLabel")
	tags_label = get_node_or_null("VBoxContainer/TagsLabel")
	
	# Ensure VBoxContainer doesn't block input
	if vbox:
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# If initialize() was called before _ready(), update display now
	if die_data:
		update_display()

func initialize(die: DieResource):
	"""Initialize with die data"""
	die_data = die
	can_drag = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_initialized = true
	
	# Only update if nodes are ready (might not be if called before _ready)
	if is_node_ready():
		if vbox:
			vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		update_display()
	# else: _ready() will call update_display()

func update_display():
	"""Update visual display"""
	if not die_data:
		return
	
	# Type
	if type_label:
		type_label.text = "D%d" % die_data.die_type
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.add_theme_font_size_override("font_size", 12)
		type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Value
	if value_label:
		value_label.text = str(die_data.get_total_value())
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 28)
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Tags
	if tags_label:
		if die_data.tags.size() > 0:
			tags_label.text = "[%s]" % ", ".join(die_data.tags)
			tags_label.show()
		else:
			tags_label.hide()
		tags_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Color
	modulate = die_data.color

# ============================================================================
# DRAG AND DROP
# ============================================================================

func _get_drag_data(_at_position: Vector2):
	"""Start dragging this die"""
	if not can_drag or not die_data:
		return null
	
	# Create preview
	var preview = PanelContainer.new()
	preview.custom_minimum_size = Vector2(70, 90)
	preview.modulate = Color(1, 1, 1, 0.8)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	style.set_corner_radius_all(4)
	preview.add_theme_stylebox_override("panel", style)
	
	var preview_vbox = VBoxContainer.new()
	preview_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	preview.add_child(preview_vbox)
	
	var preview_type = Label.new()
	preview_type.text = "D%d" % die_data.die_type
	preview_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_vbox.add_child(preview_type)
	
	var preview_value = Label.new()
	preview_value.text = str(die_data.get_total_value())
	preview_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_value.add_theme_font_size_override("font_size", 24)
	preview_vbox.add_child(preview_value)
	
	set_drag_preview(preview)
	
	return {
		"die": die_data,
		"visual": self,
		"source": "dice_pool"
	}
