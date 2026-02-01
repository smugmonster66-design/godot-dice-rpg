# die_slot.gd - A single slot in the dice grid
# Handles drag-drop for reordering dice
extends PanelContainer
class_name DieSlot

# ============================================================================
# SIGNALS (bubble up to parent)
# ============================================================================
signal die_dropped(from_slot: DieSlot, to_slot: DieSlot)
signal die_clicked(slot: DieSlot)
signal drag_started(slot: DieSlot)
signal drag_ended(slot: DieSlot)

# ============================================================================
# EXPORTS
# ============================================================================
@export var slot_index: int = 0
@export var slot_size: Vector2 = Vector2(64, 64)
@export var empty_color: Color = Color(0.15, 0.15, 0.15, 0.8)
@export var hover_color: Color = Color(0.3, 0.3, 0.5, 0.9)
@export var selected_color: Color = Color(0.4, 0.4, 0.7, 1.0)

# ============================================================================
# STATE
# ============================================================================
var die: DieResource = null
var is_hovered: bool = false
var is_selected: bool = false
var is_dragging: bool = false
var is_drag_target: bool = false  # Another die is being dragged over this slot

# ============================================================================
# UI REFERENCES
# ============================================================================
var die_visual: Control = null
var empty_label: Label = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("dice_slots")
	
	# Setup container
	custom_minimum_size = slot_size
	mouse_filter = MOUSE_FILTER_STOP
	
	# Create empty state label
	empty_label = Label.new()
	empty_label.text = "+"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 24)
	empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	empty_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(empty_label)
	
	_update_visual()

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			die_clicked.emit(self)

func _notification(what):
	match what:
		NOTIFICATION_MOUSE_ENTER:
			is_hovered = true
			_update_visual()
		NOTIFICATION_MOUSE_EXIT:
			is_hovered = false
			is_drag_target = false
			_update_visual()

# ============================================================================
# DIE MANAGEMENT
# ============================================================================

func set_die(new_die: DieResource):
	"""Set the die in this slot"""
	die = new_die
	_update_visual()

func clear_die():
	"""Remove die from slot"""
	die = null
	_update_visual()

func has_die() -> bool:
	"""Check if slot has a die"""
	return die != null

func get_die() -> DieResource:
	"""Get the die in this slot"""
	return die

# ============================================================================
# DRAG AND DROP
# ============================================================================

func _get_drag_data(_at_position: Vector2) -> Variant:
	"""Start dragging this die"""
	if not die:
		return null
	
	if die.is_locked:
		print("🔒 Cannot drag locked die")
		return null
	
	is_dragging = true
	drag_started.emit(self)
	
	# Create drag preview
	var preview = _create_drag_preview()
	set_drag_preview(preview)
	
	# Return drag data
	return {
		"type": "die_slot",
		"slot": self,
		"die": die,
		"from_index": slot_index
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	"""Check if we can accept dropped data"""
	if not data is Dictionary:
		return false
	
	if data.get("type") != "die_slot":
		return false
	
	# Don't drop on self
	if data.get("slot") == self:
		return false
	
	is_drag_target = true
	_update_visual()
	return true

func _drop_data(_at_position: Vector2, data: Variant):
	"""Handle dropped die"""
	if not data is Dictionary:
		return
	
	var from_slot: DieSlot = data.get("slot")
	if from_slot:
		die_dropped.emit(from_slot, self)
	
	is_drag_target = false
	_update_visual()

func _notification_drag(what):
	"""Handle drag notifications"""
	if what == NOTIFICATION_DRAG_END:
		is_dragging = false
		is_drag_target = false
		drag_ended.emit(self)
		_update_visual()

func _create_drag_preview() -> Control:
	"""Create visual preview while dragging"""
	var preview = PanelContainer.new()
	preview.custom_minimum_size = slot_size
	preview.modulate = Color(1, 1, 1, 0.8)
	
	if die:
		var vbox = VBoxContainer.new()
		vbox.mouse_filter = MOUSE_FILTER_IGNORE
		preview.add_child(vbox)
		
		# Die type
		var type_label = Label.new()
		type_label.text = die.get_type_string()
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.add_theme_font_size_override("font_size", 12)
		type_label.mouse_filter = MOUSE_FILTER_IGNORE
		vbox.add_child(type_label)
		
		# Value
		var value_label = Label.new()
		value_label.text = str(die.get_total_value())
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 20)
		value_label.mouse_filter = MOUSE_FILTER_IGNORE
		vbox.add_child(value_label)
	
	return preview

# ============================================================================
# VISUAL UPDATE
# ============================================================================

