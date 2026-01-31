# affix_pool.gd - Automatically loads all affix .tres files from directories
extends Node

# Affix pools by slot type
var head_affixes: Array[Affix] = []
var torso_affixes: Array[Affix] = []
var gloves_affixes: Array[Affix] = []
var boots_affixes: Array[Affix] = []
var weapon_affixes: Array[Affix] = []
var accessory_affixes: Array[Affix] = []

# Master lookup - all affixes by name for dynamic access
var affixes_by_name: Dictionary = {}

func _ready():
	print("✨ Affix Pool initializing...")
	_load_all_affixes()
	print("✨ Affix Pool ready - loaded %d total affixes" % affixes_by_name.size())

func _load_all_affixes():
	"""Automatically load all .tres affixes from directory structure"""
	_load_affixes_from_directory("res://resources/affixes/head/", head_affixes, "Head")
	_load_affixes_from_directory("res://resources/affixes/torso/", torso_affixes, "Torso")
	_load_affixes_from_directory("res://resources/affixes/gloves/", gloves_affixes, "Gloves")
	_load_affixes_from_directory("res://resources/affixes/boots/", boots_affixes, "Boots")
	_load_affixes_from_directory("res://resources/affixes/weapons/", weapon_affixes, "Weapons")
	_load_affixes_from_directory("res://resources/affixes/accessories/", accessory_affixes, "Accessories")

func _load_affixes_from_directory(dir_path: String, target_array: Array[Affix], category_name: String):
	"""Load all .tres affix files from a directory
	
	Args:
		dir_path: Path to directory containing affix .tres files
		target_array: Array to populate with loaded affixes
		category_name: Name for logging (e.g., "Weapons")
	"""
	var dir = DirAccess.open(dir_path)
	
	if not dir:
		print("  ⚠️  Directory not found: %s" % dir_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var loaded_count = 0
	
	while file_name != "":
		# Only process .tres files
		if file_name.ends_with(".tres"):
			var full_path = dir_path + file_name
			var affix = load(full_path)
			
			if affix and affix is Affix:
				target_array.append(affix)
				affixes_by_name[affix.affix_name] = affix
				loaded_count += 1
				print("    ✓ %s: %s" % [category_name, affix.affix_name])
			else:
				print("    ✗ Failed to load or not an Affix: %s" % file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if loaded_count > 0:
		print("  📦 %s affixes: %d loaded" % [category_name, loaded_count])

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

func get_affixes_for_slot(slot: EquippableItem.EquipSlot) -> Array[Affix]:
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

func get_affix_by_name(affix_name: String) -> Affix:
	"""Get a specific affix by name for dynamic access
	
	Returns:
		Affix resource if found, null otherwise
	"""
	return affixes_by_name.get(affix_name, null)

func has_affix(affix_name: String) -> bool:
	"""Check if an affix exists in the pool"""
	return affixes_by_name.has(affix_name)

func get_all_affixes() -> Array[Affix]:
	"""Get all loaded affixes (for debugging/tools)"""
	var all_affixes: Array[Affix] = []
	all_affixes.append_array(head_affixes)
	all_affixes.append_array(torso_affixes)
	all_affixes.append_array(gloves_affixes)
	all_affixes.append_array(boots_affixes)
	all_affixes.append_array(weapon_affixes)
	all_affixes.append_array(accessory_affixes)
	return all_affixes

func get_affixes_by_category(category: String) -> Array[Affix]:
	"""Get all affixes that have a specific category tag
	
	Example: get_affixes_by_category("damage_bonus")
	"""
	var result: Array[Affix] = []
	
	for affix in affixes_by_name.values():
		if affix.has_category(category):
			result.append(affix)
	
	return result

func print_all_affixes():
	"""Debug: Print all loaded affixes"""
	print("=== All Loaded Affixes ===")
	for affix_name in affixes_by_name:
		var affix = affixes_by_name[affix_name]
		print("  %s: %s (categories: %s)" % [affix_name, affix.description, affix.categories])
