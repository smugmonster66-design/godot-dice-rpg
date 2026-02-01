# res://scripts/resources/player_class.gd
# Player class definition with starting stats, dice, and skill trees
extends Resource
class_name PlayerClass

# ============================================================================
# ENUMS
# ============================================================================
enum ClassRole {
	DAMAGE,
	TANK,
	SUPPORT,
	HYBRID
}

enum MainStat {
	STRENGTH,
	AGILITY,
	INTELLIGENCE,
	VITALITY
}

# ============================================================================
# BASIC INFO
# ============================================================================
@export var class_id: String = ""
@export var player_class_name: String = "New Class"
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var portrait: Texture2D = null

@export_group("Classification")
@export var role: ClassRole = ClassRole.DAMAGE
@export var main_stat: MainStat = MainStat.STRENGTH

# ============================================================================
# BASE STATS
# ============================================================================
@export_group("Base Stats")
@export var base_health: int = 100
@export var base_mana: int = 50
@export var base_strength: int = 10
@export var base_agility: int = 10
@export var base_intelligence: int = 10
@export var base_vitality: int = 10
@export var base_armor: int = 0
@export var base_barrier: int = 0

# ============================================================================
# STAT GROWTH (per level)
# ============================================================================
@export_group("Stat Growth Per Level")
@export var health_per_level: int = 10
@export var mana_per_level: int = 5
@export var strength_per_level: float = 1.0
@export var agility_per_level: float = 1.0
@export var intelligence_per_level: float = 1.0
@export var vitality_per_level: float = 1.0

# ============================================================================
# STARTING DICE
# ============================================================================
@export_group("Starting Dice")
## Drag DieResource items here to define class starting dice
@export var starting_dice: Array[DieResource] = []

# ============================================================================
# SKILL TREES (up to 3)
# ============================================================================
@export_group("Skill Trees")
## Primary skill tree for this class
@export var skill_tree_1: SkillTree = null
## Secondary skill tree
@export var skill_tree_2: SkillTree = null
## Tertiary skill tree
@export var skill_tree_3: SkillTree = null

# ============================================================================
# STARTING EQUIPMENT & ABILITIES
# ============================================================================
@export_group("Starting Configuration")
@export var starting_actions: Array[Dictionary] = []  ## Default combat actions
@export var unlocked_at_level: int = 1  ## Level required to unlock this class

# ============================================================================
# STAT METHODS
# ============================================================================

func get_stat_at_level(stat_name: String, level: int) -> int:
	"""Calculate a stat value at a given level"""
	var base = 0
	var growth = 0.0
	
	match stat_name:
		"health", "max_hp":
			base = base_health
			growth = health_per_level
		"mana", "max_mana":
			base = base_mana
			growth = mana_per_level
		"strength":
			base = base_strength
			growth = strength_per_level
		"agility":
			base = base_agility
			growth = agility_per_level
		"intelligence":
			base = base_intelligence
			growth = intelligence_per_level
		"vitality":
			base = base_vitality
			growth = vitality_per_level
		"armor":
			return base_armor
		"barrier":
			return base_barrier
		_:
			return 0
	
	return base + int(growth * (level - 1))

func get_stat_bonus(stat_name: String) -> int:
	"""Get base stat bonus (for equipment affinity checks)"""
	match stat_name:
		"strength": return base_strength
		"agility": return base_agility
		"intelligence": return base_intelligence
		"vitality": return base_vitality
		"armor": return base_armor
		"barrier": return base_barrier
		_: return 0

func get_main_stat_name() -> String:
	"""Get the name of the main stat"""
	match main_stat:
		MainStat.STRENGTH: return "strength"
		MainStat.AGILITY: return "agility"
		MainStat.INTELLIGENCE: return "intelligence"
		MainStat.VITALITY: return "vitality"
		_: return "strength"

func get_role_name() -> String:
	"""Get the role as a string"""
	match role:
		ClassRole.DAMAGE: return "Damage"
		ClassRole.TANK: return "Tank"
		ClassRole.SUPPORT: return "Support"
		ClassRole.HYBRID: return "Hybrid"
		_: return "Unknown"

