# affix_pool_manager.gd - Manages categorized affix pools
extends RefCounted
class_name AffixPoolManager

# ============================================================================
# AFFIX POOLS BY CATEGORY
# ============================================================================
var pools: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	_initialize_pools()

func _initialize_pools():
	"""Create empty pools for all categories"""
	# Stat bonuses
	pools["strength_bonus"] = []
	pools["agility_bonus"] = []
	pools["intellect_bonus"] = []
	pools["luck_bonus"] = []
	
	# Stat multipliers
	pools["strength_multiplier"] = []
	pools["agility_multiplier"] = []
	pools["intellect_multiplier"] = []
	pools["luck_multiplier"] = []
	
	# Combat
	pools["damage_bonus"] = []
	pools["damage_multiplier"] = []
	pools["defense_bonus"] = []
	pools["defense_multiplier"] = []
	
	# Special
	pools["elemental"] = []
	pools["misc"] = []
	pools["skill"] = []
	pools["new_action"] = []
	pools["per_turn"] = []
	pools["dice"] = []

# ============================================================================
# ADD/REMOVE AFFIXES
# ============================================================================

func add_affix(affix: Affix):
	"""Add an affix to all its category pools"""
	if not affix:
		return
	
	for category in affix.categories:
		if pools.has(category):
			pools[category].append(affix)
			print("  ✨ Added affix '%s' to pool '%s'" % [affix.affix_name, category])
		else:
			print("  ⚠️ Unknown category: %s" % category)

func remove_affix(affix: Affix):
	"""Remove a specific affix from all pools"""
	if not affix:
		return
	
	for category in affix.categories:
		if pools.has(category):
			pools[category].erase(affix)
			print("  🗑️ Removed affix '%s' from pool '%s'" % [affix.affix_name, category])

func remove_affixes_by_source(source: String):
	"""Remove all affixes from a specific source"""
	var removed_count = 0
	
	for category in pools:
		var pool = pools[category]
		var to_remove = []
		
		for affix in pool:
			if affix.matches_source(source):
				to_remove.append(affix)
		
		for affix in to_remove:
			pool.erase(affix)
			removed_count += 1
	
	if removed_count > 0:
		print("  🗑️ Removed %d affixes from source: %s" % [removed_count, source])

# ============================================================================
# QUERY POOLS
# ============================================================================

func get_pool(category: String) -> Array:
	"""Get all affixes in a category"""
	return pools.get(category, [])

func get_affixes_by_source(source: String) -> Array[Affix]:
	"""Get all affixes from a specific source"""
	var result: Array[Affix] = []
	
	for category in pools:
		for affix in pools[category]:
			if affix.matches_source(source) and affix not in result:
				result.append(affix)
	
	return result

func has_affixes_from_source(source: String) -> bool:
	"""Check if any affixes exist from a source"""
	return get_affixes_by_source(source).size() > 0

# ============================================================================
# CALCULATE STATS
# ============================================================================

func calculate_stat(base_value: float, stat_name: String) -> float:
	"""Calculate a stat with bonuses then multipliers
	
	Args:
		base_value: The base stat value
		stat_name: Name of stat (strength, agility, intellect, luck)
	
	Returns:
		Final calculated value
	"""
	var value = base_value
	
	# Apply bonuses first
	var bonus_category = stat_name + "_bonus"
	if pools.has(bonus_category):
		for affix in pools[bonus_category]:
			value += affix.apply_effect()
	
	# Apply multipliers second
	var mult_category = stat_name + "_multiplier"
	if pools.has(mult_category):
		for affix in pools[mult_category]:
			value *= affix.apply_effect()
	
	return value

func calculate_damage(base_damage: float) -> float:
	"""Calculate damage with bonuses then multipliers"""
	var damage = base_damage
	
	# Apply damage bonuses
	for affix in pools["damage_bonus"]:
		damage += affix.apply_effect()
	
	# Apply damage multipliers
	for affix in pools["damage_multiplier"]:
		damage *= affix.apply_effect()
	
	return damage

func calculate_defense(base_defense: float) -> float:
	"""Calculate defense with bonuses then multipliers"""
	var defense = base_defense
	
	# Apply defense bonuses
	for affix in pools["defense_bonus"]:
		defense += affix.apply_effect()
	
	# Apply defense multipliers
	for affix in pools["defense_multiplier"]:
		defense *= affix.apply_effect()
	
	return defense

# ============================================================================
# GET SPECIAL AFFIXES
# ============================================================================

func get_granted_actions() -> Array:
	"""Get all actions granted by affixes"""
	var actions = []
	
	for affix in pools["new_action"]:
		var action = affix.apply_effect()
		if action:
			actions.append(action)
	
	return actions

func get_granted_dice() -> Array:
	"""Get all dice granted by affixes"""
	var dice = []
	
	for affix in pools["dice"]:
		var affix_dice = affix.apply_effect()
		if affix_dice is Array:
			dice.append_array(affix_dice)
	
	return dice

# ============================================================================
# DEBUG
# ============================================================================

func print_pools():
	"""Debug: print all non-empty pools"""
	print("=== Affix Pools ===")
	for category in pools:
		if pools[category].size() > 0:
			print("  %s: %d affixes" % [category, pools[category].size()])
			for affix in pools[category]:
				print("    - %s" % affix.get_display_text())
