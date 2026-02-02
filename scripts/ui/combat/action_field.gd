# res://scripts/ui/combat/action_field.gd
# Action field with icon, die slots, and charge display
extends PanelContainer
class_name ActionField

# ============================================================================
# ENUMS
# ============================================================================
enum ActionType {
	ATTACK,
	DEFEND,
	HEAL,
	SPECIAL
}

# ============================================================================
# EXPORTS
# ============================================================================
@export var action_type: ActionType = ActionType.ATTACK
@export var action_name: String = "Action"
@export var action_icon: Texture2D = null
@export_multiline var action_description: String = "Does something."
@export var die_slots: int = 1
@export var base_damage: int = 0
@export var damage_multiplier: float = 1.0
@export var required_tags: Array = []
@export var restricted_tags: Array = []

# Source tracking
var source: String = ""
var action_resource: Action = null

# ============================================================================
# NODE REFERENCES - Found from scene
# ============================================================================
@onready var name_label: Label = $VBox/TopRow/NameLabel
@onready var charge_label: Label = $VBox/TopRow/ChargeLabel
@onready var icon_container: PanelContainer = $VBox/IconContainer
@onready var icon_rect: TextureRect = $VBox/IconContainer/CenterContainer/IconVBox/IconRect
@onready var die_slots_grid: GridContainer = $VBox/IconContainer/CenterContainer/IconVBox/DieSlotsGrid

# ============================================================================
# STATE
# ============================================================================
var placed_dice: Array[DieResource] = []
var dice_visuals: Array[Control] = []
var die_slot_panels: Array[PanelContainer] = []
var is_disabled: bool = false

# ============================================================================
# SIGNALS
# ============================================================================
signal action_selected(field: ActionField)
signal action_confirmed(action_data: Dictionary)
signal dice_returned(die: DieResource)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	setup_drop_target()
	create_die_slots()
	update_charge_display()
	update_disabled_state()
	print("✅ ActionField UI created: %s" % action_name)

func create_die_slots():
	"""Create empty die slot panels"""
	# Clear existing
	for child in die_slots_grid.get_children():
		child.queue_free()
	die_slot_panels.clear()
	
	for i in range(die_slots):
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(40, 40)
		
		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.15, 0.2)
		slot_style.set_border_width_all(1)
		slot_style.border_color = Color(0.3, 0.3, 0.4)
		slot_style.set_corner_radius_all(4)
		slot_panel.add_theme_stylebox_override("panel", slot_style)
		
		die_slots_grid.add_child(slot_panel)
		die_slot_panels.append(slot_panel)
		
		# Empty slot indicator
		var empty_label = Label.new()
		empty_label.text = "?"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 24)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.5))
		empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(empty_label)
	
	update_icon_state()

func setup_drop_target():
	"""Setup as drop target for dice"""
	mouse_filter = Control.MOUSE_FILTER_STOP
	print("🎯 ActionField '%s' set up as drop target" % action_name)

# ============================================================================
# CHARGE MANAGEMENT
# ============================================================================

func has_charges() -> bool:
	"""Check if action has charges available"""
	if not action_resource:
		return true
	return action_resource.has_charges()

func consume_charge() -> bool:
	"""Consume a charge when action is used"""
	if not action_resource:
		return true
	var result = action_resource.consume_charge()
	update_charge_display()
	update_disabled_state()
	return result

func update_charge_display():
	"""Update the charge label from action_resource"""
	if not charge_label:
		return
	
	if not action_resource:
		charge_label.text = ""
		charge_label.hide()
		return
	
	if action_resource.charge_type == Action.ChargeType.UNLIMITED:
		charge_label.text = ""
		charge_label.hide()
		return
	
	charge_label.show()
	charge_label.text = "%d/%d" % [action_resource.current_charges, action_resource.max_charges]
	
	# Color based on charges remaining
	if action_resource.current_charges == 0:
		charge_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	elif action_resource.current_charges == 1:
		charge_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	else:
		charge_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))

func update_disabled_state():
	"""Update visual state based on whether action can be used"""
	is_disabled = not has_charges()
	
	if is_disabled:
		modulate = Color(0.5, 0.5, 0.5, 0.7)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		modulate = Color.WHITE
		mouse_filter = Control.MOUSE_FILTER_STOP
	
	update_icon_state()

func refresh_charge_state():
	"""Called when charges change - update display and state"""
	update_charge_display()
	update_disabled_state()

# ============================================================================
# UI UPDATES
# ============================================================================

