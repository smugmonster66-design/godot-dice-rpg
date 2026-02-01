# player_dice_collection.gd - Manages player's ordered dice collection
# Handles dice ordering, rolling, and affix processing
extends Node
class_name PlayerDiceCollection

# ============================================================================
# SIGNALS
# ============================================================================
signal dice_changed()                                    # Any change to dice array
signal dice_reordered(old_order: Array, new_order: Array)  # Dice were reordered
signal dice_rolled(dice: Array[DieResource])             # All dice rolled
signal die_consumed(die: DieResource)                    # Die was used
signal die_restored(die: DieResource)                    # Die was returned
signal affix_triggered(die: DieResource, affix: DiceAffix)

# ============================================================================
# STATE
# ============================================================================
## All dice in order (position matters for affixes!)
var dice: Array[DieResource] = []

## Dice available this turn (not yet consumed)
var available_dice: Array[DieResource] = []

## Affix processor
var affix_processor: DiceAffixProcessor = null

## Maximum dice the player can have
@export var max_dice: int = 10

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	affix_processor = DiceAffixProcessor.new()
	affix_processor.affix_activated.connect(_on_affix_activated)
	print("🎲 PlayerDiceCollection initialized")

# ============================================================================
# DICE MANAGEMENT
# ============================================================================

func add_die(die: DieResource, at_index: int = -1):
	"""Add a die to the collection at a specific position
	-1 means append to end
	"""
	if dice.size() >= max_dice:
		push_warning("Cannot add die: collection full (%d/%d)" % [dice.size(), max_dice])
		return
	
	if at_index < 0 or at_index >= dice.size():
		dice.append(die)
	else:
		dice.insert(at_index, die)
	
	_update_slot_indices()
	print("🎲 Added %s at position %d (total: %d)" % [die.display_name, die.slot_index, dice.size()])
	dice_changed.emit()

func remove_die(die: DieResource):
	"""Remove a specific die from collection"""
	dice.erase(die)
	available_dice.erase(die)
	_update_slot_indices()
	print("🎲 Removed %s (total: %d)" % [die.display_name, dice.size()])
	dice_changed.emit()

func remove_die_at(index: int) -> DieResource:
	"""Remove and return die at specific index"""
	if index < 0 or index >= dice.size():
		return null
	
	var die = dice[index]
	dice.remove_at(index)
	available_dice.erase(die)
	_update_slot_indices()
	dice_changed.emit()
	return die

func remove_dice_by_source(source: String):
	"""Remove all dice from a specific source"""
	var to_remove: Array[DieResource] = []
	for die in dice:
		if die.source == source:
			to_remove.append(die)
	
	for die in to_remove:
		remove_die(die)
	
	print("🎲 Removed %d dice from source: %s" % [to_remove.size(), source])

func clear_all_dice():
	"""Remove all dice"""
	dice.clear()
	available_dice.clear()
	dice_changed.emit()

# ============================================================================
# REORDERING (The core new feature!)
# ============================================================================

func reorder_dice(from_index: int, to_index: int):
	"""Move a die from one position to another"""
	if from_index < 0 or from_index >= dice.size():
		return
	if to_index < 0 or to_index >= dice.size():
		return
	if from_index == to_index:
		return
	
	var old_order = dice.duplicate()
	var die = dice[from_index]
	
	# Check if die is locked
	if die.is_locked:
		print("🔒 Cannot move locked die: %s" % die.display_name)
		return
	
	# Remove from old position
	dice.remove_at(from_index)
	
	# Insert at new position
	dice.insert(to_index, die)
	
	# Update slot indices
	_update_slot_indices()
	
	print("🎲 Reordered: %s moved from slot %d to slot %d" % [die.display_name, from_index, to_index])
	
	# Emit with old and new orders
	dice_reordered.emit(old_order, dice.duplicate())
	
	# Process ON_REORDER affixes
	_process_reorder_affixes()
	
	dice_changed.emit()

func swap_dice(index_a: int, index_b: int):
	"""Swap two dice positions"""
	if index_a < 0 or index_a >= dice.size():
		return
	if index_b < 0 or index_b >= dice.size():
		return
	if index_a == index_b:
		return
	
	var die_a = dice[index_a]
	var die_b = dice[index_b]
	
	# Check locks
	if die_a.is_locked or die_b.is_locked:
		print("🔒 Cannot swap: one or both dice are locked")
		return
	
	var old_order = dice.duplicate()
	
	# Swap
	dice[index_a] = die_b
	dice[index_b] = die_a
	
	_update_slot_indices()
	
	print("🎲 Swapped: %s (slot %d) <-> %s (slot %d)" % [
		die_a.display_name, index_b, die_b.display_name, index_a
	])
	
	dice_reordered.emit(old_order, dice.duplicate())
	_process_reorder_affixes()
	dice_changed.emit()

func _update_slot_indices():
	"""Update each die's slot_index to match array position"""
	for i in range(dice.size()):
		dice[i].slot_index = i

func _process_reorder_affixes():
	"""Process affixes that trigger on reorder"""
	if affix_processor:
		var result = affix_processor.process_trigger(dice, DiceAffix.Trigger.ON_REORDER)
		_handle_affix_results(result)

# ============================================================================
# TURN MANAGEMENT
# ============================================================================

