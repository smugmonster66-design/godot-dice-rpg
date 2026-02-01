# combatant.gd - Visual combatant (player or enemy) with dice and actions
extends Node2D
class_name Combatant

# ============================================================================
# EXPORTS
# ============================================================================
@export var max_health: int = 100
@export var combatant_name: String = "Combatant"
@export var is_player_controlled: bool = false

@export_group("Dice Configuration")
## Starting dice types for this combatant (only used for enemies)
@export var starting_dice_types: Array[int] = []  # DieResource.DieType values (4, 6, 8, etc.)

@export_group("Actions")
## Actions this combatant can perform (only used for enemies)
@export var actions: Array[Dictionary] = []

@export_group("AI Settings")
@export_enum("AGGRESSIVE", "DEFENSIVE", "BALANCED", "RANDOM") var ai_strategy: int = 0
@export var action_delay: float = 0.8
@export var dice_drag_duration: float = 0.4

# ============================================================================
# STATE
# ============================================================================
var current_health: int = 100
var dice_collection: PlayerDiceCollection = null

# Current action state (for AI turns)
var current_action: Dictionary = {}
var current_action_dice: Array[DieResource] = []

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var sprite = $Sprite2D
@onready var health_label = $HealthLabel

# ============================================================================
# SIGNALS
# ============================================================================
signal health_changed(new_health: int, max_health: int)
signal died()
signal turn_completed()
signal action_executed(action: Dictionary, value: int)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	current_health = max_health
	
	# Create dice collection for non-player combatants
	if not is_player_controlled:
		_setup_dice_collection()
	
	update_health_display()

func _setup_dice_collection():
	"""Setup dice collection for enemy combatants"""
	dice_collection = PlayerDiceCollection.new()
	dice_collection.name = "DiceCollection"
	add_child(dice_collection)
	
	# Add starting dice
	for die_type in starting_dice_types:
		var die = DieResource.new(die_type, combatant_name)
		dice_collection.add_die(die)
	
	print("🎲 %s: Dice collection created with %d dice" % [combatant_name, dice_collection.get_pool_count()])

func setup_from_data(data: Dictionary):
	"""Setup combatant from a data dictionary"""
	combatant_name = data.get("name", "Enemy")
	max_health = data.get("max_health", 100)
	current_health = max_health
	ai_strategy = data.get("ai_strategy", 0)
	actions = data.get("actions", [])
	
	# Setup dice
	if not dice_collection:
		_setup_dice_collection()
	else:
		dice_collection.clear_pool()
	
	var dice_types = data.get("dice", [])
	for die_type in dice_types:
		var die = DieResource.new(die_type, combatant_name)
		dice_collection.add_die(die)
	
	update_health_display()
	print("🎲 %s configured: %d HP, %d dice, %d actions" % [
		combatant_name, max_health, dice_collection.get_pool_count(), actions.size()
	])

# ============================================================================
# TURN MANAGEMENT (for AI combatants)
# ============================================================================

func start_turn():
	"""Called when this combatant's turn begins"""
	if is_player_controlled:
		return  # Player turn handled by combat_ui
	
	print("🎲 %s starting turn..." % combatant_name)
	
	# Roll dice into hand
	if dice_collection:
		dice_collection.roll_hand()
		print("  Rolled hand:")
		for die in dice_collection.get_hand_dice():
			print("    %s = %d" % [die.get_type_string(), die.get_total_value()])

func end_turn():
	"""Called when this combatant's turn ends"""
	if dice_collection:
		dice_collection.clear_hand()
	
	current_action = {}
	current_action_dice.clear()
	turn_completed.emit()

func get_available_dice() -> Array[DieResource]:
	"""Get dice available this turn"""
	if dice_collection:
		return dice_collection.get_hand_dice()
	return []

func has_usable_dice() -> bool:
	"""Check if combatant can still act"""
	var hand = get_available_dice()
	if hand.size() == 0:
		return false
	
	# Check if any action can be performed
	for action in actions:
		var required = action.get("die_slots", 1)
		if hand.size() >= required:
			return true
	
	return false

# ============================================================================
# ACTION EXECUTION (for AI combatants)
# ============================================================================

func prepare_action(action: Dictionary, dice: Array[DieResource]):
	"""Prepare an action with selected dice"""
	current_action = action
	current_action_dice = dice

func consume_action_die(die: DieResource):
	"""Mark a die as used (during animation)"""
	if dice_collection:
		dice_collection.consume_from_hand(die)

func execute_prepared_action() -> int:
	"""Execute the prepared action, return the result value"""
	var base = current_action.get("base_damage", 0)
	var multiplier = current_action.get("damage_multiplier", 1.0)
	
	var dice_total = 0
	for die in current_action_dice:
		dice_total += die.get_total_value()
	
	var result = int(base + (dice_total * multiplier))
	
	print("💥 %s executes %s: %d + (%d × %.1f) = %d" % [
		combatant_name,
		current_action.get("name", "Attack"),
		base, dice_total, multiplier, result
	])
	
	action_executed.emit(current_action, result)
	
	# Clear state
	current_action = {}
	current_action_dice.clear()
	
	return result

# ============================================================================
# HEALTH MANAGEMENT
# ============================================================================

func take_damage(amount: int):
	"""Take damage"""
	var old = current_health
	current_health = max(0, current_health - amount)
	
	print("💔 %s: %d → %d (-%d)" % [combatant_name, old, current_health, amount])
	
	update_health_display()
	flash_damage()
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		die()

func heal(amount: int):
	"""Heal"""
	var old = current_health
	current_health = min(max_health, current_health + amount)
	
	print("💚 %s: %d → %d (+%d)" % [combatant_name, old, current_health, amount])
	
	update_health_display()
	flash_heal()
	health_changed.emit(current_health, max_health)

func is_alive() -> bool:
	return current_health > 0

func die():
	"""Handle death"""
	print("☠️ %s died!" % combatant_name)
	died.emit()
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)

# ============================================================================
# DISPLAY
# ============================================================================

func update_health_display():
	"""Update health label"""
	if health_label:
		health_label.text = "%d/%d" % [current_health, max_health]

func flash_damage():
	"""Flash red on damage"""
	if sprite:
		sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func flash_heal():
	"""Flash green on heal"""
	if sprite:
		sprite.modulate = Color.GREEN
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
