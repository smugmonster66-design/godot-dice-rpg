# res://resources/data/die_resource.gd
# Individual die with type, image, and dice affixes
# Updated to support DieObject scenes for combat and pool displays
extends Resource
class_name DieResource

# ============================================================================
# ENUMS
# ============================================================================
enum DieType {
	D4 = 4,
	D6 = 6,
	D8 = 8,
	D10 = 10,
	D12 = 12,
	D20 = 20
}

# ============================================================================
# BASIC PROPERTIES
# ============================================================================
@export var display_name: String = "Die"
@export var die_type: DieType = DieType.D6
@export var color: Color = Color.WHITE

@export_group("Textures")
## Fill texture (drawn first, behind stroke)
@export var fill_texture: Texture2D = null
## Stroke/outline texture (drawn on top of fill)
@export var stroke_texture: Texture2D = null

var icon: Texture2D:
	get:
		return fill_texture
	set(value):
		fill_texture = value

# ============================================================================
# DIE OBJECT SCENES (NEW)
# ============================================================================
@export_group("Die Object Scenes")
## Scene used to display this die in combat (shows rolled value)
## If null, will auto-select based on die_type
@export var combat_die_scene: PackedScene = null
## Scene used to display this die in pool/inventory (shows max value)
## If null, will auto-select based on die_type
@export var pool_die_scene: PackedScene = null

@export var drag_preview_scene: PackedScene = null

# ============================================================================
# DICE AFFIXES
# ============================================================================
@export_group("Dice Affixes")
## Affixes that are always on this die (e.g., a "Flame Die" has fire affixes built-in)
@export var inherent_affixes: Array[DiceAffix] = []

## Runtime affixes added by equipment, blessings, curses, etc.
var applied_affixes: Array[DiceAffix] = []

# ============================================================================
# SIGNALS
# ============================================================================
signal value_modified(old_value: int, new_value: int)

# ============================================================================
# RUNTIME STATE
# ============================================================================
var current_value: int = 1          # Current rolled value (before affixes)
var modified_value: int = 1         # Value after affix modifications
var modifier: int = 0               # Flat modifier from external sources
var source: String = ""             # Where this die came from
var tags: Array[String] = []        # Tags on this die (fire, holy, etc.)
var is_locked: bool = false         # Can't be used this turn
var can_reroll: bool = false        # Can be rerolled
var slot_index: int = 0             # Position in collection (for affixes)

# ============================================================================
# SCENE PATH CONSTANTS
# ============================================================================
const COMBAT_SCENE_PATHS = {
	DieType.D4: "res://scenes/ui/components/dice/combat/combat_die_d4.tscn",
	DieType.D6: "res://scenes/ui/components/dice/combat/combat_die_d6.tscn",
	DieType.D8: "res://scenes/ui/components/dice/combat/combat_die_d8.tscn",
	DieType.D10: "res://scenes/ui/components/dice/combat/combat_die_d10.tscn",
	DieType.D12: "res://scenes/ui/components/dice/combat/combat_die_d12.tscn",
	DieType.D20: "res://scenes/ui/components/dice/combat/combat_die_d20.tscn",
}

const POOL_SCENE_PATHS = {
	DieType.D4: "res://scenes/ui/components/dice/pool/pool_die_d4.tscn",
	DieType.D6: "res://scenes/ui/components/dice/pool/pool_die_d6.tscn",
	DieType.D8: "res://scenes/ui/components/dice/pool/pool_die_d8.tscn",
	DieType.D10: "res://scenes/ui/components/dice/pool/pool_die_d10.tscn",
	DieType.D12: "res://scenes/ui/components/dice/pool/pool_die_d12.tscn",
	DieType.D20: "res://scenes/ui/components/dice/pool/pool_die_d20.tscn",
}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(type: DieType = DieType.D6, p_source: String = ""):
	die_type = type
	source = p_source
	display_name = "D%d" % type

# ============================================================================
# DIE OBJECT INSTANTIATION (NEW)
# ============================================================================

