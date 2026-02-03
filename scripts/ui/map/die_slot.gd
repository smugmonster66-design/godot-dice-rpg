# die_slot.gd - A single slot in the dice grid
# Attach to: PanelContainer
# Discovers child nodes via groups - see DICE_GRID_SETUP.md for scene structure
# Works in both Map mode (reorder) and Combat mode (drag to action fields)
extends PanelContainer
class_name DieSlot

# ============================================================================
# SIGNALS
# ============================================================================
signal die_dropped(from_slot: DieSlot, to_slot: DieSlot)
signal die_clicked(slot: DieSlot)
signal drag_started(slot: DieSlot, die: DieResource)
signal drag_ended(slot: DieSlot)

# ============================================================================
# DRAG TYPE - Set by parent DiceGrid
# ============================================================================
enum DragType {
	REORDER,      # Map mode: drag to reorder within grid
	TO_TARGET,    # Combat mode: drag to external targets (action fields)
}

# ============================================================================
# EXPORTS - Configure in Inspector
# ============================================================================
@export var slot_index: int = 0

@export_group("Behavior")
## Set by parent DiceGrid - determines what happens on drag
@export var drag_type: DragType = DragType.REORDER
## If true, slot accepts drops (for reorder mode)
@export var accepts_drops: bool = true

@export_group("Colors")
@export var empty_color: Color = Color(0.15, 0.15, 0.18, 0.9)
@export var hover_color: Color = Color(0.25, 0.25, 0.35, 0)
@export var selected_color: Color = Color(0.3, 0.3, 0.5, 0)
@export var drag_target_color: Color = Color(0.2, 0.4, 0.3, 0.95)

# ============================================================================
# NODE REFERENCES - Discovered from scene
# ============================================================================
var die_display: Control = null      # Container shown when die is present
var empty_display: Control = null    # Container shown when slot is empty
var type_label: Label = null         # Shows "D6", "D8", etc.
var value_label: Label = null        # Shows the rolled value
var modifier_label: Label = null     # Shows "+2" or "-1"
var affix_indicator: Label = null    # Shows "◆" for affixes
var lock_icon: Control = null        # Shows lock when die is locked
var die_visual_scene: PackedScene = preload("res://scenes/ui/components/die_visual.tscn")
var current_die_visual: Control = null


# ============================================================================
# STATE
# ============================================================================
var die: DieResource = null
var is_hovered: bool = false
var is_selected: bool = false
var is_dragging: bool = false
var is_drag_target: bool = false

var _base_style: StyleBox = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_nodes()
	_setup_style()
	mouse_filter = MOUSE_FILTER_STOP
	update_display()

func _discover_nodes():
	"""Find child nodes by groups or names"""
	# Find by groups first (preferred)
	var displays = find_children("*", "Control", false, false)
	for node in displays:
		if node.is_in_group("die_display"):
			die_display = node
		elif node.is_in_group("empty_display"):
			empty_display = node
		elif node.is_in_group("lock_icon"):
			lock_icon = node
	
	# Find labels anywhere in children
	var labels = find_children("*", "Label", true, false)
	for label in labels:
		if label.is_in_group("type_label"):
			type_label = label
		elif label.is_in_group("value_label"):
			value_label = label
		elif label.is_in_group("modifier_label"):
			modifier_label = label
		elif label.is_in_group("affix_indicator"):
			affix_indicator = label
	
	# Fallback: find by node names if groups not set
	if not die_display:
		die_display = get_node_or_null("Content/DieDisplay")
	if not empty_display:
		empty_display = get_node_or_null("Content/EmptyDisplay")
	if not type_label:
		type_label = get_node_or_null("Content/DieDisplay/TypeLabel")
	if not value_label:
		value_label = get_node_or_null("Content/DieDisplay/ValueLabel")
	if not modifier_label:
		modifier_label = get_node_or_null("Content/DieDisplay/ModifierLabel")
	if not affix_indicator:
		affix_indicator = get_node_or_null("Content/DieDisplay/AffixIndicator")
	if not lock_icon:
		lock_icon = get_node_or_null("LockIcon")

func _setup_style():
	"""Store the base style for modifications"""
	_base_style = get_theme_stylebox("panel")
	if not _base_style:
		var style = StyleBoxFlat.new()
		style.bg_color = empty_color
		style.set_corner_radius_all(4)
		add_theme_stylebox_override("panel", style)
		_base_style = style

# ============================================================================
# DIE MANAGEMENT
# ============================================================================

func set_die(new_die: DieResource):
	"""Set the die in this slot"""
	die = new_die
	update_display()

func clear_die():
	"""Remove die from slot"""
	die = null
	update_display()

func has_die() -> bool:
	return die != null

func get_die() -> DieResource:
	return die

# ============================================================================
# DISPLAY UPDATE
# ============================================================================

func update_display():
	"""Update all visual elements based on current state"""
	_update_background()
	
	if die:
		_show_die()
	else:
		_show_empty()


