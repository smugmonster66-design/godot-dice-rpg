# player.gd - Complete Player System
extends Node
class_name Player

# Core Stats
var max_hp: int = 100
var current_hp: int = 100
var base_armor: int = 0
var base_barrier: int = 0
var max_mana: int = 50
var current_mana: int = 50
var strength: int = 10
var agility: int = 10
var intellect: int = 10
var luck: int = 10

# Equipment
var equipment: Dictionary = {
	"Head": null,
	"Torso": null,
	"Gloves": null,
	"Boots": null,
	"Main Hand": null,
	"Off Hand": null,
	"Accessory": null
}

# Equipment sets
var equipment_sets: Dictionary = {}

# Inventory
var inventory: Array = []

# Active class
var active_class: PlayerClass = null
var available_classes: Dictionary = {}

# Combat status effects
var status_effects: Dictionary = {
	"overhealth": {"amount": 0, "turns": 0},
	"block": 0,
	"dodge": 0,
	"poison": 0,
	"burn": {"amount": 0, "turns": 0},
	"bleed": 0,
	"slowed": {"amount": 0, "turns": 0},
	"stunned": {"amount": 0, "turns": 0},
	"corrode": {"amount": 0, "turns": 0},
	"chill": 0,
	"expose": 0,
	"shadow": 0,
	"ignition": 0,
	"enfeeble": {"amount": 0, "turns": 0}
}
var dice_pool: PlayerDicePool = null

signal stat_changed(stat_name: String, old_value, new_value)
signal equipment_changed(slot: String, item)
signal status_effect_changed(effect: String, value)
signal hp_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)
signal class_changed(new_class: PlayerClass)
signal player_died()

func _ready():
	current_hp = max_hp
	current_mana = max_mana
	
		# Initialize dice pool
	dice_pool = PlayerDicePool.new()
	dice_pool.name = "DicePool"
	add_child(dice_pool)
	
	print("Player dice pool initialized")

# ============================================================================
# STAT MANAGEMENT
# ============================================================================

func get_total_stat(stat_name: String) -> int:
	var base_value = get(stat_name) if stat_name in self else 0
	var equipment_bonus = get_equipment_stat_bonus(stat_name)
	var class_bonus = 0
	if active_class:
		class_bonus = active_class.get_stat_bonus(stat_name)
	return base_value + equipment_bonus + class_bonus

func get_equipment_stat_bonus(stat_name: String) -> int:
	var bonus = 0
	for slot in equipment:
		var item = equipment[slot]
		if item and item.has("stats") and item.stats.has(stat_name):
			# Check affinity matching
			if item.has("affinity") and active_class:
				if item.affinity == active_class.main_stat:
					bonus += item.stats[stat_name]
			else:
				bonus += item.stats[stat_name]
	return bonus

func get_armor() -> int:
	var total = base_armor + get_equipment_stat_bonus("armor")
	if active_class:
		total += active_class.get_stat_bonus("armor")
	# Apply corrode reduction
	total = max(0, total - status_effects["corrode"]["amount"])
	return total

func get_barrier() -> int:
	var total = base_barrier + get_equipment_stat_bonus("barrier")
	if active_class:
		total += active_class.get_stat_bonus("barrier")
	return total

func recalculate_stats():
	# Update max mana based on intellect
	var new_max_mana = 50 + get_total_stat("intellect") * 2
	if new_max_mana != max_mana:
		max_mana = new_max_mana
		current_mana = min(current_mana, max_mana)
		mana_changed.emit(current_mana, max_mana)

# ============================================================================
# HEALTH & MANA
# ============================================================================

func take_damage(amount: int, is_magical: bool = false) -> int:
	var damage_reduction = get_barrier() if is_magical else get_armor()
	damage_reduction += status_effects["block"]
	
	var actual_damage = max(0, amount - damage_reduction)
	
	# Check overhealth first
	if status_effects["overhealth"]["amount"] > 0:
		var overhealth_damage = min(actual_damage, status_effects["overhealth"]["amount"])
		status_effects["overhealth"]["amount"] -= overhealth_damage
		actual_damage -= overhealth_damage
		status_effect_changed.emit("overhealth", status_effects["overhealth"])
	
	current_hp = max(0, current_hp - actual_damage)
	hp_changed.emit(current_hp, max_hp)
	
	if current_hp <= 0:
		die()
	
	return actual_damage

