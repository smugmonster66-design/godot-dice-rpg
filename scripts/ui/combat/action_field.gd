# res://scripts/ui/combat/action_field.gd
# Action field with icon, die slots, and charge display
# Updated to use CombatDieObject for placed dice
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
# SIGNALS
# ============================================================================
signal action_selected(field: ActionField)
signal action_confirmed(action_data: Dictionary)
signal action_ready(action_field: ActionField)
signal action_cancelled(action_field: ActionField)
signal die_placed(action_field: ActionField, die: DieResource)
signal die_removed(action_field: ActionField, die: DieResource)
signal dice_returned(die: DieResource, target_position: Vector2)
signal dice_return_complete()

# ============================================================================
# NODE REFERENCES
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
var die_slot_panels: Array[Panel] = []
var is_disabled: bool = false
var dice_source_info: Array[Dictionary] = []

const SLOT_SIZE = Vector2(62, 62)
const DIE_SCALE = 0.5

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_nodes()
	_set_children_mouse_pass()
	setup_drop_target()
	create_die_slots()
	refresh_ui()

func _discover_nodes():
	name_label = find_child("NameLabel", true, false) as Label
	charge_label = find_child("ChargeLabel", true, false) as Label
	icon_container = find_child("IconContainer", true, false) as PanelContainer
	icon_rect = find_child("IconRect", true, false) as TextureRect
	die_slots_grid = find_child("DieSlotsGrid", true, false) as GridContainer
	description_label = find_child("DescriptionLabel", true, false) as RichTextLabel

func _set_children_mouse_pass():
	for child in get_children():
		if child is Control and child != self:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
			for subchild in child.get_children():
				if subchild is Control:
					subchild.mouse_filter = Control.MOUSE_FILTER_PASS

func setup_drop_target():
	mouse_filter = Control.MOUSE_FILTER_STOP

# ============================================================================
# DIE SLOT CREATION
# ============================================================================

func create_die_slots():
	if not die_slots_grid:
		return
	
	for child in die_slots_grid.get_children():
		child.queue_free()
	die_slot_panels.clear()
	
	for i in range(die_slots):
		var slot = _create_slot_panel()
		die_slots_grid.add_child(slot)
		die_slot_panels.append(slot)
		_setup_empty_slot(slot)

func _create_slot_panel() -> Panel:
	var slot = Panel.new()
	slot.name = "SlotPanel"
	slot.custom_minimum_size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)
	return slot

func _setup_empty_slot(slot: Panel):
	for child in slot.get_children():
		child.queue_free()
	var lbl = Label.new()
	lbl.name = "EmptyLabel"
	lbl.text = "+"
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(lbl)

# ============================================================================
# CONFIGURATION
# ============================================================================

func configure_from_dict(action_data: Dictionary):
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
	
	if action_resource:
		action_resource.reset_charges_for_combat()
	
	if is_node_ready():
		refresh_ui()

func refresh_ui():
	if name_label:
		name_label.text = action_name
	if icon_rect:
		icon_rect.texture = action_icon
	if description_label:
		description_label.text = action_description
	
	create_die_slots()
	update_charge_display()
	update_disabled_state()

# ============================================================================
# DRAG AND DROP
# ============================================================================

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if is_disabled:
		return false
	if not data is Dictionary:
		return false
	if data.get("type") != "combat_die" and data.get("type") != "die_slot":
		return false
	if placed_dice.size() >= die_slot_panels.size():
		return false
	if not has_charges():
		return false
	return true

func _drop_data(_pos: Vector2, data: Variant):
	if not data is Dictionary:
		return
	
	var die = data.get("die") as DieResource
	var source_obj = data.get("die_object")
	var source_visual = data.get("visual")
	var source_pos = data.get("source_position", global_position) as Vector2
	var source_idx = data.get("slot_index", -1) as int
	
	if source_obj and source_obj.has_method("mark_as_placed"):
		source_obj.mark_as_placed()
	elif source_visual and source_visual.has_method("mark_as_placed"):
		source_visual.mark_as_placed()
	
	place_die_animated(die, source_pos, source_visual, source_idx)

# ============================================================================
# DIE PLACEMENT
# ============================================================================

func place_die_animated(die: DieResource, from_pos: Vector2, source_visual: Control = null, source_idx: int = -1):
	if placed_dice.size() >= die_slot_panels.size():
		return
	
	placed_dice.append(die)
	dice_source_info.append({
		"visual": source_visual,
		"position": from_pos,
		"slot_index": source_idx
	})
	
	var slot_idx = placed_dice.size() - 1
	var slot = die_slot_panels[slot_idx]
	
	for child in slot.get_children():
		child.queue_free()
	
	var visual = _create_placed_visual(die)
	if visual:
		slot.add_child(visual)
		dice_visuals.append(visual)
		_animate_placement(visual, slot, from_pos)
	
	update_icon_state()
	die_placed.emit(self, die)
	
	if is_ready_to_confirm():
		action_ready.emit(self)
		action_selected.emit(self)

