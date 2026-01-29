# die_data.gd - Data structure for individual dice
extends Resource
class_name DieData

# Die type (number of sides)
enum DieType {
	D4 = 4,
	D6 = 6,
	D8 = 8,
	D10 = 10,
	D12 = 12,
	D20 = 20
}

# Die characteristics/tags
var die_type: DieType = DieType.D6
var current_value: int = 1  # Current rolled value
var source: String = ""  # What granted this die (e.g., "Iron Sword", "Warrior Class")
var tags: Array[String] = []  # Additional properties (e.g., "fire", "critical", "reroll")
var is_locked: bool = false  # Can't be rerolled or consumed
var modifier: int = 0  # +/- to the die result

# Visual properties
var color: Color = Color.WHITE
var icon: Texture2D = null

func _init(type: DieType = DieType.D6, src: String = ""):
	die_type = type
	source = src
	roll()

func roll() -> int:
	"""Roll this die and return the result"""
	current_value = randi_range(1, die_type)
	return get_total_value()

func get_total_value() -> int:
	"""Get the die value including modifiers"""
	return current_value + modifier

func has_tag(tag: String) -> bool:
	"""Check if die has a specific tag"""
	return tag in tags

func add_tag(tag: String):
	"""Add a tag to this die"""
	if not has_tag(tag):
		tags.append(tag)

func remove_tag(tag: String):
	"""Remove a tag from this die"""
	tags.erase(tag)

func duplicate_die() -> DieData:
	"""Create a copy of this die"""
	var copy = DieData.new(die_type, source)
	copy.current_value = current_value
	copy.tags = tags.duplicate()
	copy.is_locked = is_locked
	copy.modifier = modifier
	copy.color = color
	copy.icon = icon
	return copy

func to_dict() -> Dictionary:
	"""Serialize die to dictionary"""
	return {
		"die_type": die_type,
		"current_value": current_value,
		"source": source,
		"tags": tags,
		"is_locked": is_locked,
		"modifier": modifier,
		"color": color.to_html(),
		# icon would need special handling for save/load
	}

static func from_dict(data: Dictionary) -> DieData:
	"""Deserialize die from dictionary"""
	var die = DieData.new(data.get("die_type", DieType.D6), data.get("source", ""))
	die.current_value = data.get("current_value", 1)
	die.tags = data.get("tags", [])
	die.is_locked = data.get("is_locked", false)
	die.modifier = data.get("modifier", 0)
	die.color = Color.from_string(data.get("color", "#ffffff"), Color.WHITE)
	return die

func get_display_name() -> String:
	"""Get human-readable die name"""
	var name = "D%d" % die_type
	if modifier > 0:
		name += "+%d" % modifier
	elif modifier < 0:
		name += "%d" % modifier
	if tags.size() > 0:
		name += " [%s]" % ", ".join(tags)
	return name