func update_icon_state():
	"""Dim icon when dice are placed or disabled"""
	if not icon_rect:
		return
	
	if is_disabled:
		icon_rect.modulate = Color(0.3, 0.3, 0.3)
	elif placed_dice.size() > 0:
		icon_rect.modulate = Color(0.5, 0.5, 0.5)
	else:
		icon_rect.modulate = Color.WHITE

func _gui_input(event: InputEvent):
	"""Handle clicking on action field"""
	if is_disabled:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_ready_to_confirm():
			action_selected.emit(self)

func configure_from_dict(action_data: Dictionary):
	"""Configure this action field from a dictionary"""
	print("🔧 Configuring ActionField with: %s" % action_data.get("name", "Unknown"))
	
	action_name = action_data.get("name", "Action")
	action_description = action_data.get("description", "")
	action_icon = action_data.get("icon", null)
	action_type = action_data.get("action_type", ActionType.ATTACK)
	die_slots = action_data.get("die_slots", 1)
	base_damage = action_data.get("base_damage", 0)
	damage_multiplier = action_data.get("damage_multiplier", 1.0)
	required_tags = action_data.get("required_tags", [])
	restricted_tags = action_data.get("restricted_tags", [])
	source = action_data.get("source", "")
	action_resource = action_data.get("action_resource", null)
	
	if is_node_ready():
		refresh_ui()
	else:
		print("  ⚠️ Nodes not ready yet, will refresh on _ready")

func refresh_ui():
	"""Refresh visual elements to match current properties"""
	if name_label:
		name_label.text = action_name
	
	if icon_rect:
		icon_rect.texture = action_icon
	
	# Recreate die slots if count changed
	if die_slot_panels.size() != die_slots:
		placed_dice.clear()
		dice_visuals.clear()
		create_die_slots()
	
	update_charge_display()
	update_disabled_state()

# ============================================================================
# DRAG AND DROP
# ============================================================================

func _can_drop_data(_at_position: Vector2, data) -> bool:
	"""Check if we can accept this drop"""
	if is_disabled:
		return false
	if not data is Dictionary:
		return false
	if not data.has("die"):
		return false
	if placed_dice.size() >= die_slots:
		return false
	
	var die = data.die as DieResource
	if not die:
		return false
	
	# Check tag restrictions
	for tag in required_tags:
		if not die.has_tag(tag):
			return false
	
	for tag in restricted_tags:
		if die.has_tag(tag):
			return false
	
	return true

func _drop_data(_at_position: Vector2, data):
	"""Handle die drop"""
	if is_disabled:
		return
	
	var die = data.die as DieResource
	if not die:
		return
	
	place_die(die)
	action_selected.emit(self)

func place_die(die: DieResource):
	"""Place a die in the next available slot"""
	if placed_dice.size() >= die_slots:
		return
	if is_disabled:
		return
	
	placed_dice.append(die)
	
	# Update slot visual
	var slot_index = placed_dice.size() - 1
	if slot_index < die_slot_panels.size():
		var slot_panel = die_slot_panels[slot_index]
		
		# Clear empty indicator
		for child in slot_panel.get_children():
			child.queue_free()
		
		# Add die visual
		var die_visual = _create_placed_die_visual(die)
		slot_panel.add_child(die_visual)
		dice_visuals.append(die_visual)
	
	update_icon_state()

func _create_placed_die_visual(die: DieResource) -> Control:
	"""Create a visual for a placed die"""
	var container = CenterContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(vbox)
	
	# Show icon if available
	if die.icon:
		var icon = TextureRect.new()
		icon.texture = die.icon
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if die.color != Color.WHITE:
			icon.modulate = die.color
		vbox.add_child(icon)
	
	var value_label = Label.new()
	value_label.text = str(die.get_total_value())
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(value_label)
	
	return container

# ============================================================================
# ACTION STATE
# ============================================================================

func is_ready_to_confirm() -> bool:
	"""Check if action has minimum dice to confirm"""
	if is_disabled:
		return false
	var min_required = max(1, die_slots) if die_slots > 0 else 1
	return placed_dice.size() >= min_required

func get_total_value() -> int:
	"""Get total value of placed dice"""
	var total = 0
	for die in placed_dice:
		total += die.get_total_value()
	return total

func clear_dice():
	"""Clear all placed dice"""
	placed_dice.clear()
	dice_visuals.clear()
	create_die_slots()

func cancel_action():
	"""Cancel action and return dice"""
	for die in placed_dice:
		dice_returned.emit(die)
	clear_dice()

func set_highlighted(highlighted: bool):
	"""Set highlight state for enemy turn display"""
	if highlighted:
		modulate = Color(1.2, 1.1, 0.9)
	else:
		if is_disabled:
			modulate = Color(0.5, 0.5, 0.5, 0.7)
		else:
			modulate = Color.WHITE