func instantiate_combat_visual():
	"""Create a CombatDieObject for use in combat hand/action fields"""
	print("🎲 DieResource.instantiate_combat_visual() for %s (type=%d)" % [display_name, die_type])
	var scene = _get_combat_scene()
	if not scene:
		push_warning("DieResource: No combat scene for %s" % display_name)
		return null
	
	print("  ✅ Scene loaded, instantiating...")
	var obj = scene.instantiate()
	if obj and obj.has_method("setup"):
		print("  ✅ Instantiated, calling setup...")
		obj.setup(self)
	else:
		print("  ❌ Failed to instantiate or no setup method")
	return obj

func instantiate_pool_visual():
	"""Create a PoolDieObject for use in map pool/inventory"""
	var scene = _get_pool_scene()
	if not scene:
		push_warning("DieResource: No pool scene for %s" % display_name)
		return null
	
	var obj = scene.instantiate()
	if obj and obj.has_method("setup"):
		obj.setup(self)
	return obj

func _get_combat_scene() -> PackedScene:
	"""Get the combat scene, using explicit or auto-selected"""
	if combat_die_scene:
		print("  Using explicit combat_die_scene")
		return combat_die_scene
	
	# Auto-select based on die type
	var path = COMBAT_SCENE_PATHS.get(die_type, "")
	print("  Looking for scene at: %s" % path)
	
	if path and ResourceLoader.exists(path):
		print("  ✅ Scene exists, loading...")
		return load(path)
	else:
		print("  ❌ Scene does NOT exist at path: %s" % path)
	
	return null

func _get_pool_scene() -> PackedScene:
	"""Get the pool scene, using explicit or auto-selected"""
	if pool_die_scene:
		return pool_die_scene
	
	# Auto-select based on die type
	var path = POOL_SCENE_PATHS.get(die_type, "")
	if path and ResourceLoader.exists(path):
		return load(path)
	
	return null

# ============================================================================
# ROLLING
# ============================================================================

func roll() -> int:
	"""Roll the die and return the result"""
	current_value = randi_range(1, die_type)
	modified_value = current_value
	return current_value

func get_total_value() -> int:
	"""Get final value including modifiers"""
	return modified_value + modifier

func get_max_value() -> int:
	"""Get maximum possible roll value"""
	return die_type

func get_base_value() -> int:
	"""Get the raw rolled value before modifications"""
	return current_value

func set_modified_value(value: int):
	"""Set the modified value (after affix processing)"""
	modified_value = value

func is_max_roll() -> bool:
	"""Check if current roll is the maximum for this die type"""
	return current_value == die_type

# ============================================================================
# VALUE MODIFICATION (for affix processor)
# ============================================================================

func apply_flat_modifier(amount: float):
	"""Apply a flat modifier to the modified value"""
	var old = modified_value
	modified_value += int(amount)
	modified_value = max(1, modified_value)  # Minimum 1
	if old != modified_value:
		value_modified.emit(old, modified_value)

func apply_percent_modifier(percent: float):
	"""Apply a percentage modifier to the modified value"""
	var old = modified_value
	modified_value = int(modified_value * percent)
	modified_value = max(1, modified_value)  # Minimum 1
	if old != modified_value:
		value_modified.emit(old, modified_value)

func set_minimum_value(minimum: int):
	"""Ensure value is at least this amount"""
	if modified_value < minimum:
		var old = modified_value
		modified_value = minimum
		value_modified.emit(old, modified_value)

func set_maximum_value(maximum: int):
	"""Cap value at this amount"""
	if modified_value > maximum:
		var old = modified_value
		modified_value = maximum
		value_modified.emit(old, modified_value)

func reset_modifications():
	"""Reset modified value to base roll"""
	modified_value = current_value

# ============================================================================
# AFFIXES
# ============================================================================

func add_affix(affix: DiceAffix):
	"""Add a runtime affix"""
	applied_affixes.append(affix)

func remove_affix(affix: DiceAffix):
	"""Remove a runtime affix"""
	applied_affixes.erase(affix)

func clear_applied_affixes():
	"""Remove all runtime affixes"""
	applied_affixes.clear()

func get_all_affixes() -> Array[DiceAffix]:
	"""Get combined inherent and applied affixes"""
	var all: Array[DiceAffix] = []
	all.append_array(inherent_affixes)
	all.append_array(applied_affixes)
	return all