func roll_all_dice():
	"""Roll all dice at start of turn"""
	print("🎲 Rolling %d dice..." % dice.size())
	
	available_dice.clear()
	
	# First: roll all dice
	for die in dice:
		die.roll()
		available_dice.append(die)
		print("  %s = %d" % [die.display_name, die.get_base_value()])
	
	# Second: process ON_ROLL affixes
	if affix_processor:
		print("  Processing roll affixes...")
		var result = affix_processor.process_trigger(dice, DiceAffix.Trigger.ON_ROLL)
		_handle_affix_results(result)
	
	# Print final values
	print("🎲 Final values after affixes:")
	for die in available_dice:
		var affix_mod = ""
		if die.modified_value != die.current_value:
			affix_mod = " (base %d)" % die.current_value
		print("  %s = %d%s" % [die.display_name, die.get_total_value(), affix_mod])
	
	dice_rolled.emit(available_dice.duplicate())

func consume_die(die: DieResource):
	"""Mark die as consumed for this turn"""
	if die.is_locked:
		print("🔒 Cannot consume locked die: %s" % die.display_name)
		return
	
	# Process ON_USE affixes before removing
	if affix_processor:
		var single_die_array: Array[DieResource] = [die]
		var result = affix_processor.process_trigger(single_die_array, DiceAffix.Trigger.ON_USE)
		_handle_affix_results(result)
	
	available_dice.erase(die)
	print("🎲 Consumed: %s" % die.display_name)
	die_consumed.emit(die)

func restore_die(die: DieResource):
	"""Restore a consumed die back to available"""
	if die in dice and die not in available_dice:
		available_dice.append(die)
		print("🎲 Restored: %s" % die.display_name)
		die_restored.emit(die)

func get_available_count() -> int:
	"""Get count of available dice"""
	return available_dice.size()

func get_total_count() -> int:
	"""Get total dice count"""
	return dice.size()

# ============================================================================
# AFFIX PROCESSING
# ============================================================================

func process_passive_affixes():
	"""Process all PASSIVE affixes (call at appropriate times)"""
	if affix_processor:
		var result = affix_processor.process_trigger(dice, DiceAffix.Trigger.PASSIVE)
		_handle_affix_results(result)

func process_combat_start_affixes():
	"""Process ON_COMBAT_START affixes"""
	if affix_processor:
		var result = affix_processor.process_trigger(dice, DiceAffix.Trigger.ON_COMBAT_START)
		_handle_affix_results(result)

func process_combat_end_affixes():
	"""Process ON_COMBAT_END affixes"""
	if affix_processor:
		var result = affix_processor.process_trigger(dice, DiceAffix.Trigger.ON_COMBAT_END)
		_handle_affix_results(result)

func _handle_affix_results(result: Dictionary):
	"""Handle special effects from affix processing"""
	for effect in result.special_effects:
		match effect.type:
			"duplicate":
				# Create duplicate die and add to collection
				var source_die: DieResource = effect.source_die
				var new_die = source_die.duplicate_die()
				new_die.source = "Duplicated from " + source_die.display_name
				add_die(new_die)
				print("    ✨ Created duplicate die!")
			
			"auto_reroll":
				# Already handled in processor, just log
				pass

func _on_affix_activated(die: DieResource, affix: DiceAffix, targets: Array[int]):
	"""Handle affix activation"""
	affix_triggered.emit(die, affix)

# ============================================================================
# QUERYING
# ============================================================================

func get_die_at(index: int) -> DieResource:
	"""Get die at specific position"""
	if index < 0 or index >= dice.size():
		return null
	return dice[index]

func get_dice_with_tag(tag: String) -> Array[DieResource]:
	"""Get all dice with a specific tag"""
	var result: Array[DieResource] = []
	for die in dice:
		if die.has_tag(tag):
			result.append(die)
	return result

func get_dice_by_source(source: String) -> Array[DieResource]:
	"""Get all dice from a specific source"""
	var result: Array[DieResource] = []
	for die in dice:
		if die.source == source:
			result.append(die)
	return result

func get_dice_by_type(die_type: DieResource.DieType) -> Array[DieResource]:
	"""Get all dice of a specific type"""
	var result: Array[DieResource] = []
	for die in dice:
		if die.die_type == die_type:
			result.append(die)
	return result

func get_available_dice() -> Array[DieResource]:
	"""Get all available (unconsumed) dice"""
	return available_dice.duplicate()

func get_all_dice() -> Array[DieResource]:
	"""Get all dice in order"""
	return dice.duplicate()

func find_die_index(die: DieResource) -> int:
	"""Find index of a die in the collection"""
	return dice.find(die)

# ============================================================================
# AFFIX PREVIEW
# ============================================================================

func get_affix_preview_for_position(die: DieResource, target_index: int) -> String:
	"""Preview what affixes would do if die is moved to a position"""
	if affix_processor:
		return affix_processor.get_affix_description_at_position(
			die, target_index, dice.size()
		)
	return ""

# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dict() -> Dictionary:
	"""Serialize collection"""
	var dice_data: Array[Dictionary] = []
	for die in dice:
		dice_data.append(die.to_dict())
	
	return {
		"dice": dice_data,
		"max_dice": max_dice
	}

func from_dict(data: Dictionary):
	"""Load from dictionary"""
	dice.clear()
	available_dice.clear()
	
	max_dice = data.get("max_dice", 10)
	
	for die_data in data.get("dice", []):
		var die = DieResource.from_dict(die_data)
		dice.append(die)
	
	_update_slot_indices()
	dice_changed.emit()

# ============================================================================
# ADDING DICE FROM EQUIPMENT
# ============================================================================

func add_dice_from_source(die_types: Array, source: String, tags: Array = []):
	"""Add multiple dice from a source (like equipment)"""
	for die_type in die_types:
		var die = DieResource.new(die_type, source)
		for tag in tags:
			if tag is String:
				die.add_tag(tag)
		add_die(die)
