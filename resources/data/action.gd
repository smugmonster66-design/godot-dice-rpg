# action.gd - Resource representing a combat action
extends Resource
class_name Action

# ============================================================================
# ENUMS
# ============================================================================
enum ActionCategory {
	ITEM,
	SKILL
}

enum ActionType {
	ATTACK,
	DEFEND,
	HEAL,
	SPECIAL
}

# ============================================================================
# BASIC DATA
# ============================================================================
@export var action_name: String = "Action"
@export_multiline var action_description: String = "Does something."
@export var action_icon: Texture2D = null
@export var action_category: ActionCategory = ActionCategory.ITEM
@export var action_type: ActionType = ActionType.ATTACK

# ============================================================================
# DICE REQUIREMENTS
# ============================================================================
@export_group("Dice")
@export var die_slots: int = 1
@export var required_die_tags: Array[String] = []
@export var restricted_die_tags: Array[String] = []

# ============================================================================
# DAMAGE FORMULA
# ============================================================================
@export_group("Damage")
@export var base_damage: int = 0
@export var damage_multiplier: float = 1.0

# ============================================================================
# SOURCE TRACKING
# ============================================================================
var source_name: String = ""  # Set at runtime (e.g., "Iron Sword")

# ============================================================================
# UTILITY
# ============================================================================

func get_formula_text() -> String:
	"""Get human-readable formula like '1D+5' or '2D'"""
	if base_damage == 0 and damage_multiplier == 1.0:
		return "D"
	elif base_damage > 0 and damage_multiplier == 1.0:
		return "D+%d" % base_damage
	elif base_damage == 0:
		return "%.1fD" % damage_multiplier
	else:
		return "%.1fD+%d" % [damage_multiplier, base_damage]

func to_dict() -> Dictionary:
	"""Convert to dictionary for compatibility"""
	return {
		"name": action_name,
		"description": action_description,
		"icon": action_icon,
		"category": action_category,
		"action_type": action_type,
		"die_slots": die_slots,
		"required_tags": required_die_tags,
		"restricted_tags": restricted_die_tags,
		"base_damage": base_damage,
		"damage_multiplier": damage_multiplier,
		"source": source_name
	}