func heal(amount: int):
	var old_hp = current_hp
	current_hp = min(max_hp, current_hp + amount)
	if current_hp != old_hp:
		hp_changed.emit(current_hp, max_hp)

func die():
	print("Player died!")
	player_died.emit()

func restore_mana(amount: int):
	current_mana = min(max_mana, current_mana + amount)
	mana_changed.emit(current_mana, max_mana)

func consume_mana(amount: int) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		mana_changed.emit(current_mana, max_mana)
		return true
	return false

# ============================================================================
# EQUIPMENT MANAGEMENT
# ============================================================================

func equip_item(item: Dictionary, slot: String = "") -> bool:
	var target_slot = slot if slot != "" else item.slot
	
	# Handle heavy weapons
	if item.has("is_heavy") and item.is_heavy:
		if equipment["Main Hand"] != null:
			unequip_item("Main Hand")
		if equipment["Off Hand"] != null:
			unequip_item("Off Hand")
		equipment["Main Hand"] = item
		equipment["Off Hand"] = item  # Reference to same item
	else:
		# Unequip current item in slot
		if equipment[target_slot] != null:
			unequip_item(target_slot)
		equipment[target_slot] = item
	
	# Remove from inventory
	inventory.erase(item)
	
	# ADD THIS after successful equip:
	apply_item_dice(item)
	
	equipment_changed.emit(target_slot, item)
	recalculate_stats()
	return true

func unequip_item(slot: String) -> bool:
	if equipment[slot] == null:
		return false
	
	var item = equipment[slot]
	
		# ADD THIS before unequipping:
	remove_item_dice(item)
	
	# Handle heavy weapons
	if item.has("is_heavy") and item.is_heavy:
		equipment["Main Hand"] = null
		equipment["Off Hand"] = null
	else:
		equipment[slot] = null
	
	# Add to inventory (only once for heavy weapons)
	if not inventory.has(item):
		inventory.append(item)
	
	equipment_changed.emit(slot, null)
	recalculate_stats()
	return true

# ============================================================================
# EQUIPMENT SETS
# ============================================================================

func save_equipment_set(set_name: String):
	var set_data = {}
	for slot in equipment:
		if equipment[slot] != null:
			set_data[slot] = equipment[slot].duplicate()
	equipment_sets[set_name] = set_data
	print("Equipment set '%s' saved" % set_name)

func load_equipment_set(set_name: String) -> bool:
	if not equipment_sets.has(set_name):
		return false
	
	var set_data = equipment_sets[set_name]
	
	# Unequip all current items
	for slot in equipment.keys():
		if equipment[slot] != null:
			unequip_item(slot)
	
	# Equip items from set that are in inventory
	var missing_items = []
	for slot in set_data:
		var item = set_data[slot]
		var found = false
		
		# Check if item exists in inventory
		for inv_item in inventory:
			if items_match(inv_item, item):
				equip_item(inv_item, slot)
				found = true
				break
		
		if not found:
			missing_items.append(slot)
			print("Missing item for slot: %s" % slot)
	
	# Remove missing items from set
	for slot in missing_items:
		set_data.erase(slot)
	
	print("Equipment set '%s' loaded" % set_name)
	return true

func items_match(item1: Dictionary, item2: Dictionary) -> bool:
	return item1.get("name", "") == item2.get("name", "")

# ============================================================================
# CLASS MANAGEMENT
# ============================================================================

func add_class(player_class_name: String, player_class: PlayerClass):
	available_classes[player_class_name] = player_class
	print("Class '%s' added" % player_class_name)

func switch_class(player_class_name: String) -> bool:
	if not available_classes.has(player_class_name):
		return false
	
	# Remove old class dice
	if active_class and dice_pool:
		dice_pool.remove_dice_by_source(active_class.player_class_name)
	
	# Switch class
	active_class = available_classes[player_class_name]
	
	# Add new class dice
	if dice_pool and active_class:
		var class_dice = active_class.get_all_class_dice()
		dice_pool.add_dice_from_source(class_dice, active_class.player_class_name, ["class"])
	
	class_changed.emit(active_class)
	print("Switched to class: %s" % player_class_name)
	return true

