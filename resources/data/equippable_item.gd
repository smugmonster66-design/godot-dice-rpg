# equippable_item.gd - Equipment that grants affixes from pools
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
# Items have their own affix pools based on slot
# These are populated when the item is created/rolled
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
		EquipSlot.HEAVY: return "Main Hand"  # Heavy weapons go in main hand
		EquipSlot.ACCESSORY: return "Accessory"
		_: return "Unknown"

# ============================================================================
# AFFIX MANAGEMENT
# ============================================================================

func roll_affixes(affix_pool: AffixPoolAutoload):
	"""Roll random affixes from the global pool for this item's slot
	
	Args:
		affix_pool: Reference to the global affix pool autoload
	"""
	item_affixes.clear()
	
	var num_affixes = get_affix_count_for_rarity()
	if num_affixes == 0:
		return
	
	var available_affixes = affix_pool.get_affixes_for_slot(equip_slot)
	if available_affixes.size() == 0:
		print("⚠️ No affixes available for slot: %s" % get_slot_name())
		return
	
	# Roll affixes
	for i in range(num_affixes):
		if available_affixes.size() == 0:
			break
		
		var affix = available_affixes.pick_random()
		# Create copy with item as source
		var affix_copy = affix.duplicate_with_source(item_name, "item")
		item_affixes.append(affix_copy)
		
		# Remove from available pool to prevent duplicates
		available_affixes.erase(affix)
	
	print("✨ Rolled %d affixes for %s" % [item_affixes.size(), item_name])

func get_affix_count_for_rarity() -> int:
	"""Get number of affixes based on rarity"""
	match rarity:
		Rarity.COMMON: return 0
		Rarity.UNCOMMON: return 1
		Rarity.RARE: return 2
		Rarity.EPIC: return 3
		Rarity.LEGENDARY: return 4
		_: return 0

func get_all_affixes() -> Array[Affix]:
	"""Get all affixes this item grants"""
	return item_affixes.duplicate()

# ============================================================================
# CONVERSION FOR UI/INVENTORY
# ============================================================================

func to_dict() -> Dictionary:
	"""Convert to Dictionary for UI compatibility"""
	var dict = {
		"name": item_name,
		"display_name": item_name,  # No longer changes with affixes
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