# ============================================================================
# DICE METHODS
# ============================================================================

func get_starting_dice_copies() -> Array[DieResource]:
	"""Create copies of starting dice (don't modify originals!)"""
	var copies: Array[DieResource] = []
	
	for die in starting_dice:
		if die:
			var copy = die.duplicate(true)
			copy.source = player_class_name
			copies.append(copy)
	
	return copies

func get_starting_dice_summary() -> String:
	"""Get a summary of starting dice for display"""
	if starting_dice.is_empty():
		return "No starting dice"
	
	var counts: Dictionary = {}
	for die in starting_dice:
		if die:
			var key = "D%d" % die.die_type
			counts[key] = counts.get(key, 0) + 1
	
	var parts: Array[String] = []
	for key in counts:
		parts.append("%dx %s" % [counts[key], key])
	
	return ", ".join(parts)

# ============================================================================
# SKILL TREE METHODS
# ============================================================================

func get_skill_trees() -> Array[SkillTree]:
	"""Get all assigned skill trees"""
	var trees: Array[SkillTree] = []
	if skill_tree_1: trees.append(skill_tree_1)
	if skill_tree_2: trees.append(skill_tree_2)
	if skill_tree_3: trees.append(skill_tree_3)
	return trees

func get_skill_tree_count() -> int:
	"""Count assigned skill trees"""
	var count = 0
	if skill_tree_1: count += 1
	if skill_tree_2: count += 1
	if skill_tree_3: count += 1
	return count

func get_all_skills() -> Array[SkillResource]:
	"""Get all skills from all skill trees"""
	var skills: Array[SkillResource] = []
	for tree in get_skill_trees():
		skills.append_array(tree.get_all_skills())
	return skills

func get_skill_by_id(id: String) -> SkillResource:
	"""Find a skill by ID across all trees"""
	for tree in get_skill_trees():
		var skill = tree.get_skill_by_id(id)
		if skill:
			return skill
	return null

func get_active_skills() -> Array[SkillResource]:
	"""Get all active (usable in combat) skills"""
	var active: Array[SkillResource] = []
	for skill in get_all_skills():
		if skill and skill.skill_type == SkillResource.SkillType.ACTIVE:
			active.append(skill)
	return active

# ============================================================================
# DEFAULT ACTIONS
# ============================================================================

func get_default_actions() -> Array[Dictionary]:
	"""Get default combat actions for this class"""
	if starting_actions.size() > 0:
		return starting_actions.duplicate(true)
	
	# Provide basic default actions if none specified
	return [
		{
			"name": "Attack",
			"action_type": 0,  # ATTACK
			"base_damage": 0,
			"damage_multiplier": 1.0,
			"die_slots": 1,
			"source": "class"
		},
		{
			"name": "Defend",
			"action_type": 1,  # DEFEND
			"base_damage": 0,
			"damage_multiplier": 0.5,
			"die_slots": 1,
			"source": "class"
		}
	]

# ============================================================================
# VALIDATION
# ============================================================================

func validate() -> Array[String]:
	"""Validate the class configuration"""
	var warnings: Array[String] = []
	
	if class_id.is_empty():
		warnings.append("Class has no ID")
	
	if player_class_name.is_empty():
		warnings.append("Class has no name")
	
	if base_health <= 0:
		warnings.append("Base health should be positive")
	
	if starting_dice.is_empty():
		warnings.append("Class has no starting dice")
	
	if get_skill_tree_count() == 0:
		warnings.append("Class has no skill trees")
	
	# Validate skill trees
	for tree in get_skill_trees():
		var tree_warnings = tree.validate()
		for warning in tree_warnings:
			warnings.append("[%s] %s" % [tree.tree_name, warning])
	
	return warnings

func _to_string() -> String:
	return "PlayerClass<%s: %s, %d dice, %d trees>" % [
		player_class_name, 
		get_role_name(),
		starting_dice.size(),
		get_skill_tree_count()
	]
