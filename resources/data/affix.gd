# affix.gd - Standalone affix resource with category-based effects
extends Resource
class_name Affix

# ============================================================================
# BASIC DATA
# ============================================================================
@export var affix_name: String = "New Affix"
@export_multiline var description: String = "An affix effect"
@export var icon: Texture2D = null

# ============================================================================
# CATEGORIZATION
# ============================================================================
# Affixes can have multiple category tags
# Categories determine when/how the affix is applied
@export var categories: Array[String] = []

# Valid categories:
# - strength_bonus, agility_bonus, intellect_bonus, luck_bonus
# - strength_multiplier, agility_multiplier, intellect_multiplier, luck_multiplier
# - damage_bonus, damage_multiplier
# - defense_bonus, defense_multiplier
# - elemental, misc, skill, new_action, per_turn, dice

# ============================================================================
# SOURCE TRACKING
# ============================================================================
# Tracks where this affix came from (for removal)
var source: String = ""  # e.g., "Iron Sword", "Warrior - Power Strike Rank 2"
var source_type: String = ""  # e.g., "item", "skill", "consumable", "buff"

# ============================================================================
# EFFECT DATA
# ============================================================================
# The value/data used by the effect function
@export var effect_value: Variant = null

# Examples:
# - For stat bonus: effect_value = 5 (adds 5 to stat)
# - For multiplier: effect_value = 1.2 (multiplies by 1.2)
# - For new action: effect_value = Action resource
# - For dice: effect_value = [6, 6] (grants 2d6)

# ============================================================================
# EFFECT APPLICATION
# ============================================================================

func apply_effect() -> Variant:
	"""Apply this affix's effect and return the result
	
	The return value depends on the category:
	- Bonuses/Multipliers: returns number to add/multiply
	- Actions: returns Action resource
	- Dice: returns Array of die values
	"""
	return effect_value

func can_stack_with(other_affix: Affix) -> bool:
	"""Check if this affix can stack with another
	
	By default, affixes with the same name from different sources stack
	Override this for special stacking rules
	"""
	if affix_name != other_affix.affix_name:
		return true  # Different affixes always stack
	
	# Same affix name - check if sources are different
	return source != other_affix.source

# ============================================================================
# UTILITY
# ============================================================================

func duplicate_with_source(p_source: String, p_source_type: String) -> Affix:
	"""Create a copy of this affix with a specific source"""
	var copy = duplicate(true)
	copy.source = p_source
	copy.source_type = p_source_type
	return copy

func matches_source(p_source: String) -> bool:
	"""Check if this affix came from a specific source"""
	return source == p_source

func has_category(category: String) -> bool:
	"""Check if this affix has a specific category tag"""
	return category in categories

func get_display_text() -> String:
	"""Get formatted display text for UI"""
	var text = affix_name
	if source:
		text += " (from %s)" % source
	return text
