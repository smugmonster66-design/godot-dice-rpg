# action_field.gd - Redesigned action field with icon and die slots
extends PanelContainer
class_name ActionField

# ============================================================================
# ENUMS
# ============================================================================
enum ActionCategory {
	ITEM,
	SKILL
}

enum ActionType {
	ATTACK,
	DEFEND,
	HEAL,
	SPECIAL
}

# ============================================================================
# EXPORTS
# ============================================================================
@export var action_category: ActionCategory = ActionCategory.ITEM
@export var action_type: ActionType = ActionType.ATTACK
@export var action_name: String = "Action"
@export var action_icon: Texture2D = null
@export_multiline var action_description: String = "Does something."
@export var die_slots: int = 1  # How many dice this action can hold
@export var base_damage: int = 0
@export var damage_multiplier: float = 1.0
@export var required_tags: Array[String] = []
@export var restricted_tags: Array[String] = []

# Source tracking (for removal when item unequipped)
var source: String = ""  # e.g., "Iron Sword", "Power Strike Skill"

# ============================================================================
# NODE REFERENCES
# ============================================================================
var name_label: Label
var icon_container: PanelContainer
var icon_rect: TextureRect
var die_slots_grid: GridContainer
var description_label: RichTextLabel

# ============================================================================
# STATE
# ============================================================================
var placed_dice: Array[DieData] = []
var dice_visuals: Array[Control] = []
var die_slot_panels: Array[PanelContainer] = []

# ============================================================================
# SIGNALS
# ============================================================================
signal action_selected(field: ActionField)
signal action_confirmed(action_data: Dictionary)
signal dice_returned(die: DieData)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	setup_ui()
	setup_drop_target()

func setup_ui():
	"""Create the UI structure dynamically"""
	custom_minimum_size = Vector2(180, 220)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	
	# Action name at top
	name_label = Label.new()
	name_label.text = action_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)
	
	# Icon container (where dice will be placed)
	icon_container = PanelContainer.new()
	icon_container.custom_minimum_size = Vector2(160, 100)
	vbox.add_child(icon_container)
	
	# Icon styling
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = Color(0.2, 0.2, 0.25)
	icon_style.border_width_left = 2
	icon_style.border_width_right = 2
	icon_style.border_width_top = 2
	icon_style.border_width_bottom = 2
	icon_style.border_color = Color(0.4, 0.4, 0.5)
	icon_style.corner_radius_top_left = 4
	icon_style.corner_radius_top_right = 4
	icon_style.corner_radius_bottom_left = 4
	icon_style.corner_radius_bottom_right = 4
	icon_container.add_theme_stylebox_override("panel", icon_style)
	
	# Center container for icon + die slots
	var center_container = CenterContainer.new()
	icon_container.add_child(center_container)
	
	var icon_vbox = VBoxContainer.new()
	icon_vbox.add_theme_constant_override("separation", 4)
	center_container.add_child(icon_vbox)
	
	# Action icon
	icon_rect = TextureRect.new()
	icon_rect.texture = action_icon
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_vbox.add_child(icon_rect)
	
	# Die slots grid
	die_slots_grid = GridContainer.new()
	die_slots_grid.columns = min(die_slots, 3)  # Max 3 columns
	die_slots_grid.add_theme_constant_override("h_separation", 4)
	die_slots_grid.add_theme_constant_override("v_separation", 4)
	icon_vbox.add_child(die_slots_grid)
	
	# Create die slot panels
	create_die_slots()
	
	# Description
	description_label = RichTextLabel.new()
	description_label.bbcode_enabled = true
	description_label.text = action_description
	description_label.custom_minimum_size = Vector2(160, 60)
	description_label.fit_content = true
	description_label.scroll_active = false
	description_label.add_theme_font_size_override("normal_font_size", 10)
	vbox.add_child(description_label)
	
	print("✅ ActionField UI created: %s" % action_name)

func create_die_slots():
	"""Create visual die slot panels"""
	for i in range(die_slots):
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(40, 40)
		slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.15, 0.2, 0.5)
		slot_style.border_width_left = 1
		slot_style.border_width_right = 1
		slot_style.border_width_top = 1
		slot_style.border_width_bottom = 1
		slot_style.border_color = Color(0.5, 0.5, 0.6)
		slot_style.corner_radius_top_left = 4
		slot_style.corner_radius_top_right = 4
		slot_style.corner_radius_bottom_left = 4
		slot_style.corner_radius_bottom_right = 4
		slot_panel.add_theme_stylebox_override("panel", slot_style)
		
		# Empty label
		var empty_label = Label.new()
		empty_label.text = "○"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 20)
		empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		slot_panel.add_child(empty_label)
		
		die_slots_grid.add_child(slot_panel)
		die_slot_panels.append(slot_panel)

