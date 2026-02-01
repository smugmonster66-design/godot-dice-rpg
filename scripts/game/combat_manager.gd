# combat_manager.gd - Manages combat flow with multiple enemies and turn order
extends Node2D

# ============================================================================
# NODE REFERENCES
# ============================================================================
var player_combatant: Combatant = null
var enemy_combatants: Array[Combatant] = []
var combat_ui = null

# ============================================================================
# STATE
# ============================================================================
var player: Player = null

enum CombatState {
	INITIALIZING,
	PLAYER_TURN,
	ENEMY_TURN,
	ANIMATING,
	ENDED
}

var combat_state: CombatState = CombatState.INITIALIZING

# Turn order
var turn_order: Array[Combatant] = []
var current_turn_index: int = 0
var current_round: int = 0

# ============================================================================
# SIGNALS
# ============================================================================
signal combat_ended(player_won: bool)
signal turn_started(combatant: Combatant, is_player: bool)
signal round_started(round_number: int)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("⚔️ CombatManager _ready")
	find_combat_nodes()
	setup_connections()

func find_combat_nodes():
	"""Find combat nodes in the scene tree"""
	print("🔍 Finding combat nodes...")
	
	# Find player combatant
	player_combatant = find_child("PlayerCombatant", true, false) as Combatant
	if not player_combatant:
		player_combatant = find_child("PlayerCombantant", true, false) as Combatant
	
	if player_combatant:
		player_combatant.is_player_controlled = true
	
	# Find all enemy combatants
	enemy_combatants.clear()
	for i in range(1, 4):  # Enemy1, Enemy2, Enemy3
		var enemy = find_child("Enemy%d" % i, true, false) as Combatant
		if enemy:
			enemy.is_player_controlled = false
			enemy_combatants.append(enemy)
	
	# Also find any Combatant children that aren't the player
	for child in get_children():
		if child is Combatant and child != player_combatant and child not in enemy_combatants:
			child.is_player_controlled = false
			enemy_combatants.append(child)
	
	# Find UI
	combat_ui = find_child("CombatUILayer", true, false)
	if not combat_ui:
		combat_ui = find_child("CombatUI", true, false)
	
	print("  Player Combatant: %s" % ("Found" if player_combatant else "❌ NOT FOUND"))
	print("  Enemy Combatants: %d found" % enemy_combatants.size())
	for enemy in enemy_combatants:
		print("    - %s" % enemy.combatant_name)
	print("  Combat UI: %s" % ("Found" if combat_ui else "❌ NOT FOUND"))

func setup_connections():
	"""Setup signal connections"""
	print("⚔️ Setting up connections...")
	
	# Player combatant
	if player_combatant:
		if not player_combatant.health_changed.is_connected(_on_player_health_changed):
			player_combatant.health_changed.connect(_on_player_health_changed)
		if not player_combatant.died.is_connected(_on_player_died):
			player_combatant.died.connect(_on_player_died)
		print("  ✅ Player combatant connected")
	
	# Enemy combatants
	for i in range(enemy_combatants.size()):
		var enemy = enemy_combatants[i]
		if not enemy.health_changed.is_connected(_on_enemy_health_changed):
			enemy.health_changed.connect(_on_enemy_health_changed.bind(i))
		if not enemy.died.is_connected(_on_enemy_died):
			enemy.died.connect(_on_enemy_died.bind(enemy))
		if not enemy.turn_completed.is_connected(_on_combatant_turn_completed):
			enemy.turn_completed.connect(_on_combatant_turn_completed.bind(enemy))
		print("  ✅ Enemy '%s' connected" % enemy.combatant_name)
	
	# Combat UI
	if combat_ui:
		if combat_ui.has_signal("action_confirmed") and not combat_ui.action_confirmed.is_connected(_on_action_confirmed):
			combat_ui.action_confirmed.connect(_on_action_confirmed)
		if combat_ui.has_signal("turn_ended") and not combat_ui.turn_ended.is_connected(_on_player_end_turn):
			combat_ui.turn_ended.connect(_on_player_end_turn)
		print("  ✅ Combat UI connected")

# ============================================================================
# COMBAT INITIALIZATION
# ============================================================================

func initialize_combat(p_player: Player):
	"""Initialize combat with player data"""
	print("⚔️ Initializing combat with player")
	player = p_player
	combat_state = CombatState.INITIALIZING
	
	# Sync player to combatant
	_sync_player_to_combatant()
	
	# Build turn order: player first, then enemies
	turn_order.clear()
	turn_order.append(player_combatant)
	for enemy in enemy_combatants:
		if enemy.is_alive():
			turn_order.append(enemy)
	
	print("  Turn order: %s" % [turn_order.map(func(c): return c.combatant_name)])
	
	# Initialize UI
	if combat_ui:
		combat_ui.initialize_ui(player, enemy_combatants)
	
	# Connect cleanup
	if not combat_ended.is_connected(_on_combat_ended):
		combat_ended.connect(_on_combat_ended)
	
	print("⚔️ Combat initialization complete")
	
	# Start first round
	await get_tree().process_frame
	_start_round()

