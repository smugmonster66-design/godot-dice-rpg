# combat_manager.gd - Manages combat flow and state
extends Node2D

# ============================================================================
# NODE REFERENCES
# ============================================================================
# Make these optional - we'll find them dynamically
var player_combatant = null
var enemy_combatant = null
var combat_ui = null

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var current_turn: String = "player"  # "player" or "enemy"

enum CombatState {
	PLAYER_TURN,
	ENEMY_TURN,
	TRANSITIONING,
	ENDED
}

var combat_state: CombatState = CombatState.PLAYER_TURN

# ============================================================================
# SIGNALS
# ============================================================================
signal combat_ended(player_won: bool)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("⚔️ CombatManager _ready")
	
	# Find nodes dynamically
	find_combat_nodes()
	
	# Setup connections
	setup_connections()

func find_combat_nodes():
	"""Find combat nodes in the scene tree"""
	print("🔍 Finding combat nodes...")
	
	# Find combatants
	player_combatant = find_child("PlayerCombantant", true, false)
	if not player_combatant:
		player_combatant = find_child("PlayerCombatant", true, false)  # Try alternate spelling
	
	enemy_combatant = find_child("Enemy1", true, false)
	if not enemy_combatant:
		enemy_combatant = find_child("EnemyCombatant", true, false)  # Try alternate name
	
	# Find UI
	combat_ui = find_child("CombatUILayer", true, false)
	if not combat_ui:
		combat_ui = find_child("CombatUI", true, false)  # Try alternate name
	
	# Report findings
	print("  Player Combatant: %s" % ("Found" if player_combatant else "❌ NOT FOUND"))
	print("  Enemy Combatant: %s" % ("Found" if enemy_combatant else "❌ NOT FOUND"))
	print("  Combat UI: %s" % ("Found" if combat_ui else "❌ NOT FOUND"))

func setup_connections():
	"""Setup signal connections"""
	print("⚔️ Setting up connections...")
	
	# Connect combatant signals if they exist
	if player_combatant and player_combatant.has_signal("hp_changed"):
		if player_combatant.hp_changed.connect(_on_player_hp_changed) == OK:
			print("  ✅ Player combatant connected")
	else:
		print("  ⚠️ Player combatant not found or missing hp_changed signal")
	
	if enemy_combatant and enemy_combatant.has_signal("hp_changed"):
		if enemy_combatant.hp_changed.connect(_on_enemy_hp_changed) == OK:
			print("  ✅ Enemy combatant connected")
	else:
		print("  ⚠️ Enemy combatant not found or missing hp_changed signal")
	
	# Connect combat UI signals
	if combat_ui:
		if combat_ui.has_signal("action_confirmed"):
			if combat_ui.action_confirmed.connect(_on_action_confirmed) == OK:
				print("  ✅ Combat UI action_confirmed connected")
		
		if combat_ui.has_signal("turn_ended"):
			if combat_ui.turn_ended.connect(_on_turn_ended) == OK:
				print("  ✅ Combat UI turn_ended connected")
	else:
		print("  ⚠️ Combat UI not found")

func initialize_combat(p_player: Player):
	"""Initialize combat with player data"""
	print("⚔️ Initializing combat with player")
	player = p_player
	
	# Check player equipment
	print("  🔍 Player equipment check:")
	for slot in player.equipment:
		if player.equipment[slot] != null:
			var item = player.equipment[slot]
			print("    %s: %s" % [slot, item.get("name")])
			if item.has("actions"):
				print("      Has %d actions!" % item.get("actions").size())
	
	# Connect to player events
	if player.has_signal("hp_changed"):
		if player.hp_changed.connect(_on_player_hp_changed) == OK:
			print("  ✅ Connected hp_changed signal")
	
	if player.has_signal("player_died"):
		if player.player_died.connect(_on_player_died) == OK:
			print("  ✅ Connected player_died signal")
	
	# Sync player data to combatant
	sync_player_to_combatant()
	
	# Roll player dice
	print("  🎲 Rolling player dice pool...")
	player.dice_pool.roll_all_dice()
	print("  🎲 Player has %d dice available" % player.dice_pool.available_dice.size())
	
	# Initialize UI
	if combat_ui:
		print("  🎮 Initializing combat UI...")
		combat_ui.initialize_ui(player, enemy_combatant)
		print("  ✅ Combat UI initialized")
	
	print("⚔️ Combat initialization complete")
	
	# Connect to combat_ended for cleanup
	if not combat_ended.is_connected(_on_combat_ended):
		combat_ended.connect(_on_combat_ended)
		print("  🎯 Connected to combat_ended signal")

