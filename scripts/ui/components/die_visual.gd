# res://scripts/ui/components/die_visual.gd
# Single draggable die visual - shows icon if available
extends PanelContainer

# ============================================================================
# NODE REFERENCES - Found in _ready(), NOT @onready
# ============================================================================
var vbox: VBoxContainer = null
var icon_rect: TextureRect = null
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
	custom_minimum_size = Vector2(70, 90)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Find nodes NOW that scene is ready
	vbox = get_node_or_null("VBoxContainer")
	icon_rect = get_node_or_null("VBoxContainer/IconRect")
	type_label = get_node_or_null("VBoxContainer/TypeLabel")
	value_label = get_node_or_null("VBoxContainer/ValueLabel")
	tags_label = get_node_or_null("VBoxContainer/TagsLabel")
	
	# Create nodes if they don't exist (fallback for scenes without them)
	if not vbox:
		_create_default_layout()
	
	# Ensure VBoxContainer doesn't block input
	if vbox:
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# If initialize() was called before _ready(), update display now
	if die_data:
		update_display()

func _create_default_layout():
	"""Create default layout if scene nodes don't exist"""
	vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)
	
	# Icon (for die texture)
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_rect)
	
	# Type label (shown when no icon)
	type_label = Label.new()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(type_label)
	
	# Value label
	value_label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 24)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(value_label)
	
	# Tags label
	tags_label = Label.new()
	tags_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tags_label.add_theme_font_size_override("font_size", 8)
	tags_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tags_label)

func initialize(die: DieResource):
	"""Initialize with die data"""
	die_data = die
	can_drag = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_initialized = true
	
	# Only update if nodes are ready
	if is_node_ready():
		if vbox:
			vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		update_display()

func set_die(die: DieResource):
	"""Alias for initialize"""
	initialize(die)

func update_display():
	"""Update visual display"""
	if not die_data:
		return
	
	# Icon - show if die has one
	if icon_rect:
		if die_data.icon:
			icon_rect.texture = die_data.icon
			icon_rect.show()
			# Hide type label when icon is shown
			if type_label:
				type_label.hide()
		else:
			icon_rect.hide()
			# Show type label when no icon
			if type_label:
				type_label.show()
	
	# Type label (fallback when no icon)
	if type_label and type_label.visible:
		type_label.text = "D%d" % die_data.die_type
		type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Value
	if value_label:
		value_label.text = str(die_data.get_total_value())
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Tags
	if tags_label:
		if die_data.tags.size() > 0:
			tags_label.text = "[%s]" % ", ".join(die_data.tags)
			tags_label.show()
		else:
			tags_label.hide()
		tags_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Color - apply to whole panel
	if die_data.color != Color.WHITE:
		modulate = die_data.color
	else:
		modulate = Color.WHITE

# ============================================================================
# DRAG AND DROP
# ============================================================================

func _get_drag_data(_at_position: Vector2):
	"""Start dragging this die"""
	if not can_drag or not die_data:
		return null
	
	# Create preview
	var preview = _create_drag_preview()
	set_drag_preview(preview)
	
	return {
		"die": die_data,
		"visual": self,
		"source": "dice_pool",
		"source_position": global_position,
		"slot_index": get_index()  # Index in parent container
	}
	
func _create_drag_preview() -> Control:
	"""Create drag preview that matches the die visual"""
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
	
	# Show icon in preview if available
	if die_data.icon:
		var preview_icon = TextureRect.new()
		preview_icon.texture = die_data.icon
		preview_icon.custom_minimum_size = Vector2(40, 40)
		preview_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview_vbox.add_child(preview_icon)
	else:
		var preview_type = Label.new()
		preview_type.text = "D%d" % die_data.die_type
		preview_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview_vbox.add_child(preview_type)
	
	var preview_value = Label.new()
	preview_value.text = str(die_data.get_total_value())
	preview_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_value.add_theme_font_size_override("font_size", 24)
	preview_vbox.add_child(preview_value)
	
	# Apply color
	if die_data.color != Color.WHITE:
		preview.modulate = die_data.color * Color(1, 1, 1, 0.8)
	
	return preview