func place_die(die: DieResource):
	place_die_animated(die, global_position, null, -1)

func _create_placed_visual(die: DieResource) -> Control:
	# Try to use new DieObject system
	if die.has_method("instantiate_combat_visual"):
		var obj = die.instantiate_combat_visual()
		if obj:
			obj.draggable = false
			obj.mouse_filter = Control.MOUSE_FILTER_IGNORE
			obj.set_display_scale(DIE_SCALE)
			obj.position = (SLOT_SIZE - obj.base_size * DIE_SCALE) / 2
			return obj
	
	# Fallback to old DieVisual if available
	var die_visual_scene = load("res://scenes/ui/components/die_visual.tscn")
	if die_visual_scene:
		var visual = die_visual_scene.instantiate()
		if visual.has_method("set_die"):
			visual.set_die(die)
		visual.can_drag = false
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.scale = Vector2(DIE_SCALE, DIE_SCALE)
		return visual
	
	# Final fallback
	var lbl = Label.new()
	lbl.text = str(die.get_total_value())
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	return lbl

func _animate_placement(visual: Control, _slot: Panel, _from_pos: Vector2):
	visual.scale = Vector2(1.3 * DIE_SCALE, 1.3 * DIE_SCALE)
	visual.modulate = Color(1.2, 1.2, 0.9)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(visual, "scale", Vector2(DIE_SCALE, DIE_SCALE), snap_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(visual, "modulate", Color.WHITE, snap_duration)

# ============================================================================
# STATE CHECKS
# ============================================================================

func is_ready_to_confirm() -> bool:
	return placed_dice.size() >= die_slots and has_charges()

func has_charges() -> bool:
	if not action_resource:
		return true
	return action_resource.has_charges()

func get_total_dice_value() -> int:
	var total = 0
	for die in placed_dice:
		total += die.get_total_value()
	return total

# ============================================================================
# CHARGE MANAGEMENT
# ============================================================================

func consume_charge() -> bool:
	if not action_resource:
		return true
	var result = action_resource.consume_charge()
	update_charge_display()
	update_disabled_state()
	return result

func update_charge_display():
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
	
	if action_resource.current_charges == 0:
		charge_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	elif action_resource.current_charges == 1:
		charge_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	else:
		charge_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))

func update_disabled_state():
	is_disabled = not has_charges()
	if is_disabled:
		modulate = Color(0.5, 0.5, 0.5, 0.7)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		modulate = Color.WHITE
		mouse_filter = Control.MOUSE_FILTER_STOP
	update_icon_state()

func refresh_charge_state():
	update_charge_display()
	update_disabled_state()

# ============================================================================
# UI UPDATES
# ============================================================================

func update_icon_state():
	if not icon_rect:
		return
	if is_disabled:
		icon_rect.modulate = Color(0.3, 0.3, 0.3)
	elif placed_dice.size() > 0:
		icon_rect.modulate = Color(0.5, 0.5, 0.5)
	else:
		icon_rect.modulate = Color.WHITE

func _gui_input(event: InputEvent):
	if is_disabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_ready_to_confirm():
			action_selected.emit(self)

# ============================================================================
# CANCEL / CLEAR
# ============================================================================

func cancel_action():
	for i in range(placed_dice.size()):
		var die = placed_dice[i]
		var info = dice_source_info[i] if i < dice_source_info.size() else {}
		var target_pos = info.get("position", Vector2.ZERO)
		dice_returned.emit(die, target_pos)
	
	_clear_placed_dice()
	action_cancelled.emit(self)
	dice_return_complete.emit()

func _clear_placed_dice():
	for obj in dice_visuals:
		if is_instance_valid(obj):
			obj.queue_free()
	dice_visuals.clear()
	placed_dice.clear()
	dice_source_info.clear()
	
	for slot in die_slot_panels:
		_setup_empty_slot(slot)
	
	update_icon_state()

func consume_dice():
	"""Consume placed dice after action execution"""
	_clear_placed_dice()
	update_icon_state()

func clear_dice():
	"""Alias for consume_dice - clears placed dice from slots"""
	_clear_placed_dice()
	update_icon_state()

func reset_charges():
	if action_resource:
		action_resource.reset_charges_for_combat()
	refresh_charge_state()

# ============================================================================
# ACTION DATA
# ============================================================================

func get_action_data() -> Dictionary:
	return {
		"name": action_name,
		"action_type": action_type,
		"base_damage": base_damage,
		"damage_multiplier": damage_multiplier,
		"placed_dice": placed_dice,
		"total_value": get_total_dice_value(),
		"source": source,
		"action_resource": action_resource
	}
