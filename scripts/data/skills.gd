# skill.gd - Individual Skill in a skill tree
extends Resource
class_name Skill

var skill_name: String = ""
var description: String = ""
var current_rank: int = 0
var max_rank: int = 1
var tier: int = 1  # Used for visual positioning in tree

# Requirements to learn this skill
# Array of {skill_name: String, required_rank: int}
var requirements: Array = []

# Skill effects - what this skill does
# This is flexible to support different skill types
var effects: Dictionary = {
	# Examples:
	# "stat_bonus": {"strength": 5},  # Passive stat increase
	# "damage_bonus": 10,  # Increases damage by flat amount
	# "damage_percent": 15,  # Increases damage by percentage
	# "unlock_action": "PowerStrike",  # Unlocks a combat action
	# "mana_cost_reduction": 5,  # Reduces mana costs
	# etc.
}

# Cost to learn each rank
var skill_point_cost: int = 1

func _init(p_name: String = "", p_description: String = "", p_max_rank: int = 1, p_tier: int = 1):
	skill_name = p_name
	description = p_description
	max_rank = p_max_rank
	tier = p_tier
	current_rank = 0
	requirements = []
	effects = {}
	skill_point_cost = 1

func add_requirement(required_skill_name: String, required_rank: int = 1) -> Skill:
	"""Fluent interface for adding requirements"""
	requirements.append({
		"skill_name": required_skill_name,
		"required_rank": required_rank
	})
	return self

func set_effects(p_effects: Dictionary) -> Skill:
	"""Fluent interface for setting effects"""
	effects = p_effects
	return self

func set_cost(cost: int) -> Skill:
	"""Fluent interface for setting skill point cost"""
	skill_point_cost = cost
	return self

func can_rank_up() -> bool:
	"""Check if this skill can be ranked up"""
	return current_rank < max_rank

func rank_up() -> bool:
	"""Increase rank by 1 if possible"""
	if can_rank_up():
		current_rank += 1
		return true
	return false

func get_effect_value(effect_name: String):
	"""Get the value of a specific effect, scaled by current rank"""
	if not effects.has(effect_name):
		return null
	
	var base_value = effects[effect_name]
	
	# For stat bonuses, scale by rank
	if typeof(base_value) == TYPE_INT or typeof(base_value) == TYPE_FLOAT:
		return base_value * current_rank
	
	# For dictionaries (like stat_bonus), scale each value
	if typeof(base_value) == TYPE_DICTIONARY:
		var scaled = {}
		for key in base_value:
			scaled[key] = base_value[key] * current_rank
		return scaled
	
	# For other types, return as-is
	return base_value

func reset():
	"""Reset skill to rank 0"""
	current_rank = 0
