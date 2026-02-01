# dice_grid.gd - Grid of dice slots with drag-drop reordering
# This is the core reorderable dice display
extends GridContainer
class_name DiceGrid

# ============================================================================
# SIGNALS (bubble up to parent)
# ============================================================================
signal dice_reordered(from_index: int, to_index: int)
signal die_selected(slot: DieSlot, die: DieResource)
signal die_double_clicked(slot: DieSlot, die: DieResource)

# ============================================================================
# EXPORTS
# ============================================================================
@export var slot_scene: PackedScene = null
@export var slot_size: Vector2 = Vector2(64, 64)
@export var max_columns: int = 5
@export var show_empty_slots: bool = true
@export var max_slots: int = 10

# ============================================================================
# STATE
# ============================================================================
var dice_collection: PlayerDiceCollection = null
var slots: Array[DieSlot] = []
var selected_slot: DieSlot = null

# Double-click tracking
var last_click_slot: DieSlot = null
var last_click_time: float = 0.0
const DOUBLE_CLICK_TIME: float = 0.3

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("dice_grids")
	columns = max_columns
	
	# Create initial empty slots
	_create_slots()
	
	print("🎲 DiceGrid ready with %d slots" % slots.size())

func _create_slots():
	"""Create the slot nodes"""
	# Clear existing slots
	for slot in slots:
		if is_instance_valid(slot):
			slot.queue_free()
	slots.clear()
	
	# Create slots
	for i in range(max_slots):
		var slot: DieSlot
		
		if slot_scene:
			slot = slot_scene.instantiate()
		else:
			slot = DieSlot.new()
		
		slot.slot_index = i
		slot.slot_size = slot_size
		slot.custom_minimum_size = slot_size
		
		# Connect signals
		slot.die_dropped.connect(_on_die_dropped)
		slot.die_clicked.connect(_on_slot_clicked)
		slot.drag_started.connect(_on_drag_started)
		slot.drag_ended.connect(_on_drag_ended)
		
		add_child(slot)
		slots.append(slot)
	
	_update_slot_visibility()

func _update_slot_visibility():
	"""Update which slots are visible"""
	if not dice_collection:
		# Show all slots if no collection
		for slot in slots:
			slot.visible = show_empty_slots
		return
	
	var dice_count = dice_collection.get_total_count()
	
	for i in range(slots.size()):
		var slot = slots[i]
		if i < dice_count:
			slot.visible = true
		else:
			slot.visible = show_empty_slots

# ============================================================================
# DICE COLLECTION BINDING
# ============================================================================

func initialize(collection: PlayerDiceCollection):
	"""Bind to a dice collection"""
	# Disconnect old signals
	if dice_collection:
		if dice_collection.dice_changed.is_connected(refresh):
			dice_collection.dice_changed.disconnect(refresh)
		if dice_collection.dice_rolled.is_connected(_on_dice_rolled):
			dice_collection.dice_rolled.disconnect(_on_dice_rolled)
	
	dice_collection = collection
	
	# Connect new signals
	if dice_collection:
		dice_collection.dice_changed.connect(refresh)
		dice_collection.dice_rolled.connect(_on_dice_rolled)
	
	refresh()
	print("🎲 DiceGrid initialized with collection")

func refresh():
	"""Refresh the grid display"""
	if not dice_collection:
		_clear_all_slots()
		return
	
	var dice = dice_collection.get_all_dice()
	
	# Update each slot
	for i in range(slots.size()):
		var slot = slots[i]
		
		if i < dice.size():
			slot.set_die(dice[i])
		else:
			slot.clear_die()
	
	_update_slot_visibility()

func _clear_all_slots():
	"""Clear all slots"""
	for slot in slots:
		slot.clear_die()

# ============================================================================
# DRAG AND DROP HANDLING
# ============================================================================

func _on_die_dropped(from_slot: DieSlot, to_slot: DieSlot):
	"""Handle die dropped from one slot to another"""
	if not dice_collection:
		return
	
	var from_index = from_slot.slot_index
	var to_index = to_slot.slot_index
	
	print("🎲 DiceGrid: Reorder request %d -> %d" % [from_index, to_index])
	
	# Tell collection to reorder
	dice_collection.reorder_dice(from_index, to_index)
	
	# Emit signal for external listeners
	dice_reordered.emit(from_index, to_index)

func _on_drag_started(slot: DieSlot):
	"""Handle drag start"""
	# Visual feedback - dim the source slot
	slot.modulate = Color(0.5, 0.5, 0.5, 0.7)

func _on_drag_ended(slot: DieSlot):
	"""Handle drag end"""
	# Restore visual
	slot.modulate = Color.WHITE
	refresh()

# ============================================================================
# SELECTION HANDLING
# ============================================================================

func _on_slot_clicked(slot: DieSlot):
	"""Handle slot clicked"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check for double-click
	if last_click_slot == slot and (current_time - last_click_time) < DOUBLE_CLICK_TIME:
		_on_slot_double_clicked(slot)
		last_click_slot = null
		return
	
	last_click_slot = slot
	last_click_time = current_time
	
	# Handle single click - selection
	if not slot.has_die():
		_deselect_all()
		return
	
	# Toggle selection
	if selected_slot == slot:
		_deselect_all()
	else:
		_deselect_all()
		selected_slot = slot
		slot.set_selected(true)
		die_selected.emit(slot, slot.get_die())

func _on_slot_double_clicked(slot: DieSlot):
	"""Handle double-click on slot"""
	if slot.has_die():
		die_double_clicked.emit(slot, slot.get_die())

func _deselect_all():
	"""Deselect all slots"""
	for slot in slots:
		slot.set_selected(false)
	selected_slot = null

func get_selected_die() -> DieResource:
	"""Get currently selected die"""
	if selected_slot and selected_slot.has_die():
		return selected_slot.get_die()
	return null

func get_selected_slot() -> DieSlot:
	"""Get currently selected slot"""
	return selected_slot

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_dice_rolled(_dice: Array[DieResource]):
	"""Handle dice rolled"""
	refresh()
	
	# Optional: play roll animation
	_play_roll_animation()

func _play_roll_animation():
	"""Play a visual roll animation on all slots"""
	for slot in slots:
		if slot.has_die():
			# Quick shake animation
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(slot, "rotation", 0.1, 0.05)
			tween.chain().tween_property(slot, "rotation", -0.1, 0.05)
			tween.chain().tween_property(slot, "rotation", 0.05, 0.05)
			tween.chain().tween_property(slot, "rotation", 0.0, 0.05)

# ============================================================================
# UTILITY
# ============================================================================

func get_slot_at_index(index: int) -> DieSlot:
	"""Get slot at specific index"""
	if index < 0 or index >= slots.size():
		return null
	return slots[index]

func get_die_at_index(index: int) -> DieResource:
	"""Get die at specific index"""
	var slot = get_slot_at_index(index)
	if slot:
		return slot.get_die()
	return null

func highlight_slot(index: int, color: Color = Color.YELLOW):
	"""Highlight a specific slot"""
	var slot = get_slot_at_index(index)
	if slot:
		slot.modulate = color

func clear_highlights():
	"""Clear all highlights"""
	for slot in slots:
		slot.modulate = Color.WHITE

func highlight_affixes_for_position(die: DieResource, target_index: int):
	"""Show which affixes would activate at a position"""
	if not dice_collection:
		return
	
	var preview = dice_collection.get_affix_preview_for_position(die, target_index)
	print("Preview for %s at slot %d:\n%s" % [die.display_name, target_index, preview])
	# Could show this in a tooltip or overlay
