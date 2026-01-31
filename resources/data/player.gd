# player.gd - Player data resource
extends Resource
class_name Player

# ============================================================================
# CORE STATS
# ============================================================================
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

# ============================================================================
# EQUIPMENT
# ============================================================================
var equipment: Dictionary = {
	"Head": null,
	"Torso": null,
	"Gloves": null,
	"Boots": null,
	"Main Hand": null,
	"Off Hand": null,
	"Accessory": null
}

var equipment_sets: Dictionary = {}

# ============================================================================
# INVENTORY
# ============================================================================
var inventory: Array = []

# ============================================================================
# CLASS SYSTEM
# ============================================================================
var active_class: PlayerClass = null
var available_classes: Dictionary = {}

# ============================================================================
# STATUS EFFECTS
# ============================================================================
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

# ============================================================================
# DICE POOL (created as node at runtime)
# ============================================================================
var dice_pool: PlayerDicePool = null

# ============================================================================
# SIGNALS
# ============================================================================
signal stat_changed(stat_name: String, old_value, new_value)
signal equipment_changed(slot: String, item)
signal status_effect_changed(effect: String, value)
signal hp_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)
signal class_changed(new_class: PlayerClass)
signal player_died()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	current_hp = max_hp
	current_mana = max_mana
	
	# Create dice pool node
	dice_pool = PlayerDicePool.new()
	dice_pool.name = "DicePool"
	
	print("Player resource initialized")

# ============================================================================
# STAT MANAGEMENT
# ============================================================================

func get_total_stat(stat_name: String) -> int:
	"""Calculate total stat using affix pool system"""
	# Get base value from player property (strength, agility, intellect, luck)
	var base = get(stat_name) if stat_name in self else 0
	
	# Add equipment bonuses (old system - keep for compatibility)
	base += get_equipment_stat_bonus(stat_name)
	
	# Add class bonuses
	if active_class:
		base += active_class.get_stat_bonus(stat_name)
	
	# Apply affixes (bonuses then multipliers)
	var final_value = affix_manager.calculate_stat(base, stat_name)
	
	return int(final_value)

func get_equipment_stat_bonus(stat_name: String) -> int:
	"""Get stat bonus from equipment"""
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
	"""Get total armor"""
	var total = base_armor + get_equipment_stat_bonus("armor")
	if active_class:
		total += active_class.get_stat_bonus("armor")
	# Apply corrode
	total = max(0, total - status_effects["corrode"]["amount"])
	return total

func get_barrier() -> int:
	"""Get total barrier"""
	var total = base_barrier + get_equipment_stat_bonus("barrier")
	if active_class:
		total += active_class.get_stat_bonus("barrier")
	return total

func recalculate_stats():
	"""Recalculate derived stats"""
	var new_max_mana = 50 + get_total_stat("intellect") * 2
	if new_max_mana != max_mana:
		max_mana = new_max_mana
		current_mana = min(current_mana, max_mana)
		mana_changed.emit(current_mana, max_mana)

var affix_manager: AffixPoolManager = AffixPoolManager.new()

# ============================================================================
# HEALTH & MANA
# ============================================================================

func take_damage(amount: int, is_magical: bool = false) -> int:
	"""Take damage"""
	var damage_reduction = get_barrier() if is_magical else get_armor()
	damage_reduction += status_effects["block"]
	
	var actual_damage = max(0, amount - damage_reduction)
	
	# Check overhealth
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
	"""Heal HP"""
	var old_hp = current_hp
	current_hp = min(max_hp, current_hp + amount)
	if current_hp != old_hp:
		hp_changed.emit(current_hp, max_hp)

func die():
	"""Player died"""
	print("Player died!")
	player_died.emit()

func restore_mana(amount: int):
	"""Restore mana"""
	current_mana = min(max_mana, current_mana + amount)
	mana_changed.emit(current_mana, max_mana)

func consume_mana(amount: int) -> bool:
	"""Consume mana"""
	if current_mana >= amount:
		current_mana -= amount
		mana_changed.emit(current_mana, max_mana)
		return true
	return false

# ============================================================================
# EQUIPMENT MANAGEMENT
# ============================================================================

func equip_item(item: Dictionary, slot: String = "") -> bool:
	var target_slot = slot if slot != "" else item.get("slot", "")
	
	# Handle heavy weapons (two-handed)
	if item.get("is_heavy", false):
		# Return off-hand to inventory if equipped
		if equipment["Off Hand"] != null:
			var offhand = equipment["Off Hand"]
			equipment["Off Hand"] = null
			inventory.append(offhand)
			print("  Returned off-hand to inventory: %s" % offhand.get("name", "Unknown"))
		
		# Return main hand to inventory if equipped
		if equipment["Main Hand"] != null:
			unequip_item("Main Hand")
		
		# Equip heavy weapon to both slots (reference same item)
		equipment["Main Hand"] = item
		equipment["Off Hand"] = item  # Same reference marks as occupied
		print("  Equipped heavy weapon: %s" % item.get("name", "Unknown"))
	else:
		# Normal single-slot equip
		# Unequip current item in slot
		if equipment[target_slot] != null:
			unequip_item(target_slot)
		equipment[target_slot] = item
	
	# Remove from inventory
	inventory.erase(item)
	
	_add_item_affixes(item)
	
	# Apply item dice
	apply_item_dice(item)
	
	equipment_changed.emit(target_slot, item)
	recalculate_stats()
	return true