func _sync_player_to_combatant():
	"""Sync player stats to combatant"""
	if player and player_combatant:
		player_combatant.current_health = player.current_hp
		player_combatant.max_health = player.max_hp
		player_combatant.combatant_name = "Player"
		player_combatant.update_health_display()
		print("  ✅ Synced player to combatant")

# ============================================================================
# TURN ORDER MANAGEMENT
# ============================================================================

func _start_round():
	"""Start a new round"""
	current_round += 1
	current_turn_index = 0
	
	print("\n⚔️ === ROUND %d ===" % current_round)
	round_started.emit(current_round)
	
	_start_current_turn()

func _start_current_turn():
	"""Start the current combatant's turn"""
	# Skip dead combatants
	while current_turn_index < turn_order.size():
		var combatant = turn_order[current_turn_index]
		if combatant.is_alive():
			break
		current_turn_index += 1
	
	# Check if round is over
	if current_turn_index >= turn_order.size():
		_end_round()
		return
	
	var combatant = turn_order[current_turn_index]
	var is_player = (combatant == player_combatant)
	
	print("\n🎲 %s's turn" % combatant.combatant_name)
	turn_started.emit(combatant, is_player)
	
	if is_player:
		_start_player_turn()
	else:
		_start_enemy_turn(combatant)

func _end_current_turn():
	"""Move to next turn"""
	current_turn_index += 1
	_start_current_turn()

func _end_round():
	"""End round and check for combat end or start new round"""
	print("\n⚔️ === ROUND %d ENDED ===" % current_round)
	
	# Check for combat end
	if _check_combat_end():
		return
	
	# Start new round
	_start_round()

func _check_combat_end() -> bool:
	"""Check if combat should end"""
	# Player dead?
	if not player_combatant.is_alive():
		end_combat(false)
		return true
	
	# All enemies dead?
	var all_dead = true
	for enemy in enemy_combatants:
		if enemy.is_alive():
			all_dead = false
			break
	
	if all_dead:
		end_combat(true)
		return true
	
	return false

# ============================================================================
# PLAYER TURN
# ============================================================================

func _start_player_turn():
	"""Start player's turn"""
	combat_state = CombatState.PLAYER_TURN
	
	# Roll player dice
	if player and player.dice_pool:
		player.dice_pool.roll_hand()
	
	# Update UI
	if combat_ui:
		if combat_ui.has_method("on_turn_start"):
			combat_ui.on_turn_start()
		if combat_ui.has_method("set_player_turn"):
			combat_ui.set_player_turn(true)

func _on_player_end_turn():
	"""Player ended their turn"""
	if combat_state != CombatState.PLAYER_TURN:
		return
	
	print("🎮 Player ended turn")
	_end_current_turn()

func _on_action_confirmed(action_data: Dictionary):
	"""Player confirmed an action"""
	if combat_state != CombatState.PLAYER_TURN:
		return
	
	var action_name = action_data.get("name", "Unknown")
	var action_type = action_data.get("action_type", 0)
	var damage = _calculate_damage(action_data)
	
	print("⚔️ Player uses %s (type=%d, value=%d)" % [action_name, action_type, damage])
	
	match action_type:
		0:  # ATTACK
			var target = _get_first_living_enemy()
			if target:
				print("  → Attacking %s" % target.combatant_name)
				target.take_damage(damage)
				_update_enemy_health(enemy_combatants.find(target))
				_check_enemy_death(target)
		1:  # DEFEND
			print("  → Defending")
		2:  # HEAL
			print("  → Healing for %d" % damage)
			player_combatant.heal(damage)
			_update_player_health()
		3:  # SPECIAL
			print("  → Special action")

# ============================================================================
# ENEMY TURN
# ============================================================================

func _start_enemy_turn(enemy: Combatant):
	"""Start an enemy's turn"""
	combat_state = CombatState.ENEMY_TURN
	
	# Disable player controls
	if combat_ui and combat_ui.has_method("set_player_turn"):
		combat_ui.set_player_turn(false)
	
	# Roll enemy dice
	enemy.start_turn()
	
	# Show enemy hand in UI
	if combat_ui and combat_ui.has_method("show_enemy_hand"):
		combat_ui.show_enemy_hand(enemy)
	
	# Process enemy decisions
	_process_enemy_turn(enemy)

func _process_enemy_turn(enemy: Combatant):
	"""Process enemy AI decisions"""
	if not enemy.is_alive():
		_finish_enemy_turn(enemy)
		return
	
	if not enemy.has_usable_dice():
		print("  %s has no usable dice" % enemy.combatant_name)
		_finish_enemy_turn(enemy)
		return
	
	# Get AI decision
	var decision = EnemyAI.decide(
		enemy.actions,
		enemy.get_available_dice(),
		enemy.ai_strategy
	)
	
	if not decision:
		print("  %s couldn't decide" % enemy.combatant_name)
		_finish_enemy_turn(enemy)
		return
	
	print("  🤖 %s decides: %s with %d dice" % [
		enemy.combatant_name,
		decision.action.get("name", "?"),
		decision.dice.size()
	])
	
	# Execute with animation
	_animate_enemy_action(enemy, decision)