func _show_die():
	"""Show die data in the slot using DieVisual"""
	if empty_display:
		empty_display.hide()
	
	# Hide lock icon unless die is actually locked
	if lock_icon:
		lock_icon.visible = die.is_locked if die else false
	
	# Remove old visual if exists
	if current_die_visual and is_instance_valid(current_die_visual):
		current_die_visual.queue_free()
		current_die_visual = null
	
	# Create DieVisual instance
	if die_visual_scene and die:
		current_die_visual = die_visual_scene.instantiate()
		
		# Show max value in map pool
		current_die_visual.show_max_value = true
		
		if current_die_visual.has_method("set_die"):
			current_die_visual.set_die(die)
		
		# Configure for slot display
		current_die_visual.can_drag = false
		current_die_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Scale to fit slot
		current_die_visual.scale = Vector2(0.6, 0.6)
		
		# Add to die_display container or directly to slot
		if die_display:
			for child in die_display.get_children():
				child.hide()
			die_display.add_child(current_die_visual)
			die_display.show()
		else:
			add_child(current_die_visual)






func _show_empty():
	"""Show empty slot state"""
	if die_display:
		die_display.hide()
	if empty_display:
		empty_display.show()
	
	# Remove die visual
	if current_die_visual and is_instance_valid(current_die_visual):
		current_die_visual.queue_free()
		current_die_visual = null



func _update_background():
	var style = _base_style.duplicate() if _base_style else StyleBoxFlat.new()
	
	if style is StyleBoxFlat:
		if is_drag_target:
			style.bg_color = drag_target_color
			style.border_color = Color.WHITE
			style.set_border_width_all(2)
		elif is_selected:
			style.bg_color = selected_color
		elif die:
			style.bg_color = Color.TRANSPARENT  # Always transparent when die present
		elif is_hovered:
			style.bg_color = hover_color
		else:
			style.bg_color = empty_color
	
	add_theme_stylebox_override("panel", style)


# ============================================================================
# INPUT HANDLING
# ============================================================================

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			die_clicked.emit(self)

func _notification(what):
	match what:
		NOTIFICATION_MOUSE_ENTER:
			is_hovered = true
			_update_background()
		NOTIFICATION_MOUSE_EXIT:
			is_hovered = false
			is_drag_target = false
			_update_background()
		NOTIFICATION_DRAG_END:
			is_dragging = false
			is_drag_target = false
			drag_ended.emit(self)
			update_display()

# ============================================================================
# DRAG AND DROP
# ============================================================================

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not die:
		return null
	
	if die.is_locked:
		return null
	
	is_dragging = true
	drag_started.emit(self, die)
	
	# Create drag preview
	var preview = _create_drag_preview()
	set_drag_preview(preview)
	
	# Return drag data - works for both reorder and combat modes
	return {
		"type": "die_slot" if drag_type == DragType.REORDER else "combat_die",
		"slot": self,
		"die": die,
		"from_index": slot_index,
		"source_grid": get_parent(),
		"visual": self,
		"source_position": global_position,
		"slot_index": slot_index
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Only accept drops if this slot allows it (reorder mode)
	if not accepts_drops:
		return false
	if not data is Dictionary:
		return false
	if data.get("type") != "die_slot":
		return false
	if data.get("slot") == self:
		return false
	
	is_drag_target = true
	_update_background()
	return true

func _drop_data(_at_position: Vector2, data: Variant):
	if not data is Dictionary:
		return
	
	var from_slot: DieSlot = data.get("slot")
	if from_slot:
		die_dropped.emit(from_slot, self)
	
	is_drag_target = false
	update_display()

func _create_drag_preview() -> Control:
	"""Create the visual shown while dragging"""
	var preview = PanelContainer.new()
	preview.custom_minimum_size = custom_minimum_size
	preview.modulate = Color(1, 1, 1, 0.8)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	style.set_corner_radius_all(4)
	preview.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	preview.add_child(vbox)
	
	if die:
		var type_lbl = Label.new()
		type_lbl.text = die.get_type_string()
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(type_lbl)
		
		var value_lbl = Label.new()
		value_lbl.text = str(die.get_total_value())
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_lbl.add_theme_font_size_override("font_size", 20)
		vbox.add_child(value_lbl)
	
	return preview

# ============================================================================
# SELECTION
# ============================================================================

func set_selected(selected: bool):
	is_selected = selected
	_update_background()

# ============================================================================
# TOOLTIP
# ============================================================================

func _get_tooltip(_at_position: Vector2) -> String:
	if not die:
		return "Empty slot"
	
	var lines: Array[String] = [die.get_display_name()]
	lines.append("Slot %d" % (slot_index + 1))
	
	var affixes = die.get_all_affixes()
	if affixes.size() > 0:
		lines.append("")
		lines.append("Dice Affixes:")
		for affix in affixes:
			lines.append("  • " + affix.get_formatted_description())
	
	var tags = die.get_tags()
	if tags.size() > 0:
		lines.append("")
		lines.append("Tags: " + ", ".join(tags))
	
	return "\n".join(lines)
