# game_manager.gd - Main game orchestrator
extends Node

# ============================================================================
# PRELOADED SCENES
# ============================================================================
const COMBAT_SCENE = preload("res://scenes/game/combat_scene.tscn")
const MAP_SCENE = preload("res://scenes/game/map_scene.tscn")

# ============================================================================
# STARTING ITEMS CONFIGURATION
# ============================================================================
@export_group("Starting Items")
@export var starting_items: Array[EquippableItem] = []

# ============================================================================
# GAME STATE
# ============================================================================
var player: Player = null
var current_scene: Node = null

# Scene instances for hide/show pattern
var map_scene_instance: Node2D = null
var combat_scene_instance: Node2D = null

# Combat results to pass to summary
var last_combat_results: Dictionary = {}

# ============================================================================
# SIGNALS
# ============================================================================
signal player_created(player: Player)
signal scene_changed(new_scene: Node)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	randomize()
	print("🎮 GameManager AutoLoad ready (waiting for scene)")
	
	# Wait for scene tree to be ready
	await get_tree().process_frame
	
	# Check if we have a current scene
	var root = get_tree().root
	var current = root.get_child(root.get_child_count() - 1)
	
	if current.name == "MapScene":
		print("🎮 Current scene: MapScene")
		map_scene_instance = current
		
		# Initialize player
		initialize_player()
		
		# Initialize the map
		if map_scene_instance.has_method("initialize_map"):
			map_scene_instance.initialize_map(player)
		
		# Connect signals
		if map_scene_instance.has_signal("start_combat"):
			map_scene_instance.start_combat.connect(_on_start_combat)
			print("🎮 Connected to map's start_combat signal")
		
		current_scene = map_scene_instance
	else:
		print("🎮 Starting fresh - loading map scene")
		initialize_player()
		load_map_scene()

func initialize_player():
	"""Create persistent player"""
	print("Creating player...")
	
	# Create player resource (not a node)
	player = Player.new()
	
	# Add dice pool as a child node
	add_child(player.dice_pool)
	print("  ✅ Dice pool added to scene tree")
	
	# Create simple warrior class (no skills yet - add via .tres files later)
	var warrior = PlayerClass.new("Warrior", "strength")
	warrior.stat_bonuses["strength"] = 5
	warrior.stat_bonuses["armor"] = 3
	
	player.add_class("Warrior", warrior)
	player.switch_class("Warrior")
	
	# Level up for testing
	for i in range(4):
		if player.active_class:
			player.active_class.gain_experience(100)
	
	# Add starting items
	#add_starting_items()
	
	if player.active_class:
		print("Player created: %s Level %d" % [player.active_class.player_class_name, player.active_class.level])
	else:
		print("Player created but no active class")
	
	player_created.emit(player)

#func add_starting_items():
	"""Add starting equipment from Inspector-configured array"""
	print("🎒 Adding starting items...")
	
	if starting_items.size() == 0:
		print("  ⚠️  No starting items configured in Inspector")
		return
	
	for item_template in starting_items:
		if not item_template:
			print("  ⚠️  Null item in starting_items array - skipping")
			continue
		
		# Initialize affixes (rolls or uses manual)
		item_template.initialize_affixes(AffixPool)
		
		# Convert to dictionary
		var item_dict = item_template.to_dict()
		item_dict["item_affixes"] = item_template.get_all_affixes()
		
		# Add to player inventory
		player.add_to_inventory(item_dict)
		
		print("  ✅ Added %s (%s) to inventory" % [item_template.item_name, item_template.get_rarity_name()])
	
	print("🎒 Finished adding %d starting items" % starting_items.size())

# ============================================================================
# SCENE MANAGEMENT
# ============================================================================

func load_map_scene():
	"""Load the map exploration scene"""
	print("🗺️ Loading map scene...")
	
	if map_scene_instance:
		map_scene_instance.show()
		current_scene = map_scene_instance
	else:
		map_scene_instance = MAP_SCENE.instantiate()
		get_tree().root.add_child(map_scene_instance)
		current_scene = map_scene_instance
		
		# Initialize after adding to tree
		if map_scene_instance.has_method("initialize_map"):
			map_scene_instance.initialize_map(player)
		
		# Connect signals
		if map_scene_instance.has_signal("start_combat"):
			map_scene_instance.start_combat.connect(_on_start_combat)
	
	scene_changed.emit(map_scene_instance)

