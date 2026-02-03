# res://scripts/ui/combat/dice_pool_display.gd
# Combat hand display - shows rolled dice available for actions
# Uses CombatDieObject for each die, handles drag initiation
extends HBoxContainer
class_name DicePoolDisplay

# ============================================================================
# SIGNALS
# ============================================================================
signal die_drag_started(die_object: CombatDieObject, die: DieResource)
signal die_drag_ended(die_object: CombatDieObject, was_placed: bool)
signal die_clicked(die_object: CombatDieObject, die: DieResource)

# ============================================================================
# EXPORTS
# ============================================================================
@export var die_spacing: int = 10

# ============================================================================
# STATE
# ============================================================================
var dice_pool: PlayerDiceCollection = null
var die_objects: Array[CombatDieObject] = []
var empty_slot_placeholders: Array[Control] = []

# Currently dragging
var _dragging_die_object: CombatDieObject = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_theme_constant_override("separation", die_spacing)
	alignment = BoxContainer.ALIGNMENT_CENTER

func initialize(pool: PlayerDiceCollection):
	"""Initialize with player's dice collection"""
	dice_pool = pool
	
	if not dice_pool:
		push_warning("DicePoolDisplay: dice_pool is null!")
		return
	
	# Connect to hand signals
	if dice_pool.has_signal("hand_rolled"):
		if not dice_pool.hand_rolled.is_connected(_on_hand_rolled):
			dice_pool.hand_rolled.connect(_on_hand_rolled)
	
	if dice_pool.has_signal("hand_changed"):
		if not dice_pool.hand_changed.is_connected(_on_hand_changed):
			dice_pool.hand_changed.connect(_on_hand_changed)
	
	refresh()

# ============================================================================
# DISPLAY
# ============================================================================

func refresh():
	"""Refresh the display to match current hand"""
	if not dice_pool:
		return
	
	clear_display()
	
	var hand = dice_pool.hand
	for i in range(hand.size()):
		var die = hand[i]
		var die_obj = _create_die_object(die, i)
		if die_obj:
			add_child(die_obj)
			die_objects.append(die_obj)

func clear_display():
	"""Remove all die objects"""
	for obj in die_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	die_objects.clear()
	
	for placeholder in empty_slot_placeholders:
		if is_instance_valid(placeholder):
			placeholder.queue_free()
	empty_slot_placeholders.clear()

func _create_die_object(die: DieResource, index: int) -> CombatDieObject:
	"""Create a CombatDieObject for a die"""
	var die_obj = die.instantiate_combat_visual()
	if not die_obj:
		push_warning("DicePoolDisplay: Failed to instantiate combat visual for %s" % die.display_name)
		return null
	
	die_obj.slot_index = index
	die_obj.draggable = not die.is_locked
	
	# Connect signals
	die_obj.drag_requested.connect(_on_die_drag_requested.bind(die_obj))
	die_obj.clicked.connect(_on_die_clicked.bind(die_obj))
	die_obj.drag_ended.connect(_on_die_drag_ended)
	
	return die_obj

# ============================================================================
# DRAG HANDLING (Parent orchestrates, DieObject provides visuals)
# ============================================================================

func _on_die_drag_requested(die_obj: CombatDieObject):
	"""Handle drag request from a die object"""
	if not die_obj.die_resource:
		return
	
	if die_obj.die_resource.is_locked:
		die_obj.show_reject_feedback()
		return
	
	# Start the drag
	_dragging_die_object = die_obj
	die_obj.start_drag_visual()
	
	# Show empty slot placeholder
	_show_empty_slot_at(die_obj.get_index())
	
	# Create drag data
	var drag_data = {
		"type": "combat_die",
		"die": die_obj.die_resource,
		"die_object": die_obj,
		"source_slot_index": die_obj.slot_index,
		"source_container": self,
		"source_position": die_obj.global_position
	}
	
	# Use Godot's drag system
	die_obj.force_drag(drag_data, die_obj.create_drag_preview())
	
	die_drag_started.emit(die_obj, die_obj.die_resource)

