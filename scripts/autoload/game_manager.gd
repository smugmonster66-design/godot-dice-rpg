# game_manager.gd - Main game orchestrator (UPDATED)
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
	
	# Set up starting class
	var warrior = PlayerClass.create_warrior()
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
	
	# Roll affixes and add to inventory
	if iron_sword:
		iron_sword.roll_affixes()
		var sword_dict = iron_sword.to_dict()
		player.add_to_inventory(sword_dict)
		print("✅ Added Iron Sword to inventory")
	
	if flaming_greatsword:
		flaming_greatsword.roll_affixes()
		var gs_dict = flaming_greatsword.to_dict()
		player.add_to_inventory(gs_dict)
		print("✅ Added Flaming Greatsword to inventory")
	

# ============================================================================
# SCENE MANAGEMENT
# ============================================================================

func load_map_scene():
	"""Load or restore map scene"""
	print("\n=== Loading Map Scene ===")
	
	# Hide combat
	if combat_scene_instance and is_instance_valid(combat_scene_instance):
		combat_scene_instance.hide()
		combat_scene_instance.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Show or create map
	if map_scene_instance and is_instance_valid(map_scene_instance):
		print("  Restoring map scene")
		map_scene_instance.show()
		map_scene_instance.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		print("  Creating new map scene")
		map_scene_instance = MAP_SCENE.instantiate()
		get_tree().root.add_child(map_scene_instance)
		
		if map_scene_instance.has_method("initialize_map"):
			map_scene_instance.initialize_map(player)
		
		if map_scene_instance.has_signal("start_combat"):
			map_scene_instance.start_combat.connect(_on_start_combat)
	
	current_scene = map_scene_instance
	scene_changed.emit(current_scene)
	print("Map scene active\n")

func load_combat_scene():
	"""Load or restore combat scene"""
	print("\n=== Loading Combat Scene ===")
	
	# Hide map
	if map_scene_instance and is_instance_valid(map_scene_instance):
		map_scene_instance.hide()
		map_scene_instance.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Reset player combat status
	player.reset_combat_status()
	
	# Show or create combat
	if combat_scene_instance and is_instance_valid(combat_scene_instance):
		print("  Reusing combat scene")
		combat_scene_instance.show()
		combat_scene_instance.process_mode = Node.PROCESS_MODE_INHERIT
		
		# CRITICAL: Initialize combat
		if combat_scene_instance.has_method("initialize_combat"):
			print("  🎯 Calling initialize_combat...")
			combat_scene_instance.initialize_combat(player)
		else:
			print("  ⚠️ ERROR: Combat scene missing initialize_combat method!")
	else:
		print("  Creating new combat scene")
		combat_scene_instance = COMBAT_SCENE.instantiate()
		get_tree().root.add_child(combat_scene_instance)
		
		# Wait for combat scene to be ready
		await get_tree().process_frame
		
		# CRITICAL: Initialize combat
		if combat_scene_instance.has_method("initialize_combat"):
			print("  🎯 Calling initialize_combat...")
			combat_scene_instance.initialize_combat(player)
		else:
			print("  ⚠️ ERROR: Combat scene missing initialize_combat method!")
		
		# Connect combat ended signal
		if combat_scene_instance.has_signal("combat_ended"):
			combat_scene_instance.combat_ended.connect(_on_combat_ended)
			print("  🎯 Connected to combat_ended signal")
	
	current_scene = combat_scene_instance
	scene_changed.emit(current_scene)
	print("Combat scene active\n")

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_start_combat():
	"""Player initiated combat"""
	print("\n>>> Starting combat <<<")
	load_combat_scene()

func _on_combat_ended(player_won: bool):
	"""Combat ended - prepare results and show summary"""
	print("\n=== Combat Ended ===")
	
	# Prepare combat results
	last_combat_results = {
		"victory": player_won,
		"xp_gained": 0,
		"loot": []
	}
	
	if player_won:
		print("🎉 VICTORY!")
		# Award XP
		var xp_gained = 100
		last_combat_results["xp_gained"] = xp_gained
		
		if player.active_class:
			player.active_class.gain_experience(xp_gained)
			print("  Awarded %d XP" % xp_gained)
			print("  Player is now level %d" % player.active_class.level)
		
		# Generate loot
		last_combat_results["loot"] = generate_loot()
		for item in last_combat_results["loot"]:
			player.add_to_inventory(item)
			print("  Looted: %s" % item.get("name", "Unknown"))
	else:
		print("💀 DEFEAT!")
		# Restore HP
		var restored_hp = int(player.max_hp * 0.5)
		player.current_hp = restored_hp
		player.hp_changed.emit(player.current_hp, player.max_hp)
		print("  HP restored to %d (50%%)" % restored_hp)
	
	# Return to map and show summary
	load_map_scene()
	
	# Wait a frame for map to fully load
	await get_tree().process_frame
	
	# Show post-combat summary
	if map_scene_instance and map_scene_instance.has_method("show_post_combat_summary"):
		map_scene_instance.show_post_combat_summary(last_combat_results)

func generate_loot() -> Array:
	"""Generate random loot (placeholder)"""
	var loot = []
	
	# Example: random potion
	if randf() > 0.5:
		loot.append({
			"name": "Health Potion",
			"type": "Consumable",
			"effect": "heal",
			"amount": 50,
			"description": "Restores 50 HP"
		})
	
	return loot

# ============================================================================
# DEBUG
# ============================================================================

func _input(event):
	if OS.is_debug_build():
		if event.is_action_pressed("ui_text_completion_replace"):  # F5
			if player:
				player.heal(50)
				print("DEBUG: Healed 50 HP")
		
		if event.is_action_pressed("ui_text_completion_accept"):  # F6
			if current_scene == map_scene_instance:
				load_combat_scene()
			else:
				load_map_scene()