func _update_visual():
	"""Update the slot's visual state"""
	# Update background color
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	
	if is_drag_target:
		style.bg_color = hover_color
		style.border_color = Color.WHITE
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
	elif is_selected:
		style.bg_color = selected_color
	elif is_hovered:
		style.bg_color = hover_color
	else:
		style.bg_color = empty_color
	
	add_theme_stylebox_override("panel", style)
	
	# Show/hide empty label
	if empty_label:
		empty_label.visible = (die == null)
	
	# Update die visual
	_update_die_visual()

func _update_die_visual():
	"""Update the die visual display"""
	# Remove existing die visual
	if die_visual and is_instance_valid(die_visual):
		die_visual.queue_free()
		die_visual = null
	
	if not die:
		return
	
	# Create new die visual
	die_visual = VBoxContainer.new()
	die_visual.mouse_filter = MOUSE_FILTER_IGNORE
	die_visual.set_anchors_preset(PRESET_CENTER)
	add_child(die_visual)
	
	# Icon or type label
	if die.icon:
		var icon_rect = TextureRect.new()
		icon_rect.texture = die.icon
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(32, 32)
		icon_rect.mouse_filter = MOUSE_FILTER_IGNORE
		die_visual.add_child(icon_rect)
	else:
		var type_label = Label.new()
		type_label.text = die.get_type_string()
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.add_theme_font_size_override("font_size", 10)
		type_label.add_theme_color_override("font_color", die.color)
		type_label.mouse_filter = MOUSE_FILTER_IGNORE
		die_visual.add_child(type_label)
	
	# Value label
	var value_label = Label.new()
	value_label.text = str(die.get_total_value())
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.mouse_filter = MOUSE_FILTER_IGNORE
	die_visual.add_child(value_label)
	
	# Modifier indicator
	if die.modifier != 0:
		var mod_label = Label.new()
		mod_label.text = "%+d" % die.modifier if die.modifier > 0 else str(die.modifier)
		mod_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mod_label.add_theme_font_size_override("font_size", 8)
		mod_label.add_theme_color_override("font_color", Color.YELLOW if die.modifier > 0 else Color.RED)
		mod_label.mouse_filter = MOUSE_FILTER_IGNORE
		die_visual.add_child(mod_label)
	
	# Affixes indicator
	var affix_count = die.get_all_affixes().size()
	if affix_count > 0:
		var affix_indicator = Label.new()
		affix_indicator.text = "◆" if affix_count == 1 else "◆%d" % affix_count
		affix_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		affix_indicator.add_theme_font_size_override("font_size", 8)
		affix_indicator.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		affix_indicator.mouse_filter = MOUSE_FILTER_IGNORE
		die_visual.add_child(affix_indicator)
	
	# Lock indicator
	if die.is_locked:
		var lock_label = Label.new()
		lock_label.text = "🔒"
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.add_theme_font_size_override("font_size", 10)
		lock_label.mouse_filter = MOUSE_FILTER_IGNORE
		die_visual.add_child(lock_label)
	
	# Apply die color tint
	modulate = die.color

func set_selected(selected: bool):
	"""Set selection state"""
	is_selected = selected
	_update_visual()

# ============================================================================
# TOOLTIP
# ============================================================================

func _make_custom_tooltip(for_text: String) -> Object:
	"""Create custom tooltip with affix details"""
	if not die:
		return null
	
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	# Die name
	var name_label = Label.new()
	name_label.text = die.get_display_name()
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)
	
	# Position info
	var pos_label = Label.new()
	pos_label.text = "Slot %d" % (slot_index + 1)
	pos_label.add_theme_font_size_override("font_size", 10)
	pos_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(pos_label)
	
	# Affixes
	var affixes = die.get_all_affixes()
	if affixes.size() > 0:
		var sep = HSeparator.new()
		vbox.add_child(sep)
		
		var affixes_label = Label.new()
		affixes_label.text = "Dice Affixes:"
		affixes_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(affixes_label)
		
		for affix in affixes:
			var affix_label = Label.new()
			affix_label.text = "• " + affix.get_formatted_description()
			affix_label.add_theme_font_size_override("font_size", 10)
			affix_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			affix_label.custom_minimum_size.x = 200
			vbox.add_child(affix_label)
	
	# Tags
	var tags = die.get_tags()
	if tags.size() > 0:
		var tag_label = Label.new()
		tag_label.text = "Tags: " + ", ".join(tags)
		tag_label.add_theme_font_size_override("font_size", 10)
		tag_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
		vbox.add_child(tag_label)
	
	return panel

func _get_tooltip(_at_position: Vector2) -> String:
	"""Return tooltip text (triggers custom tooltip)"""
	if die:
		return die.get_display_name()
	return ""
