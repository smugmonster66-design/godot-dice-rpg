# res://scripts/ui/combat/enemy_panel.gd
# Container for enemy slots - finds EnemySlot children by name
extends HBoxContainer
class_name EnemyPanel

# ============================================================================
# SIGNALS
# ============================================================================
signal enemy_selected(enemy: Combatant, slot_index: int)
signal selection_changed(slot_index: int)

# ============================================================================
# STATE
# ============================================================================
var enemy_slots: Array[EnemySlot] = []
var selected_slot_index: int = 0
var selection_enabled: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_slots()
	_connect_slot_signals()

func _discover_slots():
	"""Find EnemySlot children"""
	enemy_slots.clear()
	
	# Look for slots by name pattern or type
	for i in range(1, 4):  # EnemySlot1, EnemySlot2, EnemySlot3
		var slot = find_child("EnemySlot%d" % i, true, false) as EnemySlot
		if slot:
			slot.slot_index = i - 1
			enemy_slots.append(slot)
	
	# Fallback: find any EnemySlot children
	if enemy_slots.size() == 0:
		for child in get_children():
			if child is EnemySlot:
				child.slot_index = enemy_slots.size()
				enemy_slots.append(child)
	
	print("🎯 EnemyPanel: Found %d enemy slots" % enemy_slots.size())

func _connect_slot_signals():
	"""Connect signals from all slots"""
	for slot in enemy_slots:
		if not slot.slot_clicked.is_connected(_on_slot_clicked):
			slot.slot_clicked.connect(_on_slot_clicked)
		if not slot.slot_hovered.is_connected(_on_slot_hovered):
			slot.slot_hovered.connect(_on_slot_hovered)
		if not slot.slot_unhovered.is_connected(_on_slot_unhovered):
			slot.slot_unhovered.connect(_on_slot_unhovered)

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func initialize_enemies(enemies: Array):
	"""Initialize slots with enemy combatants"""
	print("🎯 EnemyPanel: Initializing with %d enemies" % enemies.size())
	
	for i in range(enemy_slots.size()):
		var slot = enemy_slots[i]
		
		if i < enemies.size() and enemies[i]:
			var enemy = enemies[i] as Combatant
			var data = enemy.enemy_data if enemy else null
			slot.set_enemy(enemy, data)
			print("  Slot %d: %s" % [i, enemy.combatant_name])
		else:
			slot.set_empty()
			print("  Slot %d: Empty" % i)
	
	# Select first living enemy by default
	select_first_living_enemy()

func set_selection_enabled(enabled: bool):
	"""Enable or disable enemy selection"""
	selection_enabled = enabled
	
	if not enabled:
		# Clear visual selection
		for slot in enemy_slots:
			slot.set_selected(false)
	else:
		# Show selection on current slot
		if selected_slot_index >= 0 and selected_slot_index < enemy_slots.size():
			enemy_slots[selected_slot_index].set_selected(true)

func select_enemy(slot_index: int):
	"""Select an enemy by slot index"""
	if slot_index < 0 or slot_index >= enemy_slots.size():
		return
	
	var slot = enemy_slots[slot_index]
	if slot.is_empty or not slot.is_alive():
		return
	
	# Deselect previous
	if selected_slot_index >= 0 and selected_slot_index < enemy_slots.size():
		enemy_slots[selected_slot_index].set_selected(false)
	
	# Select new
	selected_slot_index = slot_index
	if selection_enabled:
		slot.set_selected(true)
	
	selection_changed.emit(slot_index)
	enemy_selected.emit(slot.get_enemy(), slot_index)

func select_first_living_enemy():
	"""Select the first living enemy"""
	for i in range(enemy_slots.size()):
		var slot = enemy_slots[i]
		if not slot.is_empty and slot.is_alive():
			select_enemy(i)
			return
	
	# No living enemies
	selected_slot_index = -1

func get_selected_enemy() -> Combatant:
	"""Get the currently selected enemy"""
	if selected_slot_index >= 0 and selected_slot_index < enemy_slots.size():
		return enemy_slots[selected_slot_index].get_enemy()
	return null

func get_selected_slot_index() -> int:
	"""Get the selected slot index"""
	return selected_slot_index

func update_enemy_health(slot_index: int, current: int, maximum: int):
	"""Update health for a specific slot"""
	if slot_index >= 0 and slot_index < enemy_slots.size():
		enemy_slots[slot_index].update_health(current, maximum)

func on_enemy_died(slot_index: int):
	"""Handle enemy death - select next living enemy if current died"""
	if slot_index == selected_slot_index:
		select_first_living_enemy()

func get_living_enemy_count() -> int:
	"""Count living enemies"""
	var count = 0
	for slot in enemy_slots:
		if not slot.is_empty and slot.is_alive():
			count += 1
	return count

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_slot_clicked(slot: EnemySlot):
	"""Handle slot click"""
	if selection_enabled:
		select_enemy(slot.slot_index)

func _on_slot_hovered(_slot: EnemySlot):
	"""Handle slot hover"""
	pass

func _on_slot_unhovered(_slot: EnemySlot):
	"""Handle slot unhover"""
	pass