func sync_player_to_combatant():
	"""Sync player stats to combatant"""
	if player and player_combatant:
		player_combatant.current_health = player.current_health
		player_combatant.max_health = player.max_health
		print("  ✅ Synced player to combatant")

# ============================================================================
# COMBAT FLOW
# ============================================================================

func _on_action_confirmed(action_data: Dictionary):
	"""Execute a confirmed action"""
	var action_name = action_data.get("name", "Unknown")
	var action_type = action_data.get("action_type", 0)
	var base_damage = action_data.get("base_damage", 0)
	var damage_multiplier = action_data.get("damage_multiplier", 1.0)
	var placed_dice = action_data.get("placed_dice", [])
	var source = action_data.get("source", "Unknown")
	
	print("⚔️ Executing action: %s" % action_name)
	print("  Source: %s" % source)
	print("  Base Damage: %d" % base_damage)
	print("  Multiplier: %.1fx" % damage_multiplier)
	print("  Dice used: %d" % placed_dice.size())
	
	# Calculate total damage
	var total_damage = calculate_action_damage(action_data)
	
	# Execute based on action type
	match action_type:
		0: # ATTACK
			execute_attack(total_damage, action_name, source)
		1: # DEFEND
			execute_defend(action_data)
		2: # HEAL
			execute_heal(total_damage, action_name)
		3: # SPECIAL
			execute_special(action_data)
		_:
			print("  ⚠️ Unknown action type: %d" % action_type)

func calculate_action_damage(action_data: Dictionary) -> int:
	"""Calculate total damage from action and dice"""
	var base_damage = action_data.get("base_damage", 0)
	var damage_multiplier = action_data.get("damage_multiplier", 1.0)
	var placed_dice: Array = action_data.get("placed_dice", [])
	
	# Sum all dice values
	var dice_total = 0
	for die in placed_dice:
		if die is DieData:
			dice_total += die.value
			print("    Die: %s = %d" % [die.get_display_name(), die.value])
	
	# Calculate: (dice_total * multiplier) + base_damage
	var total = int((dice_total * damage_multiplier) + base_damage)
	
	print("  💥 Damage Calculation:")
	print("    Dice Total: %d" % dice_total)
	print("    × Multiplier: %.1f = %d" % [damage_multiplier, int(dice_total * damage_multiplier)])
	print("    + Base Damage: %d" % base_damage)
	print("    = TOTAL: %d" % total)
	
	return total

func execute_attack(damage: int, action_name: String, source: String):
	"""Execute an attack action"""
	print("  ⚔️ %s attacks with %s for %d damage!" % [source, action_name, damage])
	
	# Apply damage to enemy
	if enemy_combatant:
		enemy_combatant.take_damage(damage)
		print("    ✅ Enemy took %d damage" % damage)
		
		# Update UI
		if combat_ui and combat_ui.has_method("update_enemy_health"):
			combat_ui.update_enemy_health(enemy_combatant.current_hp, enemy_combatant.max_hp)
		
		# Check if enemy died
		if enemy_combatant.current_hp <= 0:
			print("    ☠️ Enemy defeated!")
			end_combat(true)  # Player wins
	else:
		print("    ❌ No enemy to attack!")

func execute_defend(action_data: Dictionary):
	"""Execute a defend action (reduce incoming damage)"""
	var armor_bonus = action_data.get("base_damage", 5)  # Use base_damage as armor value
	print("  🛡️ Defending! Gained %d temporary armor" % armor_bonus)
	
	# TODO: Implement temporary armor system
	# For now, just log it