# ============================================================================
# STATUS EFFECT MANAGEMENT
# ============================================================================

func add_status_effect(effect: String, amount: int, turns: int = 0):
	if effect in ["overhealth", "burn", "slowed", "stunned", "corrode", "enfeeble"]:
		status_effects[effect]["amount"] = amount
		status_effects[effect]["turns"] = turns
	else:
		status_effects[effect] += amount
	
	status_effect_changed.emit(effect, status_effects[effect])

func remove_status_effect(effect: String, amount: int = 0):
	if effect in ["overhealth", "burn", "slowed", "stunned", "corrode", "enfeeble"]:
		if amount > 0:
			status_effects[effect]["amount"] = max(0, status_effects[effect]["amount"] - amount)
		else:
			status_effects[effect]["amount"] = 0
			status_effects[effect]["turns"] = 0
	else:
		if amount > 0:
			status_effects[effect] = max(0, status_effects[effect] - amount)
		else:
			status_effects[effect] = 0
	
	status_effect_changed.emit(effect, status_effects[effect])

func reset_combat_status():
	"""Reset status effects between combats"""
	status_effects = {
		"overhealth": {"amount": 0, "turns": 0},
		"block": 0,
		"dodge": 0,
		"poison": 0,
		"burn": {"amount": 0, "turns": 0},
		"bleed": 0,
		"slowed": {"amount": 0, "turns": 0},
		"stunned": {"amount": 0, "turns": 0},
		"corrode": {"amount": 0, "turns": 0},
		"chill": 0,
		"expose": 0,
		"shadow": 0,
		"ignition": 0,
		"enfeeble": {"amount": 0, "turns": 0}
	}

# ============================================================================
# COMBAT CALCULATIONS
# ============================================================================

func get_crit_chance() -> float:
	var base_crit = 5.0  # 5% base
	var agility_bonus = get_total_stat("agility") * 0.5  # 0.5% per agility
	var expose_bonus = status_effects["expose"] * 2.0  # 2% per expose stack
	return base_crit + agility_bonus + expose_bonus

func get_physical_damage_bonus() -> int:
	return get_total_stat("strength")

func get_magical_damage_bonus() -> int:
	return get_total_stat("intellect")

func get_die_penalty() -> int:
	var penalty = 0
	if status_effects.has("slowed"):
		penalty += status_effects["slowed"]["amount"]
	penalty += floor(status_effects["chill"] / 2.0)
	return penalty

func check_dodge() -> bool:
	if status_effects["dodge"] <= 0:
		return false
	# Simple probability: dodge chance per stack
	return randf() * 100 < status_effects["dodge"] * 10  # 10% per stack

func get_available_combat_actions() -> Array:
	"""Get all available combat actions from equipment and class"""
	var actions = []
	
	# Add weapon actions from equipped items
	for slot in ["Main Hand", "Off Hand"]:
		var item = equipment[slot]
		if item and item.has("combat_actions"):
			for action in item.combat_actions:
				if action not in actions:
					actions.append(action)
	
	# Add class actions
	if active_class and active_class.combat_actions:
		for action in active_class.combat_actions:
			if action not in actions:
				actions.append(action)
	
	return actions

# ============================================================================
# INVENTORY MANAGEMENT
# ============================================================================

func add_to_inventory(item: Dictionary):
	inventory.append(item)

func remove_from_inventory(item: Dictionary):
	inventory.erase(item)
	
func apply_item_dice(item: Dictionary):
	"""Add dice from equipped item to player's pool"""
	if not item.has("dice") or not dice_pool:
		return
	
	var item_dice = item.get("dice", [])
	var item_name = item.get("name", "Unknown Item")
	var tags = item.get("dice_tags", [])
	
	dice_pool.add_dice_from_source(item_dice, item_name, tags)

func remove_item_dice(item: Dictionary):
	"""Remove dice from unequipped item"""
	if not item or not dice_pool:
		return
	
	var item_name = item.get("name", "Unknown Item")
	dice_pool.remove_dice_by_source(item_name)