func has_affix_with_effect(effect_type: DiceAffix.EffectType) -> bool:
	"""Check if any affix has a specific effect type"""
	for affix in get_all_affixes():
		if affix.effect_type == effect_type:
			return true
	return false

# ============================================================================
# TAGS
# ============================================================================

func add_tag(tag: String):
	if tag not in tags:
		tags.append(tag)

func remove_tag(tag: String):
	tags.erase(tag)

func has_tag(tag: String) -> bool:
	return tag in tags

func get_tags() -> Array[String]:
	return tags

# ============================================================================
# DISPLAY
# ============================================================================

func get_display_name() -> String:
	if display_name and display_name != "Die":
		return display_name
	return "D%d" % die_type

func get_type_string() -> String:
	return "D%d" % die_type

func get_affix_summary() -> String:
	"""Get a summary of all affixes for tooltip"""
	var all_affixes = get_all_affixes()
	if all_affixes.size() == 0:
		return ""
	
	var lines: Array[String] = []
	for affix in all_affixes:
		lines.append("• " + affix.get_formatted_description())
	return "\n".join(lines)

# ============================================================================
# DUPLICATION
# ============================================================================

func duplicate_die() -> DieResource:
	"""Create a deep copy of this die"""
	var copy = DieResource.new(die_type, source)
	copy.display_name = display_name
	copy.fill_texture = fill_texture
	copy.stroke_texture = stroke_texture
	copy.color = color
	copy.combat_die_scene = combat_die_scene
	copy.pool_die_scene = pool_die_scene
	copy.current_value = current_value
	copy.modified_value = modified_value
	copy.modifier = modifier
	copy.tags = tags.duplicate()
	copy.is_locked = is_locked
	copy.can_reroll = can_reroll
	
	# Deep copy inherent affixes
	for affix in inherent_affixes:
		copy.inherent_affixes.append(affix.duplicate(true))
	
	# Deep copy applied affixes
	for affix in applied_affixes:
		copy.applied_affixes.append(affix.duplicate(true))
	
	return copy

# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dict() -> Dictionary:
	"""Serialize die to dictionary"""
	var inherent_data: Array[Dictionary] = []
	for affix in inherent_affixes:
		inherent_data.append(affix.to_dict())
	
	var applied_data: Array[Dictionary] = []
	for affix in applied_affixes:
		applied_data.append(affix.to_dict())
	
	return {
		"display_name": display_name,
		"die_type": die_type,
		"color": color.to_html(),
		"current_value": current_value,
		"modified_value": modified_value,
		"modifier": modifier,
		"source": source,
		"tags": tags,
		"is_locked": is_locked,
		"can_reroll": can_reroll,
		"inherent_affixes": inherent_data,
		"applied_affixes": applied_data,
	}

static func from_dict(data: Dictionary) -> DieResource:
	"""Deserialize die from dictionary"""
	var die = DieResource.new(data.get("die_type", DieType.D6), data.get("source", ""))
	die.display_name = data.get("display_name", "Die")
	die.color = Color.from_string(data.get("color", "#ffffff"), Color.WHITE)
	die.current_value = data.get("current_value", 1)
	die.modified_value = data.get("modified_value", 1)
	die.modifier = data.get("modifier", 0)
	die.tags = data.get("tags", [])
	die.is_locked = data.get("is_locked", false)
	die.can_reroll = data.get("can_reroll", false)
	
	# Deserialize affixes
	for affix_data in data.get("inherent_affixes", []):
		die.inherent_affixes.append(DiceAffix.from_dict(affix_data))
	
	for affix_data in data.get("applied_affixes", []):
		die.applied_affixes.append(DiceAffix.from_dict(affix_data))
	
	return die

# ============================================================================
# COMPATIBILITY WITH OLD DieData
# ============================================================================

static func from_die_data(die_data) -> DieResource:
	"""Convert old DieData to new DieResource"""
	var die = DieResource.new(die_data.die_type, die_data.source)
	die.current_value = die_data.current_value
	die.modified_value = die_data.current_value
	die.modifier = die_data.modifier
	die.tags = die_data.tags.duplicate() if die_data.tags else []
	die.is_locked = die_data.is_locked
	die.color = die_data.color
	die.icon = die_data.icon
	return die
