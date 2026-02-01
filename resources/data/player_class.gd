# player_class.gd - Complete Player Class with Skill Tree System
extends Resource
class_name PlayerClass

# ============================================================================
# PROPERTIES
# ============================================================================
@export var player_class_name: String = ""
@export var level: int = 1
@export var experience: int = 0
@export var main_stat: String = "strength"

# Base stat bonuses from class
@export var stat_bonuses: Dictionary = {
	"strength": 0,
	"agility": 0,
	"intellect": 0,
	"armor": 0,
	"barrier": 0
}

# Skill trees - Dictionary of SkillTree objects
var skill_trees: Dictionary = {}

# Track total skill points available and spent
var total_skill_points: int = 0
var spent_skill_points: int = 0

# Combat actions this class can perform
var combat_actions: Array = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_class_name: String = "", p_main_stat: String = "strength"):
	player_class_name = p_class_name
	main_stat = p_main_stat
	level = 1
	experience = 0
	total_skill_points = level
	spent_skill_points = 0
	skill_trees = {}
	combat_actions = []
	stat_bonuses = {
		"strength": 0,
		"agility": 0,
		"intellect": 0,
		"armor": 0,
		"barrier": 0
	}

# ============================================================================
# STAT & LEVEL MANAGEMENT
# ============================================================================

func get_stat_bonus(stat_name: String) -> int:
	"""Get total stat bonus"""
	var total_bonus = 0
	
	# Base class bonuses
	if stat_bonuses.has(stat_name):
		total_bonus += stat_bonuses[stat_name]
	
	# Bonuses from skills
	total_bonus += get_skill_stat_bonus(stat_name)
	
	return total_bonus

func get_skill_stat_bonus(stat_name: String) -> int:
	"""Calculate stat bonuses from all learned skills"""
	var bonus = 0
	
	for tree_name in skill_trees:
		var tree = skill_trees[tree_name]
		for skill in tree.skills:
			if skill.current_rank > 0:
				var stat_bonus_effect = skill.get_effect_value("stat_bonus")
				if stat_bonus_effect and typeof(stat_bonus_effect) == TYPE_DICTIONARY:
					if stat_bonus_effect.has(stat_name):
						bonus += stat_bonus_effect[stat_name]
	
	return bonus

func gain_experience(amount: int):
	"""Gain experience points"""
	experience += amount
	check_level_up()

func check_level_up():
	"""Check if should level up"""
	var exp_needed = get_exp_for_next_level()
	while experience >= exp_needed:
		level += 1
		experience -= exp_needed
		total_skill_points += 1
		on_level_up()
		exp_needed = get_exp_for_next_level()

func get_exp_for_next_level() -> int:
	"""Calculate XP needed for next level"""
	return level * 100

func get_exp_progress() -> float:
	"""Get experience progress as 0.0 to 1.0"""
	var needed = get_exp_for_next_level()
	if needed <= 0:
		return 0.0
	return float(experience) / float(needed)

func on_level_up():
	"""Called when leveling up"""
	match main_stat:
		"strength":
			stat_bonuses["strength"] += 2
		"agility":
			stat_bonuses["agility"] += 2
		"intellect":
			stat_bonuses["intellect"] += 2
	
	print("Class %s leveled up to %d!" % [player_class_name, level])

# ============================================================================
# SKILL TREE MANAGEMENT
# ============================================================================

func add_skill_tree(tree: SkillTree) -> PlayerClass:
	"""Add a skill tree to this class"""
	skill_trees[tree.tree_name] = tree
	return self

func find_skill_by_name(skill_name: String) -> Skill:
	"""Find a skill across all trees by name"""
	for tree_name in skill_trees:
		var skill = skill_trees[tree_name].find_skill_by_name(skill_name)
		if skill:
			return skill
	return null

func can_learn_skill(skill: Skill) -> bool:
	"""Check if a skill can be learned/ranked up"""
	if get_available_skill_points() < skill.skill_point_cost:
		return false
	
	if not skill.can_rank_up():
		return false
	
	for requirement in skill.requirements:
		var req_skill = find_skill_by_name(requirement.skill_name)
		if not req_skill or req_skill.current_rank < requirement.required_rank:
			return false
	
	return true

func learn_skill(skill: Skill) -> bool:
	"""Learn/rank up a skill"""
	if not can_learn_skill(skill):
		return false
	
	skill.rank_up()
	spent_skill_points += skill.skill_point_cost
	
	var unlock_action = skill.get_effect_value("unlock_action")
	if unlock_action and unlock_action not in combat_actions:
		combat_actions.append(unlock_action)
		print("Unlocked combat action: %s" % unlock_action)
	
	print("Learned %s (Rank %d/%d)" % [skill.skill_name, skill.current_rank, skill.max_rank])
	return true

func get_available_skill_points() -> int:
	"""Calculate unspent skill points"""
	return total_skill_points - spent_skill_points

func get_all_class_dice() -> Array:
	"""Get all dice granted by this class"""
	var class_dice = []
	
	match player_class_name:
		"Warrior":
			class_dice = [DieResource.DieType.D6, DieResource.DieType.D6]
			var bonus_count = int(level / 5)
			for i in range(bonus_count):
				class_dice.append(DieResource.DieType.D6)
		
		"Rogue":
			class_dice = [DieResource.DieType.D4, DieResource.DieType.D4, DieResource.DieType.D4]
			var bonus_count = int(level / 5)
			for i in range(bonus_count):
				class_dice.append(DieResource.DieType.D4)
		
		"Mage":
			class_dice = [DieResource.DieType.D8, DieResource.DieType.D6]
			var bonus_count = int(level / 5)
			for i in range(bonus_count):
				class_dice.append(DieResource.DieType.D8)
		
		_:
			class_dice = [DieResource.DieType.D6, DieResource.DieType.D6]
	
	return class_dice

func reset_skills():
	"""Reset all skills and refund points"""
	spent_skill_points = 0
	combat_actions.clear()
	
	for tree_name in skill_trees:
		skill_trees[tree_name].reset_all_skills()
	
	print("All skills reset for %s" % player_class_name)

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================