func unequip_item(slot: String) -> bool:
	if equipment[slot] == null:
		return false
	
	var item = equipment[slot]
	
	_remove_item_affixes(item)
	
	# Remove item dice
	remove_item_dice(item)
	
	# Handle heavy weapons
	if item.get("is_heavy", false):
		equipment["Main Hand"] = null
		equipment["Off Hand"] = null
		print("  Unequipped heavy weapon from both hands")
	else:
		equipment[slot] = null
	
	# Add to inventory (only once for heavy weapons)
	if not inventory.has(item):
		inventory.append(item)
	
	equipment_changed.emit(slot, null)
	recalculate_stats()
	return true

func apply_item_dice(item: Dictionary):
	"""Add dice from item to pool"""
	if not item.has("dice") or not dice_pool:
		return
	
	var item_dice = item.get("dice", [])
	var item_name = item.get("name", "Unknown Item")
	var tags = item.get("dice_tags", [])
	
	dice_pool.add_dice_from_source(item_dice, item_name, tags)

func remove_item_dice(item: Dictionary):
	"""Remove dice from item"""
	if not item or not dice_pool:
		return
	
	var item_name = item.get("name", "Unknown Item")
	dice_pool.remove_dice_by_source(item_name)

# ============================================================================
# CLASS MANAGEMENT
# ============================================================================

func add_class(p_class_name: String, player_class: PlayerClass):
	"""Add available class"""
	available_classes[p_class_name] = player_class
	print("Added class: %s" % p_class_name)

func switch_class(p_class_name: String) -> bool:
	"""Switch active class"""
	if not available_classes.has(p_class_name):
		return false
	
	# Remove old class dice
	if active_class and dice_pool:
		dice_pool.remove_dice_by_source(active_class.player_class_name)
	
	# Switch
	active_class = available_classes[p_class_name]
	
	# Add new class dice
	if dice_pool and active_class:
		var class_dice = active_class.get_all_class_dice()
		dice_pool.add_dice_from_source(class_dice, active_class.player_class_name, ["class"])
	
	class_changed.emit(active_class)
	print("Switched to class: %s" % p_class_name)
	return true

# ============================================================================
# STATUS EFFECTS
# ============================================================================

func add_status_effect(effect: String, amount: int, turns: int = 0):
	"""Add status effect"""
	if effect in ["overhealth", "burn", "slowed", "stunned", "corrode", "enfeeble"]:
		status_effects[effect]["amount"] = amount
		status_effects[effect]["turns"] = turns
	else:
		status_effects[effect] += amount
	
	status_effect_changed.emit(effect, status_effects[effect])

func remove_status_effect(effect: String, amount: int = 0):
	"""Remove status effect"""
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
	"""Get critical hit chance"""
	var base_crit = 5.0
	var agility_bonus = get_total_stat("agility") * 0.5
	var expose_bonus = status_effects["expose"] * 2.0
	return base_crit + agility_bonus + expose_bonus

func get_physical_damage_bonus() -> int:
	"""Get physical damage bonus"""
	return get_total_stat("strength")

func get_magical_damage_bonus() -> int:
	"""Get magical damage bonus"""
	return get_total_stat("intellect")

func get_die_penalty() -> int:
	"""Get die value penalty from status effects"""
	var penalty = 0
	if status_effects.has("slowed"):
		penalty += status_effects["slowed"]["amount"]
	penalty += floor(status_effects["chill"] / 2.0)
	return penalty

func check_dodge() -> bool:
	"""Check if dodge succeeds"""
	if status_effects["dodge"] <= 0:
		return false
	return randf() * 100 < status_effects["dodge"] * 10

# ============================================================================
# INVENTORY
# ============================================================================

func add_to_inventory(item: Dictionary):
	"""Add item to inventory"""
	inventory.append(item)

func remove_from_inventory(item: Dictionary):
	"""Remove item from inventory"""
	inventory.erase(item)


func _add_item_affixes(item: Dictionary):
	"""Add all affixes from an item to the affix pool"""
	var item_name = item.get("name", "Unknown Item")
	
	if item.has("item_affixes") and item.item_affixes is Array:
		for affix in item.item_affixes:
			if affix is Affix:
				affix_manager.add_affix(affix)

func _remove_item_affixes(item: Dictionary):
	"""Remove all affixes from an item from the affix pool"""
	var item_name = item.get("name", "Unknown Item")
	affix_manager.remove_affixes_by_source(item_name)

func learn_skill(skill: Skill) -> bool:
	"""Learn a skill (adds its affixes to pool)"""
	if not skill.can_rank_up():
		return false
	
	skill.rank_up()
	
	# Get affixes for the new rank
	var new_affixes = skill.get_affixes_for_rank(skill.current_rank)
	
	# Add them to the pool
	for affix in new_affixes:
		affix_manager.add_affix(affix)
	
	recalculate_stats()
	return true

func unlearn_skill_rank(skill: Skill) -> bool:
	"""Remove one rank from a skill (removes that rank's affixes)"""
	if skill.current_rank <= 0:
		return false
	
	# Remove affixes from current rank
	var source_name = "%s - %s Rank %d" % [
		skill.player_class,
		skill.skill_name,
		skill.current_rank
	]
	affix_manager.remove_affixes_by_source(source_name)
	
	skill.rank_down()
	recalculate_stats()
	return true
