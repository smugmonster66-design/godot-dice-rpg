# affix_pool.gd - Global pool of available affixes
extends Node

# Affix pools by slot type
var head_affixes: Array[ItemAffix] = []
var torso_affixes: Array[ItemAffix] = []
var gloves_affixes: Array[ItemAffix] = []
var boots_affixes: Array[ItemAffix] = []
var weapon_affixes: Array[ItemAffix] = []  # Main Hand, Off Hand, Heavy
var accessory_affixes: Array[ItemAffix] = []

func _ready():
	print("✨ Affix Pool initializing...")
	setup_affixes()
	print("✨ Affix Pool ready")

func setup_affixes():
	"""Create all available affixes"""
	setup_head_affixes()
	setup_torso_affixes()
	setup_gloves_affixes()
	setup_boots_affixes()
	setup_weapon_affixes()
	setup_accessory_affixes()

# ============================================================================
# HEAD AFFIXES
# ============================================================================

func setup_head_affixes():
	"""Affixes for helmets/hats"""
	var intelligent = ItemAffix.new()
	intelligent.display_name = "Wise"
	intelligent.is_prefix = true
	intelligent.description = "+3 Intellect"
	intelligent.stat_bonuses = {"intellect": 3}
	head_affixes.append(intelligent)
	
	var fortified = ItemAffix.new()
	fortified.display_name = "Protection"
	fortified.is_prefix = false
	fortified.description = "+5 Armor"
	fortified.stat_bonuses = {"armor": 5}
	head_affixes.append(fortified)

# ============================================================================
# TORSO AFFIXES
# ============================================================================

func setup_torso_affixes():
	"""Affixes for chest armor"""
	var sturdy = ItemAffix.new()
	sturdy.display_name = "Sturdy"
	sturdy.is_prefix = true
	sturdy.description = "+8 Armor"
	sturdy.stat_bonuses = {"armor": 8}
	torso_affixes.append(sturdy)
	
	var vitality = ItemAffix.new()
	vitality.display_name = "Vitality"
	vitality.is_prefix = false
	vitality.description = "+20 Max HP"
	vitality.stat_bonuses = {"max_hp": 20}
	torso_affixes.append(vitality)

# ============================================================================
# GLOVES AFFIXES
# ============================================================================

func setup_gloves_affixes():
	"""Affixes for gloves"""
	var nimble = ItemAffix.new()
	nimble.display_name = "Nimble"
	nimble.is_prefix = true
	nimble.description = "+3 Agility"
	nimble.stat_bonuses = {"agility": 3}
	gloves_affixes.append(nimble)
	
	var striking = ItemAffix.new()
	striking.display_name = "Striking"
	striking.is_prefix = false
	striking.description = "+2 Strength"
	striking.stat_bonuses = {"strength": 2}
	gloves_affixes.append(striking)

# ============================================================================
# BOOTS AFFIXES
# ============================================================================

func setup_boots_affixes():
	"""Affixes for boots"""
	var swift = ItemAffix.new()
	swift.display_name = "Swift"
	swift.is_prefix = true
	swift.description = "+4 Agility"
	swift.stat_bonuses = {"agility": 4}
	boots_affixes.append(swift)
	
	var the_traveler = ItemAffix.new()
	the_traveler.display_name = "the Traveler"
	the_traveler.is_prefix = false
	the_traveler.description = "+2 Luck"
	the_traveler.stat_bonuses = {"luck": 2}
	boots_affixes.append(the_traveler)

# ============================================================================
# WEAPON AFFIXES
# ============================================================================

func setup_weapon_affixes():
	"""Affixes for weapons (Main Hand, Off Hand, Heavy)"""
	var sharp = ItemAffix.new()
	sharp.display_name = "Sharp"
	sharp.is_prefix = true
	sharp.description = "+2 Slashing Damage"
	sharp.base_damage_bonus = 2
	weapon_affixes.append(sharp)
	
	var power = ItemAffix.new()
	power.display_name = "Power"
	power.is_prefix = false
	power.description = "+3 Strength"
	power.stat_bonuses = {"strength": 3}
	weapon_affixes.append(power)
	
	var crushing = ItemAffix.new()
	crushing.display_name = "Crushing"
	crushing.is_prefix = true
	crushing.description = "1.2x Damage Multiplier"
	crushing.damage_multiplier = 1.2
	weapon_affixes.append(crushing)

# ============================================================================
# ACCESSORY AFFIXES
# ============================================================================

func setup_accessory_affixes():
	"""Affixes for accessories/rings"""
	var lucky = ItemAffix.new()
	lucky.display_name = "Lucky"
	lucky.is_prefix = true
	lucky.description = "+5 Luck"
	lucky.stat_bonuses = {"luck": 5}
	accessory_affixes.append(lucky)
	
	var the_archmage = ItemAffix.new()
	the_archmage.display_name = "the Archmage"
	the_archmage.is_prefix = false
	the_archmage.description = "+4 Intellect, +10 Max Mana"
	the_archmage.stat_bonuses = {"intellect": 4, "max_mana": 10}
	accessory_affixes.append(the_archmage)

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

func get_affixes_for_slot(slot: EquippableItem.EquipSlot) -> Array[ItemAffix]:
	"""Get available affixes for equipment slot"""
	match slot:
		EquippableItem.EquipSlot.HEAD:
			return head_affixes
		EquippableItem.EquipSlot.TORSO:
			return torso_affixes
		EquippableItem.EquipSlot.GLOVES:
			return gloves_affixes
		EquippableItem.EquipSlot.BOOTS:
			return boots_affixes
		EquippableItem.EquipSlot.MAIN_HAND, EquippableItem.EquipSlot.OFF_HAND, EquippableItem.EquipSlot.HEAVY:
			return weapon_affixes
		EquippableItem.EquipSlot.ACCESSORY:
			return accessory_affixes
		_:
			return []