func _animate_enemy_action(enemy: Combatant, decision: EnemyAI.Decision):
	"""Animate enemy placing dice and executing action"""
	combat_state = CombatState.ANIMATING
	
	# Prepare action
	enemy.prepare_action(decision.action, decision.dice)
	
	# Show action in UI
	if combat_ui and combat_ui.has_method("show_enemy_action"):
		combat_ui.show_enemy_action(enemy, decision.action)
	
	# Animate each die placement
	for i in range(decision.dice.size()):
		var die = decision.dice[i]
		
		if combat_ui and combat_ui.has_method("animate_enemy_die_placement"):
			await combat_ui.animate_enemy_die_placement(enemy, die, i)
		else:
			await get_tree().create_timer(enemy.dice_drag_duration).timeout
		
		enemy.consume_action_die(die)
		
		# Refresh enemy hand display
		if combat_ui and combat_ui.has_method("refresh_enemy_hand"):
			combat_ui.refresh_enemy_hand(enemy)
	
	# Short pause before execution
	await get_tree().create_timer(0.3).timeout
	
	# Execute action
	var result = enemy.execute_prepared_action()
	var action_type = decision.action.get("action_type", 0)
	
	match action_type:
		0:  # ATTACK
			print("  💥 %s attacks player for %d!" % [enemy.combatant_name, result])
			player_combatant.take_damage(result)
			_update_player_health()
			if _check_player_death():
				return
		1:  # DEFEND
			print("  🛡️ %s defends" % enemy.combatant_name)
		2:  # HEAL
			print("  💚 %s heals for %d" % [enemy.combatant_name, result])
			enemy.heal(result)
			_update_enemy_health(enemy_combatants.find(enemy))
	
	# Delay before next action
	await get_tree().create_timer(enemy.action_delay).timeout
	
	# Continue turn (might have more dice)
	combat_state = CombatState.ENEMY_TURN
	_process_enemy_turn(enemy)

func _finish_enemy_turn(enemy: Combatant):
	"""Finish enemy's turn"""
	print("  %s's turn complete" % enemy.combatant_name)
	
	if combat_ui and combat_ui.has_method("hide_enemy_hand"):
		combat_ui.hide_enemy_hand()
	
	enemy.end_turn()
	_end_current_turn()

func _on_combatant_turn_completed(combatant: Combatant):
	"""Signal handler for turn completion"""
	pass  # Handled by _finish_enemy_turn

# ============================================================================
# DAMAGE CALCULATION
# ============================================================================

func _calculate_damage(action_data: Dictionary) -> int:
	"""Calculate damage from action data"""
	var base = action_data.get("base_damage", 0)
	var mult = action_data.get("damage_multiplier", 1.0)
	var placed_dice: Array = action_data.get("placed_dice", [])
	
	var dice_total = 0
	for die in placed_dice:
		if die is DieResource:
			dice_total += die.get_total_value()
	
	return int(base + (dice_total * mult))

# ============================================================================
# HEALTH MANAGEMENT
# ============================================================================

func _on_player_health_changed(current: int, maximum: int):
	if player:
		player.current_hp = current
	_update_player_health()

func _on_enemy_health_changed(current: int, maximum: int, enemy_index: int):
	_update_enemy_health(enemy_index)

func _on_enemy_died(enemy: Combatant):
	print("☠️ %s defeated!" % enemy.combatant_name)
	_check_combat_end()

func _on_player_died():
	print("💀 Player defeated!")
	end_combat(false)

func _update_player_health():
	if combat_ui and combat_ui.has_method("update_player_health"):
		combat_ui.update_player_health(player_combatant.current_health, player_combatant.max_health)

func _update_enemy_health(index: int):
	if combat_ui and combat_ui.has_method("update_enemy_health"):
		if index >= 0 and index < enemy_combatants.size():
			var enemy = enemy_combatants[index]
			combat_ui.update_enemy_health(index, enemy.current_health, enemy.max_health)

func _check_player_death() -> bool:
	if player_combatant.current_health <= 0:
		end_combat(false)
		return true
	return false

func _check_enemy_death(enemy: Combatant):
	if not enemy.is_alive():
		_check_combat_end()

func _get_first_living_enemy() -> Combatant:
	for enemy in enemy_combatants:
		if enemy.is_alive():
			return enemy
	return null

# ============================================================================
# COMBAT END
# ============================================================================

func end_combat(player_won: bool):
	"""End combat"""
	print("\n=== COMBAT ENDED ===")
	combat_state = CombatState.ENDED
	
	if player_won:
		print("🎉 Victory!")
	else:
		print("💀 Defeat!")
	
	combat_ended.emit(player_won)

func _on_combat_ended(player_won: bool):
	"""Cleanup after combat"""
	if player and player_combatant:
		player.current_hp = player_combatant.current_health
	
	await get_tree().create_timer(2.0).timeout
	
	if GameManager and GameManager.has_method("on_combat_ended"):
		GameManager.on_combat_ended(player_won)
	elif GameManager and GameManager.has_method("load_map_scene"):
		GameManager.load_map_scene()
