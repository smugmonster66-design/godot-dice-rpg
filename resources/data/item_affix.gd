# item_affix.gd - Affix that can roll on items
extends Resource
class_name ItemAffix

# ============================================================================
# BASIC DATA
# ============================================================================
@export var display_name: String = "Affix"
@export var is_prefix: bool = true  # If false, it's a suffix ("of Power")
@export_multiline var description: String = "An affix effect"

# ============================================================================
# STAT BONUSES
# ============================================================================
@export_group("Stat Bonuses")
@export var stat_bonuses: Dictionary = {}  # e.g., {"strength": 3, "armor": 5}

# ============================================================================
# COMBAT MODIFIERS
# ============================================================================
@export_group("Combat Modifiers")
@export var base_damage_bonus: int = 0
@export var damage_multiplier: float = 1.0

# ============================================================================
# ACTION GRANTING
# ============================================================================
@export_group("Grants Action")
@export var grants_action: bool = false
@export var action_name: String = ""
@export_multiline var action_description: String = ""
@export var action_icon: Texture2D = null
@export var die_slots: int = 1
@export var action_type: ActionField.ActionType = ActionField.ActionType.ATTACK
@export var action_base_damage: int = 0
@export var action_damage_multiplier: float = 1.0
@export var action_required_tags: Array[String] = []
@export var action_restricted_tags: Array[String] = []

# ============================================================================
# UTILITY
# ============================================================================

func get_description() -> String:
	"""Get formatted description of effects"""
	return description

func get_action_data() -> Dictionary:
	"""Get action data if this affix grants an action"""
	if not grants_action:
		return {}
	
	return {
		"name": action_name,
		"description": action_description,
		"icon": action_icon,
		"die_slots": die_slots,
		"action_type": action_type,
		"base_damage": action_base_damage,
		"damage_multiplier": action_damage_multiplier,
		"required_tags": action_required_tags,
		"restricted_tags": action_restricted_tags,
		"category": ActionField.ActionCategory.ITEM
	}

func copy() -> ItemAffix:
	"""Create a copy of this affix"""
	var affix_copy = ItemAffix.new()
	affix_copy.display_name = display_name
	affix_copy.is_prefix = is_prefix
	affix_copy.description = description
	affix_copy.stat_bonuses = stat_bonuses.duplicate()
	affix_copy.base_damage_bonus = base_damage_bonus
	affix_copy.damage_multiplier = damage_multiplier
	affix_copy.grants_action = grants_action
	affix_copy.action_name = action_name
	affix_copy.action_description = action_description
	affix_copy.action_icon = action_icon
	affix_copy.die_slots = die_slots
	affix_copy.action_type = action_type
	affix_copy.action_base_damage = action_base_damage
	affix_copy.action_damage_multiplier = action_damage_multiplier
	affix_copy.action_required_tags = action_required_tags.duplicate()
	affix_copy.action_restricted_tags = action_restricted_tags.duplicate()
	return affix_copy
