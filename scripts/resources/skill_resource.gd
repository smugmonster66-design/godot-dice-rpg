# res://scripts/resources/skill_resource.gd
# Individual skill definition
extends Resource
class_name SkillResource

# ============================================================================
# ENUMS
# ============================================================================
enum SkillType {
	PASSIVE,      # Always active when learned
	ACTIVE,       # Must be used manually (adds action)
	TRIGGERED,    # Activates on specific conditions
	MODIFIER      # Modifies other skills/actions
}

enum TargetType {
	SELF,
	SINGLE_ENEMY,
	ALL_ENEMIES,
	SINGLE_ALLY,
	ALL_ALLIES
}

# ============================================================================
# BASIC INFO
# ============================================================================
@export var skill_id: String = ""
@export var skill_name: String = "New Skill"
@export_multiline var description: String = ""
@export var icon: Texture2D = null

@export_group("Skill Type")
@export var skill_type: SkillType = SkillType.PASSIVE
@export var target_type: TargetType = TargetType.SELF

# ============================================================================
# REQUIREMENTS
# ============================================================================
@export_group("Requirements")
@export var tier: int = 1  ## Which tier in the skill tree (1-5)
@export var skill_point_cost: int = 1
@export var required_skills: Array[SkillResource] = []  ## Must learn these first
@export var required_class_level: int = 1

# ============================================================================
# RANKS
# ============================================================================
@export_group("Ranks")
@export var max_rank: int = 3  ## How many times this can be upgraded
@export var rank_descriptions: Array[String] = []  ## Description per rank
@export var rank_values: Array[float] = []  ## Value scaling per rank

# ============================================================================
# PASSIVE EFFECTS
# ============================================================================
@export_group("Passive Effects")
@export var stat_bonuses: Dictionary = {}  ## {"strength": 2, "armor": 5}
@export var damage_bonus_percent: float = 0.0
@export var defense_bonus_percent: float = 0.0
@export var dice_modifier: int = 0  ## +/- to all dice rolls

# ============================================================================
# ACTIVE SKILL (if skill_type == ACTIVE)
# ============================================================================
@export_group("Active Skill")
@export var action_name: String = ""  ## Name shown in combat
@export var action_type: int = 0  ## 0=Attack, 1=Defend, 2=Heal, 3=Special
@export var base_damage: int = 0
@export var damage_multiplier: float = 1.0
@export var die_slots: int = 1
@export var cooldown_turns: int = 0
@export var mana_cost: int = 0

# ============================================================================
# TRIGGERED EFFECTS
# ============================================================================
@export_group("Trigger Conditions")
@export_enum("ON_ATTACK", "ON_DEFEND", "ON_DAMAGE_TAKEN", "ON_KILL", "ON_TURN_START", "ON_TURN_END", "ON_LOW_HEALTH", "ON_CRITICAL") var trigger_condition: int = 0
@export var trigger_chance: float = 1.0  ## 0.0 to 1.0
@export var trigger_value: float = 0.0  ## Damage/heal amount when triggered

# ============================================================================
# METHODS
# ============================================================================

func get_description_for_rank(rank: int) -> String:
	"""Get the description for a specific rank"""
	if rank <= 0:
		return description
	
	var index = rank - 1
	if index < rank_descriptions.size():
		return rank_descriptions[index]
	
	return description

func get_value_for_rank(rank: int) -> float:
	"""Get the scaled value for a specific rank"""
	if rank <= 0:
		return 0.0
	
	var index = rank - 1
	if index < rank_values.size():
		return rank_values[index]
	
	# Default scaling if not specified
	return rank * 1.0

func get_stat_bonus(stat_name: String, rank: int) -> int:
	"""Get stat bonus scaled by rank"""
	if not stat_bonuses.has(stat_name):
		return 0
	
	var base = stat_bonuses[stat_name]
	return int(base * rank)

func can_learn(player_level: int, learned_skills: Array) -> bool:
	"""Check if this skill can be learned"""
	# Check level requirement
	if player_level < required_class_level:
		return false
	
	# Check prerequisite skills
	for required in required_skills:
		if required and not learned_skills.has(required.skill_id):
			return false
	
	return true

func to_action_dict(rank: int = 1) -> Dictionary:
	"""Convert active skill to action dictionary for combat"""
	if skill_type != SkillType.ACTIVE:
		return {}
	
	var scaled_damage = base_damage + int(get_value_for_rank(rank))
	
	return {
		"name": action_name if action_name else skill_name,
		"action_type": action_type,
		"base_damage": scaled_damage,
		"damage_multiplier": damage_multiplier,
		"die_slots": die_slots,
		"source": "skill",
		"skill_id": skill_id,
		"rank": rank,
		"cooldown": cooldown_turns,
		"mana_cost": mana_cost,
		"icon": icon
	}

func _to_string() -> String:
	return "SkillResource<%s>" % skill_name
