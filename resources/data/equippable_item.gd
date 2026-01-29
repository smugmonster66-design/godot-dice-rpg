# equippable_item.gd - Base class for all equippable items with affix system
extends Resource
class_name EquippableItem

# ============================================================================
# ENUMS
# ============================================================================
enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

enum EquipSlot {
	HEAD,
	TORSO,
	GLOVES,
	BOOTS,
	MAIN_HAND,
	OFF_HAND,
	HEAVY,  # Two-handed weapons - occupies Main Hand + Off Hand
	ACCESSORY
}

# ============================================================================
# BASIC ITEM DATA
# ============================================================================
@export var item_name: String = "New Item"
@export_multiline var description: String = "An equippable item."
@export var icon: Texture2D = null
@export var rarity: Rarity = Rarity.COMMON
@export var equip_slot: EquipSlot = EquipSlot.MAIN_HAND

# ============================================================================
# STATS
# ============================================================================
@export_group("Stats")
@export var strength_bonus: int = 0
@export var agility_bonus: int = 0
@export var intellect_bonus: int = 0
@export var luck_bonus: int = 0
@export var armor_bonus: int = 0
@export var max_hp_bonus: int = 0
@export var max_mana_bonus: int = 0

# ============================================================================
# DICE
# ============================================================================
@export_group("Dice")
@export var grants_dice: Array[DieData.DieType] = []
@export var dice_tags: Array[String] = []  # Tags to apply to granted dice

# ============================================================================
# COMBAT ACTION
# ============================================================================
@export_group("Combat Action")
@export var grants_action: bool = false
@export var action: Action = null  # Reference to Action resource
@export var action_name: String = ""
@export_multiline var action_description: String = ""  # Rich text, e.g., "[color=yellow]1D+1[/color] Slashing"
@export var action_icon: Texture2D = null
@export var die_slots: int = 1  # How many dice can be placed
@export var action_type: ActionField.ActionType = ActionField.ActionType.ATTACK
@export var base_damage: int = 0  # Base value added to formula
@export var damage_multiplier: float = 1.0  # Multiplies die value
@export var required_die_tags: Array[String] = []  # Dice must have ONE of these tags
@export var restricted_die_tags: Array[String] = []  # Dice cannot have any of these

# ============================================================================
# AFFIXES (Applied at generation)
# ============================================================================
var applied_affixes: Array[ItemAffix] = []

# ============================================================================
# UTILITY
# ============================================================================

func is_heavy_weapon() -> bool:
	"""Check if this is a two-handed weapon"""
	return equip_slot == EquipSlot.HEAVY

func get_rarity_color() -> Color:
	"""Get color for rarity tier"""
	match rarity:
		Rarity.COMMON: return Color.WHITE
		Rarity.UNCOMMON: return Color.GREEN
		Rarity.RARE: return Color.BLUE
		Rarity.EPIC: return Color.PURPLE
		Rarity.LEGENDARY: return Color.ORANGE
		_: return Color.WHITE

func get_rarity_name() -> String:
	"""Get rarity name as string"""
	match rarity:
		Rarity.COMMON: return "Common"
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		Rarity.EPIC: return "Epic"
		Rarity.LEGENDARY: return "Legendary"
		_: return "Unknown"

func get_slot_name() -> String:
	"""Get equipment slot name"""
	match equip_slot:
		EquipSlot.HEAD: return "Head"
		EquipSlot.TORSO: return "Torso"
		EquipSlot.GLOVES: return "Gloves"
		EquipSlot.BOOTS: return "Boots"
		EquipSlot.MAIN_HAND: return "Main Hand"
		EquipSlot.OFF_HAND: return "Off Hand"
		EquipSlot.HEAVY: return "Main Hand"  # Heavy weapons go in main hand slot
		EquipSlot.ACCESSORY: return "Accessory"
		_: return "Unknown"

func get_display_name() -> String:
	"""Get full display name with affixes"""
	if applied_affixes.size() == 0:
		return item_name
	
	var prefix = ""
	var suffix = ""
	
	for affix in applied_affixes:
		if affix.is_prefix:
			prefix = affix.display_name + " "
		else:
			suffix = " of " + affix.display_name
	
	return prefix + item_name + suffix

