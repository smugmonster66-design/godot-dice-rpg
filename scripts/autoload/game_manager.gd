# game_manager.gd - Main game orchestrator
extends Node

# ============================================================================
# PRELOADED SCENES
# ============================================================================
const COMBAT_SCENE = preload("res://scenes/game/combat_scene.tscn")
const MAP_SCENE = preload("res://scenes/game/map_scene.tscn")

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
	add_starting_items()
	
	if player.active_class:
		print("Player created: %s Level %d" % [player.active_class.player_class_name, player.active_class.level])
	else:
		print("Player created but no active class")
	
	player_created.emit(player)

func add_starting_items():
	"""Add starting equipment with affix rolls"""
	
	# Load item resources
	var iron_sword = load("res://resources/items/iron_sword.tres")
	var flaming_greatsword = load("res://resources/items/flaming_greatsword.tres")
	
	# Roll affixes using the global pool
	if iron_sword:
		iron_sword.roll_affixes(AffixPool)
		var sword_dict = iron_sword.to_dict()
		# Store the actual affix objects
		sword_dict["item_affixes"] = iron_sword.get_all_affixes()
		player.add_to_inventory(sword_dict)
		print("✅ Added Iron Sword to inventory")
	
	if flaming_greatsword:
		flaming_greatsword.roll_affixes(AffixPool)
		var gs_dict = flaming_greatsword.to_dict()
		# Store the actual affix objects
		gs_dict["item_affixes"] = flaming_greatsword.get_all_affixes()
		player.add_to_inventory(gs_dict)
		print("✅ Added Flaming Greatsword to inventory")

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
