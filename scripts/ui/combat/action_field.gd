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

@export_group("Animation")
@export var snap_duration: float = 0.25
@export var return_duration: float = 0.3

# Source tracking
var source: String = ""
var action_resource: Action = null

# ============================================================================
# NODE REFERENCES - Discovered by name in _ready()
# ============================================================================
var name_label: Label = null
var charge_label: Label = null
var icon_container: PanelContainer = null
var icon_rect: TextureRect = null
var die_slots_grid: GridContainer = null
var description_label: RichTextLabel = null

# ============================================================================
# STATE
# ============================================================================
var placed_dice: Array[DieResource] = []
var dice_visuals: Array[Control] = []
var die_slot_panels: Array[PanelContainer] = []
var is_disabled: bool = false

# Track source info for each placed die (for return animation)
var dice_source_info: Array[Dictionary] = []  # [{visual, position, slot_index}, ...]

# ============================================================================
# SIGNALS
# ============================================================================
signal action_selected(field: ActionField)
signal action_confirmed(action_data: Dictionary)
signal dice_returned(die: DieResource, target_position: Vector2)
signal dice_return_complete()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_nodes()
	setup_drop_target()
	create_die_slots()
	refresh_ui()
	print("✅ ActionField UI created: %s" % action_name)

func _discover_nodes():
	"""Find UI nodes by name, searching recursively"""
	name_label = find_child("NameLabel", true, false) as Label
	charge_label = find_child("ChargeLabel", true, false) as Label
	icon_container = find_child("IconContainer", true, false) as PanelContainer
	icon_rect = find_child("IconRect", true, false) as TextureRect
	die_slots_grid = find_child("DieSlotsGrid", true, false) as GridContainer
	description_label = find_child("DescriptionLabel", true, false) as RichTextLabel

func create_die_slots():
	"""Create empty die slot panels"""
	if not die_slots_grid:
		push_warning("DieSlotsGrid not found in ActionField!")
		return
	
	# Clear existing slots
	for child in die_slots_grid.get_children():
		child.queue_free()
	die_slot_panels.clear()
	
	# Create new slot panels
	for i in range(die_slots):
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(62, 62)  # 62x62 slots
		
		# Style the slot
		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.15, 0.2)
		slot_style.border_color = Color(0.3, 0.3, 0.4)
		slot_style.set_border_width_all(1)
		slot_style.set_corner_radius_all(4)
		slot_panel.add_theme_stylebox_override("panel", slot_style)
		
		# Add empty indicator
		var empty_label = Label.new()
		empty_label.text = "+"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		slot_panel.add_child(empty_label)
		
		die_slots_grid.add_child(slot_panel)
		die_slot_panels.append(slot_panel)


func setup_drop_target():
	"""Setup as drop target for dice"""
	mouse_filter = Control.MOUSE_FILTER_STOP

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

func refresh_ui():
	"""Refresh visual elements to match current properties"""
	if name_label:
		name_label.text = action_name
	
	if icon_rect:
		icon_rect.texture = action_icon
	
	if description_label:
		description_label.text = action_description
	
	# Recreate die slots if count changed
	if die_slots_grid and die_slot_panels.size() != die_slots:
		placed_dice.clear()
		dice_visuals.clear()
		dice_source_info.clear()
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
	
	# Get source info from drop data
	var source_visual = data.get("visual", null) as Control
	var source_position = data.get("source_position", Vector2.ZERO)
	var source_slot_index = data.get("slot_index", -1)
	
	# If source visual provided, get its global position
	if source_visual and is_instance_valid(source_visual):
		source_position = source_visual.global_position
		# Hide the source visual
		source_visual.modulate.a = 0.3
	
	# Place die with animation
	place_die_animated(die, source_position, source_visual, source_slot_index)
	action_selected.emit(self)

func place_die_animated(die: DieResource, from_position: Vector2, source_visual: Control, source_slot_index: int):
	"""Place a die with snap animation"""
	if placed_dice.size() >= die_slots:
		return
	if is_disabled:
		return
	
	placed_dice.append(die)
	
	# Store source info for return animation
	dice_source_info.append({
		"visual": source_visual,
		"position": from_position,
		"slot_index": source_slot_index
	})
	
	# Get target slot
	var slot_index = placed_dice.size() - 1
	if slot_index >= die_slot_panels.size():
		return
	
	var slot_panel = die_slot_panels[slot_index]
	
	# Clear empty indicator
	for child in slot_panel.get_children():
		child.queue_free()
	
	# Create die visual
	var die_visual = _create_placed_die_visual(die)
	slot_panel.add_child(die_visual)
	dice_visuals.append(die_visual)
	
	# Animate snap to slot
	_animate_snap_to_slot(die_visual, slot_panel, from_position)
	
	update_icon_state()

