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
			class_dice = [DieData.DieType.D6, DieData.DieType.D6]
			var bonus_count = int(level / 5)
			for i in range(bonus_count):
				class_dice.append(DieData.DieType.D6)
		
		"Rogue":
			class_dice = [DieData.DieType.D4, DieData.DieType.D4, DieData.DieType.D4]
			var bonus_count = int(level / 5)
			for i in range(bonus_count):
				class_dice.append(DieData.DieType.D4)
		
		"Mage":
			class_dice = [DieData.DieType.D8, DieData.DieType.D6]
			var bonus_count = int(level / 5)
			for i in range(bonus_count):
				class_dice.append(DieData.DieType.D8)
		
		_:
			class_dice = [DieData.DieType.D6, DieData.DieType.D6]
	
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

static func create_warrior() -> PlayerClass:
	var warrior = PlayerClass.new("Warrior", "strength")
	warrior.stat_bonuses["strength"] = 5
	warrior.stat_bonuses["armor"] = 3
	
	var arms_tree = SkillTree.new("Arms", "Master of weapons and physical combat")
	
	var weapon_mastery = Skill.new("Weapon Mastery", "Increases physical damage", 5, 1)
	weapon_mastery.set_effects({"damage_bonus": 2})
	
	var armor_proficiency = Skill.new("Armor Proficiency", "Increases armor", 5, 1)
	armor_proficiency.set_effects({"stat_bonus": {"armor": 2}})
	
	var power_strike = Skill.new("Power Strike", "Unlocks powerful attack", 1, 2)
	power_strike.add_requirement("Weapon Mastery", 3)
	power_strike.set_effects({"unlock_action": "PowerStrike"})
	
	var cleave = Skill.new("Cleave", "Increases strength", 3, 2)
	cleave.add_requirement("Weapon Mastery", 2)
	cleave.set_effects({"stat_bonus": {"strength": 3}})
	
	var devastating_blow = Skill.new("Devastating Blow", "Massive damage attack", 1, 3)
	devastating_blow.add_requirement("Power Strike", 1)
	devastating_blow.add_requirement("Cleave", 2)
	devastating_blow.set_effects({"unlock_action": "DevastatingBlow"})
	
	arms_tree.add_skill(weapon_mastery)
	arms_tree.add_skill(armor_proficiency)
	arms_tree.add_skill(power_strike)
	arms_tree.add_skill(cleave)
	arms_tree.add_skill(devastating_blow)
	
	var armour_tree = SkillTree.new("Armour", "Master of defense and endurance")
	
	var iron_skin = Skill.new("Iron Skin", "Increases armor", 5, 1)
	iron_skin.set_effects({"stat_bonus": {"armor": 3}})
	
	var vitality = Skill.new("Vitality", "Increases maximum HP", 5, 1)
	vitality.set_effects({"stat_bonus": {"max_hp": 10}})
	
	var shield_wall = Skill.new("Shield Wall", "Defensive stance", 1, 2)
	shield_wall.add_requirement("Iron Skin", 3)
	shield_wall.set_effects({"unlock_action": "ShieldWall"})
	
	var tough_as_nails = Skill.new("Tough as Nails", "Damage reduction", 3, 2)
	tough_as_nails.add_requirement("Vitality", 2)
	tough_as_nails.set_effects({"damage_reduction_percent": 5})
	
	var unbreakable = Skill.new("Unbreakable", "Ultimate defense", 1, 3)
	unbreakable.add_requirement("Shield Wall", 1)
	unbreakable.add_requirement("Tough as Nails", 2)
	unbreakable.set_effects({"unlock_action": "Unbreakable"})
	
	armour_tree.add_skill(iron_skin)
	armour_tree.add_skill(vitality)
	armour_tree.add_skill(shield_wall)
	armour_tree.add_skill(tough_as_nails)
	armour_tree.add_skill(unbreakable)
	
	var berserker_tree = SkillTree.new("Berserker", "Channel rage for devastating power")
	
	var battle_rage = Skill.new("Battle Rage", "Increases damage when low HP", 5, 1)
	battle_rage.set_effects({"low_hp_damage_bonus": 10})
	
	var savage_strikes = Skill.new("Savage Strikes", "Increases crit damage", 5, 1)
	savage_strikes.set_effects({"crit_damage_bonus": 5})
	
	var bloodlust = Skill.new("Bloodlust", "Heal on kill", 1, 2)
	bloodlust.add_requirement("Battle Rage", 3)
	bloodlust.set_effects({"heal_on_kill_percent": 20})
	
	var reckless_abandon = Skill.new("Reckless Abandon", "More damage, less defense", 3, 2)
	reckless_abandon.add_requirement("Savage Strikes", 2)
	reckless_abandon.set_effects({"damage_bonus": 5, "armor_penalty": -2})
	
	var rampage = Skill.new("Rampage", "Ultimate berserker ability", 1, 3)
	rampage.add_requirement("Bloodlust", 1)
	rampage.add_requirement("Reckless Abandon", 2)
	rampage.set_effects({"unlock_action": "Rampage"})
	
	berserker_tree.add_skill(battle_rage)
	berserker_tree.add_skill(savage_strikes)
	berserker_tree.add_skill(bloodlust)
	berserker_tree.add_skill(reckless_abandon)
	berserker_tree.add_skill(rampage)
	
	warrior.add_skill_tree(arms_tree)
	warrior.add_skill_tree(armour_tree)
	warrior.add_skill_tree(berserker_tree)
	
	return warrior

static func create_rogue() -> PlayerClass:
	var rogue = PlayerClass.new("Rogue", "agility")
	rogue.stat_bonuses["agility"] = 5
	return rogue

static func create_mage() -> PlayerClass:
	var mage = PlayerClass.new("Mage", "intellect")
	mage.stat_bonuses["intellect"] = 5
	mage.stat_bonuses["barrier"] = 3
	return mage