func execute_heal(heal_amount: int, action_name: String):
	"""Execute a healing action"""
	print("  💚 %s heals for %d HP!" % [action_name, heal_amount])
	
	if player_combatant and player_combatant.has_method("heal"):
		var old_hp = player_combatant.current_hp
		player_combatant.heal(heal_amount)
		var healed = player_combatant.current_hp - old_hp
		print("    ✅ Healed %d HP" % healed)
		
		# Update UI
		if combat_ui and combat_ui.has_method("update_player_health"):
			combat_ui.update_player_health(player_combatant.current_hp, player_combatant.max_hp)

func execute_special(action_data: Dictionary):
	"""Execute a special action"""
	var action_name = action_data.get("name", "Special")
	print("  ✨ Special action: %s" % action_name)
	# TODO: Implement special action effects

func _on_turn_ended():
	"""Handle turn end"""
	print("⚔️ Turn ended")
	
	if combat_state == CombatState.PLAYER_TURN:
		# Switch to enemy turn
		combat_state = CombatState.ENEMY_TURN
		current_turn = "enemy"
		print("  → AI turn")
		start_enemy_turn()
	elif combat_state == CombatState.ENEMY_TURN:
		# Switch back to player turn
		combat_state = CombatState.PLAYER_TURN
		current_turn = "player"
		print("  → Player turn")
		start_player_turn()

func start_player_turn():
	"""Start player's turn"""
	# Roll new dice
	if player and player.dice_pool:
		player.dice_pool.roll_all_dice()
	
	# Refresh UI
	if combat_ui and combat_ui.has_method("refresh_dice_pool"):
		combat_ui.refresh_dice_pool()

func start_enemy_turn():
	"""Start enemy's turn (AI)"""
	print("🤖 AI thinking...")
	
	# Simple AI: just attack
	await get_tree().create_timer(1.0).timeout
	
	print("🤖 AI attacks!")
	var damage = randi_range(1, 6)  # Random damage for now
	
	if player_combatant and player_combatant.has_method("take_damage"):
		player_combatant.take_damage(damage)
		
		# Update UI
		if combat_ui and combat_ui.has_method("update_player_health"):
			combat_ui.update_player_health(player_combatant.current_hp, player_combatant.max_hp)
		
		# Check if player died
		if player_combatant.current_hp <= 0:
			print("    ☠️ Player defeated!")
			end_combat(false)  # Player lost
			return
	
	# End enemy turn
	await get_tree().create_timer(1.0).timeout
	_on_turn_ended()

# ============================================================================
# COMBAT END
# ============================================================================

func end_combat(player_won: bool):
	"""End combat with result"""
	print("\n=== Combat Ended ===")
	combat_state = CombatState.ENDED
	
	if player_won:
		print("🎉 Victory! Player wins!")
		# TODO: Show victory screen, give rewards
	else:
		print("💀 Defeat! Player lost!")
		# TODO: Show defeat screen
	
	# Emit signal
	combat_ended.emit(player_won)
	
	# Return to map after delay
	await get_tree().create_timer(2.0).timeout
	
	# Return to map scene
	if GameManager and GameManager.has_method("load_map_scene"):
		GameManager.load_map_scene()
	else:
		print("⚠️ GameManager.load_map_scene() not found")

func _on_combat_ended(player_won: bool):
	"""Cleanup after combat ends"""
	print("🧹 Cleaning up combat...")
	
	# Sync combatant HP back to player
	if player and player_combatant:
		player.current_hp = player_combatant.current_hp

# ============================================================================
# HEALTH CHANGE HANDLERS
# ============================================================================

func _on_player_hp_changed(current: int, maximum: int):
	"""Player HP changed"""
	# Sync to player resource
	if player:
		player.current_hp = current
	
	# Update UI
	if combat_ui and combat_ui.has_method("update_player_health"):
		combat_ui.update_player_health(current, maximum)

func _on_enemy_hp_changed(current: int, maximum: int):
	"""Enemy HP changed"""
	# Update UI
	if combat_ui and combat_ui.has_method("update_enemy_health"):
		combat_ui.update_enemy_health(current, maximum)

func _on_player_died():
	"""Player died"""
	print("💀 Player has died!")
	end_combat(false)