func _animate_snap_to_slot(die_visual: Control, slot_panel: PanelContainer, from_position: Vector2):
	"""Animate die snapping to its slot"""
	# We need to animate in global space, so temporarily reparent
	var target_pos = slot_panel.global_position + slot_panel.size / 2
	
	# Set initial state (at source position)
	die_visual.pivot_offset = die_visual.size / 2
	die_visual.scale = Vector2(1.2, 1.2)
	die_visual.modulate = Color(1.2, 1.2, 0.8, 0.8)
	
	# Animate
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(die_visual, "scale", Vector2.ONE, snap_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(die_visual, "modulate", Color.WHITE, snap_duration).set_ease(Tween.EASE_OUT)
	
	# Flash effect on slot
	var original_style = slot_panel.get_theme_stylebox("panel")
	if original_style is StyleBoxFlat:
		var flash_style = original_style.duplicate() as StyleBoxFlat
		flash_style.border_color = Color(1.0, 0.9, 0.5)
		flash_style.set_border_width_all(2)
		slot_panel.add_theme_stylebox_override("panel", flash_style)
		
		tween.chain().tween_callback(func():
			var revert_style = original_style.duplicate() as StyleBoxFlat
			revert_style.bg_color = Color(0.2, 0.2, 0.25)
			revert_style.border_color = Color(0.4, 0.5, 0.4)
			slot_panel.add_theme_stylebox_override("panel", revert_style)
		)

func place_die(die: DieResource):
	"""Place a die without animation (for programmatic placement)"""
	place_die_animated(die, global_position, null, -1)

func _create_placed_die_visual(die: DieResource) -> Control:
	"""Create a visual for a placed die using DieVisual scene"""
	var die_visual_scene = preload("res://scenes/ui/components/die_visual.tscn")
	var visual = die_visual_scene.instantiate() as DieVisual
	
	if not visual:
		return null
	
	visual.can_drag = false
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.set_die(die)
	
	# Create a container to hold and scale the visual
	var container = Control.new()
	container.custom_minimum_size = Vector2(62, 62)
	container.clip_contents = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Add visual and scale it
	container.add_child(visual)
	visual.scale = Vector2(0.5, 0.5)
	visual.position = Vector2.ZERO
	
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
	"""Clear all placed dice without animation"""
	placed_dice.clear()
	dice_visuals.clear()
	dice_source_info.clear()
	create_die_slots()

func cancel_action():
	"""Cancel action and animate dice returning to hand"""
	if placed_dice.is_empty():
		dice_return_complete.emit()
		return
	
	var return_count = placed_dice.size()
	var returned = 0
	
	# Animate each die back to source
	for i in range(placed_dice.size()):
		var die = placed_dice[i]
		var visual = dice_visuals[i] if i < dice_visuals.size() else null
		var source_info = dice_source_info[i] if i < dice_source_info.size() else {}
		
		var target_pos = source_info.get("position", global_position)
		var source_visual = source_info.get("visual", null)
		
		# Animate return
		if visual and is_instance_valid(visual):
			_animate_return_to_hand(visual, target_pos, source_visual, func():
				returned += 1
				dice_returned.emit(die, target_pos)
				if returned >= return_count:
					_finish_cancel()
			)
		else:
			returned += 1
			dice_returned.emit(die, target_pos)
			# Restore source visual
			if source_visual and is_instance_valid(source_visual):
				source_visual.modulate.a = 1.0
			if returned >= return_count:
				_finish_cancel()

func _animate_return_to_hand(visual: Control, target_pos: Vector2, source_visual: Control, on_complete: Callable):
	"""Animate a die visual returning to the hand"""
	# Get slot panel this visual is in
	var slot_panel = visual.get_parent()
	
	# Get current global position
	var start_pos = slot_panel.global_position if slot_panel else visual.global_position
	
	# Create a temporary visual for animation in a higher layer
	var temp_visual = visual.duplicate()
	var canvas_layer = get_tree().root
	canvas_layer.add_child(temp_visual)
	temp_visual.global_position = start_pos
	temp_visual.z_index = 100
	
	# Hide original
	visual.modulate.a = 0
	
	# Animate to target
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(temp_visual, "global_position", target_pos, return_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(temp_visual, "scale", Vector2(0.8, 0.8), return_duration * 0.5)
	tween.chain().tween_property(temp_visual, "scale", Vector2.ONE, return_duration * 0.5)
	tween.tween_property(temp_visual, "modulate", Color(0.8, 1.0, 0.8), return_duration * 0.5)
	tween.chain().tween_property(temp_visual, "modulate:a", 0.0, return_duration * 0.3)
	
	tween.chain().tween_callback(func():
		temp_visual.queue_free()
		# Restore source visual
		if source_visual and is_instance_valid(source_visual):
			source_visual.modulate.a = 1.0
			# Flash to show it's back
			var flash_tween = create_tween()
			flash_tween.tween_property(source_visual, "modulate", Color(1.3, 1.3, 1.0), 0.1)
			flash_tween.tween_property(source_visual, "modulate", Color.WHITE, 0.1)
		on_complete.call()
	)

func _finish_cancel():
	"""Finish cancellation after all dice returned"""
	placed_dice.clear()
	dice_visuals.clear()
	dice_source_info.clear()
	create_die_slots()
	dice_return_complete.emit()

func set_highlighted(highlighted: bool):
	"""Set highlight state for enemy turn display"""
	if highlighted:
		modulate = Color(1.2, 1.1, 0.9)
	else:
		if is_disabled:
			modulate = Color(0.5, 0.5, 0.5, 0.7)
		else:
			modulate = Color.WHITE