func _on_die_drag_ended(die_obj: CombatDieObject, was_placed: bool):
	"""Handle drag end"""
	_dragging_die_object = null
	
	if was_placed:
		# Die was placed in an action field - remove from display
		_remove_die_object(die_obj)
	else:
		# Drag cancelled - restore display
		_hide_empty_slot()
		die_obj.end_drag_visual(false)
	
	die_drag_ended.emit(die_obj, was_placed)

func _on_die_clicked(die_obj: CombatDieObject):
	"""Handle click on die (not drag)"""
	die_clicked.emit(die_obj, die_obj.die_resource)

# ============================================================================
# EMPTY SLOT MANAGEMENT
# ============================================================================

func _show_empty_slot_at(index: int):
	"""Show an empty slot placeholder where the die was"""
	# Hide the actual die object
	if index >= 0 and index < die_objects.size():
		die_objects[index].visible = false
	
	# Create placeholder if needed
	var placeholder = _create_empty_slot_placeholder()
	
	# Insert at the right position
	if index >= 0 and index < get_child_count():
		move_child(placeholder, index)
	
	empty_slot_placeholders.append(placeholder)

func _hide_empty_slot():
	"""Remove empty slot placeholder and restore die visibility"""
	for placeholder in empty_slot_placeholders:
		if is_instance_valid(placeholder):
			placeholder.queue_free()
	empty_slot_placeholders.clear()
	
	# Restore visibility of all die objects
	for obj in die_objects:
		if is_instance_valid(obj):
			obj.visible = true

func _create_empty_slot_placeholder() -> Control:
	"""Create a visual placeholder for an empty slot"""
	var placeholder = Panel.new()
	placeholder.custom_minimum_size = Vector2(124, 124)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.5)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.4, 0.5)
	style.set_corner_radius_all(8)
	placeholder.add_theme_stylebox_override("panel", style)
	
	add_child(placeholder)
	return placeholder

# ============================================================================
# DIE MANAGEMENT
# ============================================================================

func _remove_die_object(die_obj: CombatDieObject):
	"""Remove a die object from the display"""
	die_objects.erase(die_obj)
	if is_instance_valid(die_obj):
		die_obj.queue_free()
	_hide_empty_slot()

func restore_die(die: DieResource, from_position: Vector2 = Vector2.ZERO):
	"""Restore a die back to the hand (e.g., action cancelled)"""
	# Find the slot index
	var slot_index = -1
	if dice_pool:
		for i in range(dice_pool.hand.size()):
			if dice_pool.hand[i] == die:
				slot_index = i
				break
	
	# Create new die object
	var die_obj = _create_die_object(die, slot_index)
	if not die_obj:
		return
	
	# Insert at correct position
	if slot_index >= 0 and slot_index < get_child_count():
		add_child(die_obj)
		move_child(die_obj, slot_index)
	else:
		add_child(die_obj)
	
	die_objects.insert(slot_index if slot_index >= 0 else die_objects.size(), die_obj)
	
	# Animate restore
	if from_position != Vector2.ZERO:
		die_obj.global_position = from_position
		die_obj.play_restore_animation()

func get_die_object_for(die: DieResource) -> CombatDieObject:
	"""Find the die object for a given DieResource"""
	for obj in die_objects:
		if obj.die_resource == die:
			return obj
	return null

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_hand_rolled(_hand: Array):
	"""Hand was rolled - refresh display"""
	refresh()

func _on_hand_changed():
	"""Hand contents changed - refresh display"""
	refresh()

# ============================================================================
# UTILITY
# ============================================================================

func get_die_at_position(pos: Vector2) -> CombatDieObject:
	"""Get die object at a screen position"""
	for obj in die_objects:
		if obj.get_global_rect().has_point(pos):
			return obj
	return null
