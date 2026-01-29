# player_dice_pool.gd - Manages player's dice pool
extends Node
class_name PlayerDicePool

# ============================================================================
# STATE
# ============================================================================
var dice: Array[DieData] = []
var available_dice: Array[DieData] = []

# ============================================================================
# SIGNALS
# ============================================================================
signal dice_changed()
signal dice_rolled(dice: Array[DieData])

# ============================================================================
# DICE MANAGEMENT
# ============================================================================

func add_die(die: DieData):
	"""Add a die to pool"""
	dice.append(die)
	print("Added %s to dice pool (from: %s)" % [die.get_display_name(), die.source])
	dice_changed.emit()

func remove_die(die: DieData):
	"""Remove specific die"""
	dice.erase(die)
	available_dice.erase(die)
	print("Removed %s from dice pool" % die.get_display_name())
	dice_changed.emit()

func remove_dice_by_source(source: String):
	"""Remove all dice from a source"""
	var to_remove = []
	for die in dice:
		if die.source == source:
			to_remove.append(die)
	
	for die in to_remove:
		remove_die(die)
	
	print("Removed %d dice from source: %s" % [to_remove.size(), source])

func add_dice_from_source(die_types: Array, source: String, tags: Array = []):
	"""Add multiple dice from a source"""
	for die_type in die_types:
		var die = DieData.new(die_type, source)
		for tag in tags:
			if tag is String:
				die.add_tag(tag)
		add_die(die)

func clear_all_dice():
	"""Clear all dice"""
	dice.clear()
	available_dice.clear()
	dice_changed.emit()

# ============================================================================
# TURN MANAGEMENT
# ============================================================================

func roll_all_dice():
	"""Roll all dice at start of turn"""
	available_dice.clear()
	
	for die in dice:
		die.roll()
		available_dice.append(die)
	
	print("Rolled %d dice" % available_dice.size())
	for die in available_dice:
		print("  %s = %d" % [die.get_display_name(), die.get_total_value()])
	
	dice_rolled.emit(available_dice.duplicate())

func consume_die(die: DieData):
	"""Mark die as consumed"""
	available_dice.erase(die)
	print("Consumed die: %s" % die.get_display_name())

func restore_die(die: DieData):
	"""Restore consumed die"""
	if die in dice and die not in available_dice:
		available_dice.append(die)
		print("Restored die: %s" % die.get_display_name())

func get_available_count() -> int:
	"""Get available dice count"""
	return available_dice.size()

func get_total_count() -> int:
	"""Get total dice count"""
	return dice.size()

# ============================================================================
# QUERYING
# ============================================================================

func get_dice_with_tag(tag: String) -> Array[DieData]:
	"""Get dice with specific tag"""
	var result: Array[DieData] = []
	for die in dice:
		if die.has_tag(tag):
			result.append(die)
	return result

func get_dice_by_source(source: String) -> Array[DieData]:
	"""Get dice from source"""
	var result: Array[DieData] = []
	for die in dice:
		if die.source == source:
			result.append(die)
	return result

func get_dice_by_type(die_type: DieData.DieType) -> Array[DieData]:
	"""Get dice of specific type"""
	var result: Array[DieData] = []
	for die in dice:
		if die.die_type == die_type:
			result.append(die)
	return result
