# die_data.gd - Die data resource
extends Resource
class_name DieData

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
# PROPERTIES
# ============================================================================
var die_type: DieType = DieType.D6
var current_value: int = 1
var source: String = ""
var tags: Array[String] = []
var is_locked: bool = false
var modifier: int = 0

# Visual
var color: Color = Color.WHITE
var icon: Texture2D = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(type: DieType = DieType.D6, src: String = ""):
	die_type = type
	source = src
	roll()

# ============================================================================
# CORE FUNCTIONS
# ============================================================================

func roll() -> int:
	"""Roll this die"""
	current_value = randi_range(1, die_type)
	return get_total_value()

func get_total_value() -> int:
	"""Get value with modifiers"""
	return current_value + modifier

func has_tag(tag: String) -> bool:
	"""Check if has tag"""
	return tag in tags

func add_tag(tag: String):
	"""Add tag"""
	if not has_tag(tag):
		tags.append(tag)

func remove_tag(tag: String):
	"""Remove tag"""
	tags.erase(tag)

func get_display_name() -> String:
	"""Get readable name"""
	var name = "D%d" % die_type
	if modifier > 0:
		name += "+%d" % modifier
	elif modifier < 0:
		name += "%d" % modifier
	if tags.size() > 0:
		name += " [%s]" % ", ".join(tags)
	return name

# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dict() -> Dictionary:
	"""Serialize"""
	return {
		"die_type": die_type,
		"current_value": current_value,
		"source": source,
		"tags": tags,
		"is_locked": is_locked,
		"modifier": modifier,
		"color": color.to_html()
	}

static func from_dict(data: Dictionary) -> DieData:
	"""Deserialize"""
	var die = DieData.new(data.get("die_type", DieType.D6), data.get("source", ""))
	die.current_value = data.get("current_value", 1)
	die.tags = data.get("tags", [])
	die.is_locked = data.get("is_locked", false)
	die.modifier = data.get("modifier", 0)
	die.color = Color.from_string(data.get("color", "#ffffff"), Color.WHITE)
	return die