func load_combat_scene():
	"""Load the combat scene"""
	print("⚔️ Loading combat scene...")
	
	if combat_scene_instance:
		combat_scene_instance.show()
		current_scene = combat_scene_instance
	else:
		combat_scene_instance = COMBAT_SCENE.instantiate()
		get_tree().root.add_child(combat_scene_instance)
		current_scene = combat_scene_instance
		
		# Initialize after adding to tree
		if combat_scene_instance.has_method("initialize_combat"):
			combat_scene_instance.initialize_combat(player)
		
		# Connect signals
		if combat_scene_instance.has_signal("combat_ended"):
			combat_scene_instance.combat_ended.connect(_on_combat_ended)
	
	# Hide map
	if map_scene_instance:
		map_scene_instance.hide()
	
	scene_changed.emit(combat_scene_instance)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_start_combat():
	"""Handle start combat from map"""
	print("🎮 Starting combat...")
	load_combat_scene()

func _on_combat_ended(results: Dictionary):
	"""Handle combat ended"""
	print("🎮 Combat ended")
	last_combat_results = results
	
	# Hide combat scene
	if combat_scene_instance:
		combat_scene_instance.hide()
	
	# Show map scene
	if map_scene_instance:
		map_scene_instance.show()
		current_scene = map_scene_instance
		
		# Show post-combat summary if available
		if map_scene_instance.has_method("show_post_combat_summary"):
			map_scene_instance.show_post_combat_summary(results)
	
	scene_changed.emit(map_scene_instance)

# Add these to your existing game_manager.gd

# ============================================================================
# COMBAT ENCOUNTER SYSTEM
# ============================================================================

## The pending encounter to load when combat scene starts
var pending_encounter: CombatEncounter = null

## History of completed encounters (for tracking/quests)
var completed_encounters: Array[String] = []

func start_combat_encounter(encounter: CombatEncounter):
	"""Start a combat encounter - stores encounter and transitions to combat scene"""
	if not encounter:
		push_error("GameManager: Cannot start null encounter")
		return
	
	print("🎮 GameManager: Starting encounter '%s'" % encounter.encounter_name)
	
	# Validate encounter
	var warnings = encounter.validate()
	if warnings.size() > 0:
		print("  ⚠️ Encounter warnings:")
		for warning in warnings:
			print("    - %s" % warning)
	
	# Store encounter for combat scene to read
	pending_encounter = encounter
	
	# Transition to combat scene
	load_combat_scene()

func start_random_encounter(encounter_pool: Array[CombatEncounter]):
	"""Start a random encounter from a pool"""
	if encounter_pool.size() == 0:
		push_error("GameManager: Empty encounter pool")
		return
	
	var random_index = randi() % encounter_pool.size()
	var encounter = encounter_pool[random_index]
	start_combat_encounter(encounter)

func get_pending_encounter() -> CombatEncounter:
	"""Get the pending encounter (called by combat scene)"""
	return pending_encounter

func clear_pending_encounter():
	"""Clear pending encounter after it's been loaded"""
	pending_encounter = null

func mark_encounter_completed(encounter: CombatEncounter):
	"""Mark an encounter as completed"""
	if encounter and encounter.encounter_id != "":
		if encounter.encounter_id not in completed_encounters:
			completed_encounters.append(encounter.encounter_id)
			print("🎮 Encounter completed: %s" % encounter.encounter_id)

func has_completed_encounter(encounter_id: String) -> bool:
	"""Check if an encounter has been completed"""
	return encounter_id in completed_encounters

func on_combat_ended(player_won: bool):
	"""Called when combat ends"""
	if player_won and pending_encounter:
		mark_encounter_completed(pending_encounter)
		
		# Calculate rewards
		var exp = pending_encounter.get_total_experience()
		var gold_range = pending_encounter.get_total_gold_range()
		var gold = randi_range(gold_range.x, gold_range.y)
		
		print("🎮 Combat rewards: %d XP, %d gold" % [exp, gold])
		
		# Apply rewards to player
		if player:
			player.add_experience(exp)
			player.add_gold(gold)
	
	clear_pending_encounter()
	load_map_scene()
