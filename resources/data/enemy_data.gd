# enemy_data.gd - Enemy configuration resource with drag-and-drop dice and actions
extends Resource
class_name EnemyData

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")
@export var enemy_name: String = "Enemy"
@export_multiline var description: String = "A hostile creature."
@export var portrait: Texture2D = null
@export var sprite_texture: Texture2D = null

# ============================================================================
# STATS
# ============================================================================
@export_group("Stats")
@export var max_health: int = 50
@export var base_armor: int = 0
@export var base_barrier: int = 0

# ============================================================================
# DICE - Drag and drop DieResource assets here!
# ============================================================================
@export_group("Dice Pool")
## Dice this enemy starts combat with. Drag DieResource files here.
@export var starting_dice: Array[DieResource] = []

# ============================================================================
# ACTIONS - Drag and drop Action resources here!
# ============================================================================
@export_group("Combat Actions")
## Actions this enemy can perform. Drag Action resource files here.
@export var combat_actions: Array[Action] = []

# ============================================================================
# AI BEHAVIOR
# ============================================================================
@export_group("AI Settings")

enum AIStrategy {
	AGGRESSIVE,    ## Prioritize high damage attacks
	DEFENSIVE,     ## Prioritize defense and healing
	BALANCED,      ## Mix of offense and defense
	RANDOM         ## Random action selection
}

@export var ai_strategy: AIStrategy = AIStrategy.BALANCED

enum TargetPriority {
	LOWEST_HEALTH,   ## Target the weakest
	HIGHEST_HEALTH,  ## Target the strongest
	RANDOM           ## Random target
}

@export var target_priority: TargetPriority = TargetPriority.RANDOM

@export_subgroup("Timing")
## Delay between enemy actions (seconds)
@export_range(0.3, 2.0, 0.1) var action_delay: float = 0.8
## Duration of dice drag animation (seconds)
@export_range(0.2, 1.0, 0.1) var dice_drag_duration: float = 0.4

# ============================================================================
# REWARDS
# ============================================================================
@export_group("Rewards")
@export var experience_reward: int = 10
@export var gold_reward_min: int = 5
@export var gold_reward_max: int = 15
@export var loot_table_id: String = ""

# ============================================================================
# UTILITY METHODS
# ============================================================================

func get_actions_as_dicts() -> Array[Dictionary]:
	"""Convert Action resources to dictionaries for combat system"""
	var result: Array[Dictionary] = []
	
	for action in combat_actions:
		if action:
			var dict = action.to_dict()
			dict["source"] = enemy_name
			result.append(dict)
	
	return result

func create_dice_copies() -> Array[DieResource]:
	"""Create fresh copies of starting dice for a combat instance"""
	var copies: Array[DieResource] = []
	
	for die_template in starting_dice:
		if die_template:
			var die_copy = die_template.duplicate_die()
			die_copy.source = enemy_name
			copies.append(die_copy)
	
	return copies

func get_gold_reward() -> int:
	"""Roll gold reward within range"""
	return randi_range(gold_reward_min, gold_reward_max)

func _to_string() -> String:
	return "EnemyData<%s, HP:%d, Dice:%d, Actions:%d>" % [
		enemy_name, max_health, starting_dice.size(), combat_actions.size()
	]

# ============================================================================
# FACTORY METHODS - Create common enemies in code
# ============================================================================

static func create_goblin() -> EnemyData:
	"""Factory method: Create a basic goblin"""
	var enemy = EnemyData.new()
	enemy.enemy_name = "Goblin"
	enemy.description = "A small, vicious creature."
	enemy.max_health = 25
	enemy.ai_strategy = AIStrategy.AGGRESSIVE
	enemy.experience_reward = 15
	enemy.gold_reward_min = 3
	enemy.gold_reward_max = 8
	
	# Create dice
	enemy.starting_dice = [
		DieResource.new(DieResource.DieType.D4, "Goblin"),
		DieResource.new(DieResource.DieType.D6, "Goblin")
	]
	
	# Create action
	var stab = Action.new()
	stab.action_name = "Stab"
	stab.action_description = "A quick stab."
	stab.action_type = Action.ActionType.ATTACK
	stab.die_slots = 1
	stab.base_damage = 2
	stab.damage_multiplier = 1.0
	enemy.combat_actions = [stab]
	
	return enemy

static func create_skeleton() -> EnemyData:
	"""Factory method: Create a skeleton warrior"""
	var enemy = EnemyData.new()
	enemy.enemy_name = "Skeleton"
	enemy.description = "An undead warrior."
	enemy.max_health = 35
	enemy.base_armor = 2
	enemy.ai_strategy = AIStrategy.BALANCED
	enemy.experience_reward = 20
	
	enemy.starting_dice = [
		DieResource.new(DieResource.DieType.D6, "Skeleton"),
		DieResource.new(DieResource.DieType.D6, "Skeleton")
	]
	
	var bone_strike = Action.new()
	bone_strike.action_name = "Bone Strike"
	bone_strike.action_description = "Strikes with a bone club."
	bone_strike.action_type = Action.ActionType.ATTACK
	bone_strike.die_slots = 1
	bone_strike.base_damage = 3
	enemy.combat_actions = [bone_strike]
	
	return enemy

static func create_orc() -> EnemyData:
	"""Factory method: Create an orc warrior"""
	var enemy = EnemyData.new()
	enemy.enemy_name = "Orc Warrior"
	enemy.description = "A brutish orc."
	enemy.max_health = 60
	enemy.base_armor = 3
	enemy.ai_strategy = AIStrategy.AGGRESSIVE
	enemy.experience_reward = 35
	
	enemy.starting_dice = [
		DieResource.new(DieResource.DieType.D8, "Orc"),
		DieResource.new(DieResource.DieType.D8, "Orc"),
		DieResource.new(DieResource.DieType.D6, "Orc")
	]
	
	var cleave = Action.new()
	cleave.action_name = "Cleave"
	cleave.action_description = "Powerful overhead swing."
	cleave.action_type = Action.ActionType.ATTACK
	cleave.die_slots = 2
	cleave.base_damage = 5
	cleave.damage_multiplier = 1.5
	enemy.combat_actions = [cleave]
	
	return enemy
