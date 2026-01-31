# equippable_item.gd - Equipment with manual or random affix assignment
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
	HEAVY,  # Two-handed weapons
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
# AFFIX SYSTEM
# ============================================================================
@export_group("Affixes")

# Manual affix assignment (optional - overrides random rolling)
# Leave these empty to use random rolling instead
@export var manual_first_affix: Affix = null
@export var manual_second_affix: Affix = null
@export var manual_third_affix: Affix = null

# Runtime affixes (populated either manually or by rolling)
var item_affixes: Array[Affix] = []

# ============================================================================
# DICE
# ============================================================================
@export_group("Dice")
@export var grants_dice: Array[DieData.DieType] = []
@export var dice_tags: Array[String] = []

# ============================================================================
# COMBAT ACTION
# ============================================================================
@export_group("Combat Action")
@export var grants_action: bool = false
@export var action: Action = null

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
		EquipSlot.HEAVY: return "Main Hand"
		EquipSlot.ACCESSORY: return "Accessory"
		_: return "Unknown"

# ============================================================================
# AFFIX MANAGEMENT
# ============================================================================

func initialize_affixes(affix_pool):
	"""Initialize affixes - use manual if set, otherwise roll randomly
	
	Call this when creating an item instance (e.g., in GameManager)
	"""
	item_affixes.clear()
	
	# Check if manual affixes are set
	if manual_first_affix or manual_second_affix or manual_third_affix:
		_use_manual_affixes()
	else:
		_roll_random_affixes(affix_pool)

func _use_manual_affixes():
	"""Use manually assigned affixes from Inspector"""
	if manual_first_affix:
		var copy = manual_first_affix.duplicate_with_source(item_name, "item")
		item_affixes.append(copy)
		print("  ✓ Using manual affix 1: %s" % manual_first_affix.affix_name)
	
	if manual_second_affix:
		var copy = manual_second_affix.duplicate_with_source(item_name, "item")
		item_affixes.append(copy)
		print("  ✓ Using manual affix 2: %s" % manual_second_affix.affix_name)
	
	if manual_third_affix:
		var copy = manual_third_affix.duplicate_with_source(item_name, "item")
		item_affixes.append(copy)
		print("  ✓ Using manual affix 3: %s" % manual_third_affix.affix_name)

func _roll_random_affixes(affix_pool):
	"""Roll random affixes from the three-tier pools
	
	Rarity determines which pools to roll from:
	- COMMON: No affixes
	- UNCOMMON: Roll 1 from First pool
	- RARE: Roll 1 from First, 1 from Second
	- EPIC: Roll 1 from First, 1 from Second, 1 from Third
	- LEGENDARY: Roll 1 from each pool (all three)
	"""
	var num_affixes = get_affix_count_for_rarity()
	
	if num_affixes >= 1:
		_roll_from_pool(affix_pool, 1, "First")
	
	if num_affixes >= 2:
		_roll_from_pool(affix_pool, 2, "Second")
	
	if num_affixes >= 3:
		_roll_from_pool(affix_pool, 3, "Third")
	
	print("✨ Rolled %d affixes for %s" % [item_affixes.size(), item_name])

func _roll_from_pool(affix_pool, tier: int, tier_name: String):
	"""Roll one affix from a specific tier pool"""
	var pool = affix_pool.get_affix_pool(equip_slot, tier)
	
	if pool.size() == 0:
		print("  ⚠️ No affixes in %s pool for %s" % [tier_name, get_slot_name()])
		return
	
	var affix = pool.pick_random()
	var affix_copy = affix.duplicate_with_source(item_name, "item")
	item_affixes.append(affix_copy)
	print("  🎲 Rolled %s affix: %s" % [tier_name, affix.affix_name])

func get_affix_count_for_rarity() -> int:
	"""Get number of affixes to roll based on rarity"""
	match rarity:
		Rarity.COMMON: return 0
		Rarity.UNCOMMON: return 1
		Rarity.RARE: return 2
		Rarity.EPIC: return 3
		Rarity.LEGENDARY: return 3  # Still 3, just better pools
		_: return 0

func get_all_affixes() -> Array[Affix]:
	"""Get all affixes this item grants"""
	return item_affixes.duplicate()

# ============================================================================
# BACKWARD COMPATIBILITY
# ============================================================================

func roll_affixes(affix_pool):
	"""Legacy function - calls initialize_affixes for compatibility"""
	initialize_affixes(affix_pool)

# ============================================================================
# CONVERSION FOR UI/INVENTORY
# ============================================================================

func to_dict() -> Dictionary:
	"""Convert to Dictionary for UI compatibility"""
	var dict = {
		"name": item_name,
		"display_name": item_name,
		"slot": get_slot_name(),
		"description": description,
		"dice": grants_dice.duplicate(),
		"dice_tags": dice_tags.duplicate(),
		"is_heavy": is_heavy_weapon(),
		"icon": icon,
		"rarity": get_rarity_name()
	}
	
	# Add affixes as dictionaries for UI display
	var affixes_data = []
	for affix in item_affixes:
		affixes_data.append({
			"name": affix.affix_name,
			"display_name": affix.affix_name,
			"description": affix.description,
			"categories": affix.categories
		})
	
	if affixes_data.size() > 0:
		dict["affixes"] = affixes_data
	
	# Add action if granted
	if grants_action and action:
		dict["actions"] = [action.to_dict()]
	
	return dict
