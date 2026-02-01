# dice_grid.gd - Grid container for dice slots with drag-drop
# Attach to: GridContainer
# Add DieSlot children in the editor - see DICE_GRID_SETUP.md
# Works in both Map mode (reorder pool) and Combat mode (hand to action fields)
extends GridContainer
class_name DiceGrid

# ============================================================================
# SIGNALS
# ============================================================================
signal dice_reordered(from_index: int, to_index: int)
signal die_selected(slot: DieSlot, die: DieResource)
signal die_double_clicked(slot: DieSlot, die: DieResource)
signal die_consumed(die: DieResource)  # Combat mode: die was used

# ============================================================================
# MODE - Determines behavior
# ============================================================================
enum GridMode {
	POOL,    # Map mode: show all dice, drag to reorder
	HAND,    # Combat mode: show available dice, drag to action fields
}

# ============================================================================
# EXPORTS - Configure in Inspector
# ============================================================================
@export_group("Behavior")
@export var grid_mode: GridMode = GridMode.POOL
@export var show_empty_slots: bool = true

# ============================================================================
# STATE
# ============================================================================
var dice_collection: PlayerDiceCollection = null
var slots: Array[DieSlot] = []
var selected_slot: DieSlot = null

# Double-click detection
var _last_click_slot: DieSlot = null
var _last_click_time: float = 0.0
const DOUBLE_CLICK_THRESHOLD: float = 0.3

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_slots()
	_connect_slot_signals()
	print("🎲 DiceGrid: Found %d slots" % slots.size())

func _discover_slots():
	"""Find all DieSlot children and configure them based on grid mode"""
	slots.clear()
	
	for child in get_children():
		if child is DieSlot:
			child.slot_index = slots.size()
			
			# Configure slot based on grid mode
			if grid_mode == GridMode.POOL:
				child.drag_type = DieSlot.DragType.REORDER
				child.accepts_drops = true
			else:  # HAND mode
				child.drag_type = DieSlot.DragType.TO_TARGET
				child.accepts_drops = false
			
			slots.append(child)

func _connect_slot_signals():
	"""Connect signals from all discovered slots"""
	for slot in slots:
		if not slot.die_dropped.is_connected(_on_die_dropped):
			slot.die_dropped.connect(_on_die_dropped)
		if not slot.die_clicked.is_connected(_on_slot_clicked):
			slot.die_clicked.connect(_on_slot_clicked)
		if not slot.drag_started.is_connected(_on_drag_started):
			slot.drag_started.connect(_on_drag_started)
		if not slot.drag_ended.is_connected(_on_drag_ended):
			slot.drag_ended.connect(_on_drag_ended)

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
		if dice_collection.die_consumed.is_connected(_on_die_consumed):
			dice_collection.die_consumed.disconnect(_on_die_consumed)
		if dice_collection.die_restored.is_connected(_on_die_restored):
			dice_collection.die_restored.disconnect(_on_die_restored)
	
	dice_collection = collection
	
	# Connect new signals
	if dice_collection:
		dice_collection.dice_changed.connect(refresh)
		dice_collection.dice_rolled.connect(_on_dice_rolled)
		
		# Hand mode needs consume/restore signals
		if grid_mode == GridMode.HAND:
			dice_collection.die_consumed.connect(_on_die_consumed)
			dice_collection.die_restored.connect(_on_die_restored)
	
	refresh()

func refresh():
	"""Refresh all slots from the dice collection"""
	if not dice_collection:
		_clear_all_slots()
		_update_visibility()
		return
	
	# Get dice based on mode
	var dice: Array[DieResource]
	if grid_mode == GridMode.POOL:
		dice = dice_collection.get_all_dice()
	else:  # HAND mode
		dice = dice_collection.get_available_dice()
	
	for i in range(slots.size()):
		var slot = slots[i]
		if i < dice.size():
			slot.set_die(dice[i])
		else:
			slot.clear_die()
	
	_update_visibility()

func _clear_all_slots():
	"""Clear all slots"""
	for slot in slots:
		slot.clear_die()

func _update_visibility():
	"""Update which slots are visible"""
	if not dice_collection:
		for slot in slots:
			slot.visible = show_empty_slots
		return
	
	var dice_count: int
	if grid_mode == GridMode.POOL:
		dice_count = dice_collection.get_total_count()
	else:  # HAND mode
		dice_count = dice_collection.get_available_count()
	
	for i in range(slots.size()):
		if i < dice_count:
			slots[i].visible = true
		else:
			slots[i].visible = show_empty_slots

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_die_dropped(from_slot: DieSlot, to_slot: DieSlot):
	"""Handle drag-drop reordering (POOL mode only)"""
	if grid_mode != GridMode.POOL:
		return
	if not dice_collection:
		return
	
	var from_index = from_slot.slot_index
	var to_index = to_slot.slot_index
	
	# Tell collection to reorder (this triggers refresh via signal)
	dice_collection.reorder_dice(from_index, to_index)
	
	# Emit for external listeners
	dice_reordered.emit(from_index, to_index)

func _on_die_consumed(die: DieResource):
	"""Handle die consumed (HAND mode) - refresh display"""
	if grid_mode == GridMode.HAND:
		refresh()
		die_consumed.emit(die)

func _on_die_restored(die: DieResource):
	"""Handle die restored (HAND mode) - refresh display"""
	if grid_mode == GridMode.HAND:
		refresh()

func _on_slot_clicked(slot: DieSlot):
	"""Handle slot click - selection and double-click detection"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check for double-click
	if _last_click_slot == slot and (current_time - _last_click_time) < DOUBLE_CLICK_THRESHOLD:
		if slot.has_die():
			die_double_clicked.emit(slot, slot.get_die())
		_last_click_slot = null
		return
	
	_last_click_slot = slot
	_last_click_time = current_time
	
	# Handle selection
	if not slot.has_die():
		deselect_all()
		return
	
	if selected_slot == slot:
		deselect_all()
	else:
		deselect_all()
		selected_slot = slot
		slot.set_selected(true)
		die_selected.emit(slot, slot.get_die())

func _on_drag_started(slot: DieSlot, _die: DieResource):
	"""Visual feedback when drag starts"""
	slot.modulate = Color(0.6, 0.6, 0.6, 0.7)

func _on_drag_ended(slot: DieSlot):
	"""Restore visual when drag ends"""
	slot.modulate = Color.WHITE
	refresh()

func _on_dice_rolled(_dice: Array[DieResource]):
	"""Handle dice rolled - refresh and optionally animate"""
	refresh()

# ============================================================================
# SELECTION
# ============================================================================

func deselect_all():
	"""Deselect all slots"""
	for slot in slots:
		slot.set_selected(false)
	selected_slot = null

func get_selected_die() -> DieResource:
	"""Get the currently selected die"""
	if selected_slot and selected_slot.has_die():
		return selected_slot.get_die()
	return null

func get_selected_slot() -> DieSlot:
	"""Get the currently selected slot"""
	return selected_slot

# ============================================================================
# UTILITY
# ============================================================================

func get_slot_at_index(index: int) -> DieSlot:
	"""Get slot by index"""
	if index >= 0 and index < slots.size():
		return slots[index]
	return null

func get_slot_count() -> int:
	"""Get total number of slots"""
	return slots.size()

func highlight_slot(index: int, color: Color = Color.YELLOW):
	"""Highlight a specific slot"""
	var slot = get_slot_at_index(index)
	if slot:
		slot.modulate = color

func clear_highlights():
	"""Clear all slot highlights"""
	for slot in slots:
		slot.modulate = Color.WHITE