func get_total_stats() -> Dictionary:
	"""Get base stats + affix bonuses"""
	var stats = get_stats_dict()
	
	# Apply affix stat bonuses
	for affix in applied_affixes:
		for stat_name in affix.stat_bonuses:
			var current = stats.get(stat_name, 0)
			stats[stat_name] = current + affix.stat_bonuses[stat_name]
	
	return stats

func get_stats_dict() -> Dictionary:
	"""Get base stats as Dictionary"""
	var stats = {}
	if strength_bonus > 0: stats["strength"] = strength_bonus
	if agility_bonus > 0: stats["agility"] = agility_bonus
	if intellect_bonus > 0: stats["intellect"] = intellect_bonus
	if luck_bonus > 0: stats["luck"] = luck_bonus
	if armor_bonus > 0: stats["armor"] = armor_bonus
	if max_hp_bonus > 0: stats["max_hp"] = max_hp_bonus
	if max_mana_bonus > 0: stats["max_mana"] = max_mana_bonus
	return stats

func get_action_data() -> Dictionary:
	"""Get action data with affix modifications"""
	if not grants_action:
		return {}
	
	var action = {
		"name": action_name,
		"description": action_description,
		"icon": action_icon,
		"die_slots": die_slots,
		"action_type": action_type,
		"base_damage": base_damage,
		"damage_multiplier": damage_multiplier,
		"required_tags": required_die_tags.duplicate(),
		"restricted_tags": restricted_die_tags.duplicate(),
		"category": ActionField.ActionCategory.ITEM,
		"source": get_display_name()
	}
	
	# Apply affix modifications to action
	for affix in applied_affixes:
		action["base_damage"] += affix.base_damage_bonus
		action["damage_multiplier"] *= affix.damage_multiplier
	
	return action

func get_all_actions() -> Array[Dictionary]:
	"""Get all actions (base + affix-granted)"""
	var actions: Array[Dictionary] = []
	
	# Add base action
	if grants_action:
		actions.append(get_action_data())
	
	# Add affix-granted actions
	for affix in applied_affixes:
		if affix.grants_action:
			var affix_action = affix.get_action_data()
			affix_action["source"] = get_display_name() + " (" + affix.display_name + ")"
			actions.append(affix_action)
	
	return actions

func to_dict() -> Dictionary:
	"""Convert to Dictionary for compatibility with old inventory system"""
	var dict = {
		"name": get_display_name(),
		"slot": get_slot_name(),
		"description": get_full_description(),
		"stats": get_total_stats(),
		"dice": grants_dice.duplicate(),
		"dice_tags": dice_tags.duplicate(),
		"is_heavy": is_heavy_weapon()
	}
	
	var actions = get_all_actions()
	if actions.size() > 0:
		dict["actions"] = actions
	
	return dict

func get_full_description() -> String:
	"""Get description with affix effects"""
	var full_desc = description
	
	if applied_affixes.size() > 0:
		full_desc += "\n\n[color=cyan]Affixes:[/color]"
		for affix in applied_affixes:
			full_desc += "\n• " + affix.get_description()
	
	return full_desc

# ============================================================================
# AFFIX GENERATION
# ============================================================================

func roll_affixes():
	"""Roll random affixes based on rarity"""
	applied_affixes.clear()
	
	var num_affixes = get_affix_count_for_rarity()
	if num_affixes == 0:
		return
	
	var available_affixes = AffixPool.get_affixes_for_slot(equip_slot)
	if available_affixes.size() == 0:
		print("⚠️ No affixes available for slot: %s" % get_slot_name())
		return
	
	# Roll affixes
	for i in range(num_affixes):
		if available_affixes.size() == 0:
			break
		
		var affix = available_affixes.pick_random()
		applied_affixes.append(affix.copy())
		
		# Remove from pool to prevent duplicates
		available_affixes.erase(affix)
	
	print("✨ Rolled %d affixes for %s: %s" % [
		applied_affixes.size(),
		item_name,
		get_display_name()
	])

func get_affix_count_for_rarity() -> int:
	"""Get number of affixes based on rarity"""
	match rarity:
		Rarity.COMMON: return 0
		Rarity.UNCOMMON: return 1
		Rarity.RARE: return 2
		Rarity.EPIC: return 3
		Rarity.LEGENDARY: return 4  # 3 + unique
		_: return 0
