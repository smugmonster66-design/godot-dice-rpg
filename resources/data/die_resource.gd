# die_resource.gd - Individual die with type, image, and dice affixes
# This replaces/enhances DieData with proper resource-based design
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
# DICE AFFIXES
# ============================================================================
@export_group("Dice Affixes")
## Affixes that are always on this die (e.g., a "Flame Die" has fire affixes built-in)
@export var inherent_affixes: Array[DiceAffix] = []

## Runtime affixes added by equipment, blessings, curses, etc.
var applied_affixes: Array[DiceAffix] = []

# ============================================================================
# RUNTIME STATE
# ============================================================================
var current_value: int = 1          # Current rolled value (before affixes)
var modified_value: int = 1         # Value after affix modifications
var modifier: int = 0               # Flat modifier from external sources
var source: String = ""             # Where this die came from
var tags: Array[String] = []        # Tags on this die (fire, holy, etc.)
var is_locked: bool = false         # Can't be consumed/moved
var can_reroll: bool = false        # Has a reroll available
var slot_index: int = -1            # Current position in dice collection

# ============================================================================
# SIGNALS
# ============================================================================
signal rolled(value: int)
signal value_modified(old_value: int, new_value: int)
signal tag_added(tag: String)
signal tag_removed(tag: String)
signal affix_triggered(affix: DiceAffix)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(type: DieType = DieType.D6, src: String = ""):
	die_type = type
	source = src
	display_name = "D%d" % type

# ============================================================================
# ROLLING
# ============================================================================

func roll() -> int:
	"""Roll this die and return base value (before affix modifications)"""
	current_value = randi_range(1, die_type)
	modified_value = current_value
	can_reroll = false  # Reset reroll on new roll
	
	rolled.emit(current_value)
	return current_value

func get_base_value() -> int:
	"""Get the base rolled value (no modifiers)"""
	return current_value

func get_total_value() -> int:
	"""Get the final value including all modifications"""
	return modified_value + modifier

func get_max_value() -> int:
	"""Get maximum possible roll for this die type"""
	return die_type

func is_max_roll() -> bool:
	"""Check if this die rolled its maximum value"""
	return current_value == die_type

func is_min_roll() -> bool:
	"""Check if this die rolled 1"""
	return current_value == 1

# ============================================================================
# AFFIX MANAGEMENT
# ============================================================================

func get_all_affixes() -> Array[DiceAffix]:
	"""Get all affixes (inherent + applied)"""
	var all_affixes: Array[DiceAffix] = []
	all_affixes.append_array(inherent_affixes)
	all_affixes.append_array(applied_affixes)
	return all_affixes

func add_affix(affix: DiceAffix):
	"""Add a runtime affix to this die"""
	var copy = affix.duplicate_with_source(affix.source, affix.source_type)
	applied_affixes.append(copy)
	print("  🎲 Added affix '%s' to %s" % [affix.affix_name, display_name])

func remove_affix(affix: DiceAffix):
	"""Remove a specific affix"""
	applied_affixes.erase(affix)

func remove_affixes_by_source(source_name: String):
	"""Remove all affixes from a specific source"""
	var to_remove: Array[DiceAffix] = []
	for affix in applied_affixes:
		if affix.source == source_name:
			to_remove.append(affix)
	for affix in to_remove:
		applied_affixes.erase(affix)

func clear_applied_affixes():
	"""Clear all runtime affixes (keeps inherent ones)"""
	applied_affixes.clear()

func get_affixes_by_trigger(trigger: DiceAffix.Trigger) -> Array[DiceAffix]:
	"""Get all affixes with a specific trigger type"""
	var result: Array[DiceAffix] = []
	for affix in get_all_affixes():
		if affix.trigger == trigger:
			result.append(affix)
	return result

# ============================================================================
# TAG MANAGEMENT
# ============================================================================

func has_tag(tag: String) -> bool:
	"""Check if die has a specific tag"""
	return tag in tags

func add_tag(tag: String):
	"""Add a tag to this die"""
	if not has_tag(tag):
		tags.append(tag)
		tag_added.emit(tag)

func remove_tag(tag: String):
	"""Remove a tag from this die"""
	if has_tag(tag):
		tags.erase(tag)
		tag_removed.emit(tag)

func clear_tags():
	"""Remove all tags"""
	tags.clear()

func get_tags() -> Array[String]:
	"""Get all tags"""
	return tags.duplicate()

# ============================================================================
# VALUE MODIFICATION
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
# DISPLAY
# ============================================================================

func get_display_name() -> String:
	"""Get human-readable die name"""
	var name = display_name if display_name != "Die" else "D%d" % die_type
	
	if modifier > 0:
		name += "+%d" % modifier
	elif modifier < 0:
		name += "%d" % modifier
	
	if tags.size() > 0:
		name += " [%s]" % ", ".join(tags)
	
	return name

func get_type_string() -> String:
	"""Get die type as string (D6, D8, etc.)"""
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
