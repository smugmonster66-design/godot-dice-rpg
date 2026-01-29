# die_visual.gd - Single draggable die visual with DEBUG
extends PanelContainer

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var vbox = $VBoxContainer
@onready var type_label = $VBoxContainer/TypeLabel
@onready var value_label = $VBoxContainer/ValueLabel
@onready var tags_label = $VBoxContainer/TagsLabel

# ============================================================================
# STATE
# ============================================================================
var die_data: DieData = null
var can_drag: bool = true

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	custom_minimum_size = Vector2(90, 110)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	print("🎲 DieVisual _ready")
	print("  - mouse_filter: %s" % mouse_filter)
	print("  - can_drag: %s" % can_drag)

func initialize(die: DieData):
	"""Initialize with die data"""
	die_data = die
	can_drag = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# CRITICAL: Ensure VBoxContainer doesn't block input
	if vbox:
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	update_display()
	
	print("🎲 DieVisual initialized")
	print("  - die: %s" % die.get_display_name())
	print("  - can_drag: %s" % can_drag)
	print("  - mouse_filter: %s" % mouse_filter)
	print("  - is_visible: %s" % is_visible_in_tree())

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
		value_label.add_theme_font_size_override("font_size", 32)
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Tags
	if tags_label:
		if die_data.tags.size() > 0:
			tags_label.text = "[%s]" % ", ".join(die_data.tags)
			tags_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tags_label.add_theme_font_size_override("font_size", 10)
			tags_label.show()
		else:
			tags_label.hide()
		tags_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Color
	modulate = die_data.color

# ============================================================================
# DRAG & DROP - WITH DEBUG
# ============================================================================

func _gui_input(event: InputEvent):
	"""DEBUG: Catch all input events"""
	if event is InputEventMouseButton:
		print("🖱️ DieVisual received mouse button: %s, pressed: %s" % [event.button_index, event.pressed])

func _get_drag_data(at_position: Vector2):
	"""Start dragging"""
	print("🎲 _get_drag_data called!")
	print("  - at_position: %s" % at_position)
	print("  - die_data: %s" % ("EXISTS" if die_data else "NULL"))
	print("  - can_drag: %s" % can_drag)
	
	if not die_data:
		print("  ❌ FAIL: No die_data")
		return null
	
	if not can_drag:
		print("  ❌ FAIL: can_drag is false")
		return null
	
	print("  ✅ Creating drag preview...")
	
	# Create preview
	var preview = PanelContainer.new()
	preview.custom_minimum_size = Vector2(90, 110)
	preview.modulate = Color(1, 1, 1, 0.7)
	
	var preview_vbox = VBoxContainer.new()
	preview.add_child(preview_vbox)
	
	var preview_label = Label.new()
	preview_label.text = str(die_data.get_total_value())
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_label.add_theme_font_size_override("font_size", 32)
	preview_vbox.add_child(preview_label)
	
	set_drag_preview(preview)
	
	var drag_data = {
		"die": die_data,
		"visual": self,
		"value": die_data.get_total_value()
	}
	
	print("  ✅ DRAG STARTED: %s (value: %d)" % [die_data.get_display_name(), die_data.get_total_value()])
	
	return drag_data

func set_dragging_enabled(enabled: bool):
	"""Enable/disable dragging"""
	can_drag = enabled
	
	if not enabled:
		modulate.a = 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		modulate.a = 1.0
		mouse_filter = Control.MOUSE_FILTER_STOP
	
	print("🎲 Dragging %s" % ("ENABLED" if enabled else "DISABLED"))