func setup_drop_target():
	"""Enable this field to accept dropped dice"""
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Connect GUI input for clicking
	gui_input.connect(_on_gui_input)

# ============================================================================
# DRAG AND DROP
# ============================================================================

func _can_drop_data(_at_position: Vector2, data) -> bool:
	"""Check if this field can accept the dropped die"""
	if not data is Dictionary or not data.has("die"):
		return false
	
	# Check if we have available slots
	if placed_dice.size() >= die_slots:
		return false
	
	var die: DieData = data.get("die")
	
	# Check required tags
	if required_tags.size() > 0:
		var has_required = false
		for tag in required_tags:
			if die.has_tag(tag):
				has_required = true
				break
		if not has_required:
			return false
	
	# Check restricted tags
	for tag in restricted_tags:
		if die.has_tag(tag):
			return false
	
	return true

func _drop_data(_at_position: Vector2, data):
	"""Handle die being dropped on this field"""
	if not data is Dictionary or not data.has("die"):
		return
	
	var die: DieData = data.get("die")
	var visual: Control = data.get("visual")
	
	add_die(die, visual)

# ============================================================================
# DIE MANAGEMENT
# ============================================================================

func add_die(die: DieData, visual: Control = null):
	"""Add a die to this field"""
	if placed_dice.size() >= die_slots:
		print("⚠️ No available die slots in %s" % action_name)
		return
	
	placed_dice.append(die)
	
	if visual:
		# Get the next available slot
		var slot_index = placed_dice.size() - 1
		var slot_panel = die_slot_panels[slot_index]
		
		# Clear the empty indicator
		for child in slot_panel.get_children():
			child.queue_free()
		
		# Reparent visual to slot
		var original_parent = visual.get_parent()
		if original_parent:
			original_parent.remove_child(visual)
		slot_panel.add_child(visual)
		dice_visuals.append(visual)
		
		# Scale down die to fit slot
		visual.custom_minimum_size = Vector2(38, 38)
		
		# Disable dragging while in field
		if visual.has_method("set_dragging_enabled"):
			visual.set_dragging_enabled(false)
	
	print("✅ Added %s to %s (%d/%d slots)" % [die.get_display_name(), action_name, placed_dice.size(), die_slots])
	
	# Dim icon when dice are placed
	update_icon_state()

func remove_die_at_index(index: int) -> Dictionary:
	"""Remove a die at specific index"""
	if index < 0 or index >= placed_dice.size():
		return {}
	
	var die = placed_dice[index]
	var visual = dice_visuals[index] if index < dice_visuals.size() else null
	
	placed_dice.remove_at(index)
	if visual:
		dice_visuals.remove_at(index)
	
	# Restore slot
	var slot_panel = die_slot_panels[index]
	if visual and visual.get_parent() == slot_panel:
		slot_panel.remove_child(visual)
	
	# Add empty indicator back
	var empty_label = Label.new()
	empty_label.text = "○"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 20)
	empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	slot_panel.add_child(empty_label)
	
	print("🔄 Removed %s from %s" % [die.get_display_name(), action_name])
	
	update_icon_state()
	
	return {"die": die, "visual": visual}

func cancel_action():
	"""Cancel this action and return all dice"""
	print("❌ Canceling %s" % action_name)
	
	# Return all dice
	while placed_dice.size() > 0:
		var data = remove_die_at_index(0)
		if data.has("die"):
			dice_returned.emit(data["die"])

func confirm_action():
	"""Confirm and execute this action"""
	if placed_dice.size() == 0:
		return
	
	print("✅ Confirmed %s with %d dice" % [action_name, placed_dice.size()])
	
	# Build action data
	var action_data = {
		"type": action_type,
		"name": action_name,
		"value": get_total_value(),
		"dice": placed_dice.duplicate(),
		"base_damage": base_damage,
		"multiplier": damage_multiplier,
		"source": source
	}
	
	# Emit confirmation
	action_confirmed.emit(action_data)
	
	# Clear all slots
	cancel_action()

# ============================================================================
# CALCULATIONS
# ============================================================================

func get_total_value() -> int:
	"""Calculate total value of all dice"""
	var total = base_damage
	
	for die in placed_dice:
		total += int(die.get_total_value() * damage_multiplier)
	
	return total

func is_ready_to_confirm() -> bool:
	"""Check if action can be confirmed"""
	return placed_dice.size() > 0

# ============================================================================
# VISUAL UPDATES
# ============================================================================

func update_icon_state():
	"""Dim icon when dice are placed"""
	if placed_dice.size() > 0:
		icon_rect.modulate = Color(0.5, 0.5, 0.5)  # Dimmed
	else:
		icon_rect.modulate = Color.WHITE  # Full brightness

func _on_gui_input(event: InputEvent):
	"""Handle clicking on action field"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_ready_to_confirm():
			action_selected.emit(self)
