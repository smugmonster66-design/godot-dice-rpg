# combat_manager.gd - Combat scene orchestrator
extends Node2D

# ============================================================================
# ENUMS
# ============================================================================
enum CombatState {
	PLAYER_TURN,
	AI_TURN,
	ANIMATION_PLAYING,
	GAME_OVER
}

# ============================================================================
# STATE
# ============================================================================
var current_state: CombatState = CombatState.PLAYER_TURN
var player: Player = null
var selected_action_field: Control = null

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var player_combatant = $PlayerCombatant
@onready var enemy_combatant = $EnemyCombatant
@onready var combat_ui = $CombatUILayer

# ============================================================================
# SIGNALS
# ============================================================================
signal turn_changed(new_state: CombatState)
signal combat_ended(player_won: bool)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("⚔️ CombatManager _ready")
	setup_connections()
	turn_changed.emit(current_state)

func initialize_combat(p_player: Player):
	"""Initialize combat with player"""
	print("⚔️ Initializing combat with player")
	player = p_player
	
	# Connect player signals
	if not player.hp_changed.is_connected(_on_player_hp_changed):
		player.hp_changed.connect(_on_player_hp_changed)
		print("  ✅ Connected hp_changed signal")
	
	if not player.player_died.is_connected(_on_player_died):
		player.player_died.connect(_on_player_died)
		print("  ✅ Connected player_died signal")
	
	# Sync player to visual combatant
	sync_player_to_combatant()
	
	# CRITICAL: Roll dice pool for combat
	if player.dice_pool:
		print("  🎲 Rolling player dice pool...")
		player.dice_pool.roll_all_dice()
		print("  🎲 Player has %d dice available" % player.dice_pool.get_available_count())
	else:
		print("  ⚠️ WARNING: Player has no dice pool!")
	
	# Initialize UI
	if combat_ui and combat_ui.has_method("initialize_ui"):
		print("  🎮 Initializing combat UI...")
		combat_ui.initialize_ui(player, enemy_combatant)
		print("  ✅ Combat UI initialized")
	else:
		print("  ⚠️ WARNING: Combat UI not found or missing initialize_ui method!")
	
	print("⚔️ Combat initialization complete")

func setup_connections():
	"""Connect signals"""
	print("⚔️ Setting up connections...")
	
	if player_combatant:
		if not player_combatant.health_changed.is_connected(_on_player_combatant_health_changed):
			player_combatant.health_changed.connect(_on_player_combatant_health_changed)
		print("  ✅ Player combatant connected")
	
	if enemy_combatant:
		if not enemy_combatant.died.is_connected(_on_enemy_died):
			enemy_combatant.died.connect(_on_enemy_died)
		print("  ✅ Enemy combatant connected")
	
	if combat_ui:
		if combat_ui.has_signal("action_confirmed"):
			if not combat_ui.action_confirmed.is_connected(_on_action_confirmed):
				combat_ui.action_confirmed.connect(_on_action_confirmed)
			print("  ✅ Combat UI action_confirmed connected")
		
		if combat_ui.has_signal("turn_ended"):
			if not combat_ui.turn_ended.is_connected(_on_turn_ended):
				combat_ui.turn_ended.connect(_on_turn_ended)
			print("  ✅ Combat UI turn_ended connected")

func sync_player_to_combatant():
	"""Sync player data to visual"""
	if player_combatant:
		player_combatant.max_health = player.max_hp
		player_combatant.current_health = player.current_hp
		if player_combatant.has_method("update_health_display"):
			player_combatant.update_health_display()
		print("  ✅ Synced player to combatant")

# ============================================================================
# COMBAT FLOW
# ============================================================================

func _on_action_confirmed(action_data: Dictionary):
	"""Execute confirmed action"""
	print("⚔️ Executing action: %s" % action_data.get("type", "unknown"))
	
	var action_type = action_data.get("type")
	var value = action_data.get("value", 0)
	var die = action_data.get("die")
	
	match action_type:
		0:  # ATTACK
			execute_attack(player, enemy_combatant, value)
		1:  # DEFEND
			execute_defend(player, value)
		2:  # HEAL
			execute_heal(player, value)
	
	# Consume die
	if die and player.dice_pool:
		player.dice_pool.consume_die(die)
		if combat_ui and combat_ui.has_method("refresh_dice_pool"):
			combat_ui.refresh_dice_pool()
	
	check_combat_end()

func _on_turn_ended():
	"""End current turn"""
	print("⚔️ Turn ended")
	end_turn()

func end_turn():
	"""Switch turns"""
	if current_state == CombatState.PLAYER_TURN:
		current_state = CombatState.AI_TURN
		print("  → AI turn")
		await get_tree().create_timer(0.5).timeout
		execute_ai_turn()
	else:
		current_state = CombatState.PLAYER_TURN
		print("  → Player turn")
		
		# Roll new dice
		if player and player.dice_pool:
			player.dice_pool.roll_all_dice()
			if combat_ui and combat_ui.has_method("refresh_dice_pool"):
				combat_ui.refresh_dice_pool()
		
		turn_changed.emit(current_state)

func execute_ai_turn():
	"""AI's turn logic"""
	print("🤖 AI thinking...")
	await get_tree().create_timer(1.0).timeout
	
	var action_value = randi_range(1, 6)
	
	if randf() < 0.7:
		print("🤖 AI attacks!")
		await get_tree().create_timer(0.5).timeout
		execute_attack(enemy_combatant, player, action_value)
	else:
		print("🤖 AI heals!")
		await get_tree().create_timer(0.5).timeout
		execute_heal(enemy_combatant, action_value)
	
	await get_tree().create_timer(0.5).timeout
	check_combat_end()
	
	if current_state != CombatState.GAME_OVER:
		await get_tree().create_timer(1.0).timeout
		end_turn()

# ============================================================================
# COMBAT ACTIONS
# ============================================================================

func execute_attack(attacker, target, dice_value: int):
	"""Execute attack"""
	var damage = dice_value
	
	# Add bonuses if attacker is player
	if attacker == player:
		damage += player.get_physical_damage_bonus()
		
		# Crit check
		if randf() * 100 < player.get_crit_chance():
			damage = int(damage * 1.5)
			print("💥 CRITICAL HIT!")
	
	print("%s attacks for %d damage" % [attacker.name if attacker is Node else "Player", damage])
	
	# Apply damage
	if target == player:
		player.take_damage(damage, false)
		sync_player_to_combatant()
		if player_combatant.has_method("flash_damage"):
			player_combatant.flash_damage()
	elif target is Node and target.has_method("take_damage"):
		target.take_damage(damage)

func execute_defend(defender, dice_value: int):
	"""Execute defend"""
	if defender == player:
		player.add_status_effect("block", dice_value)
		print("🛡️ Player gains %d Block" % dice_value)

func execute_heal(healer, dice_value: int):
	"""Execute heal"""
	var heal_amount = dice_value
	
	if healer == player:
		heal_amount += int(player.get_total_stat("intellect") * 0.5)
		player.heal(heal_amount)
		sync_player_to_combatant()
		if player_combatant.has_method("flash_heal"):
			player_combatant.flash_heal()
	elif healer is Node and healer.has_method("heal"):
		healer.heal(heal_amount)
	
	print("💚 Healed for %d" % heal_amount)

# ============================================================================
# COMBAT END
# ============================================================================

func check_combat_end():
	"""Check if combat should end"""
	if player and player.current_hp <= 0:
		current_state = CombatState.GAME_OVER
		combat_ended.emit(false)
		print("💀 Player defeated")
	elif enemy_combatant.current_health <= 0:
		current_state = CombatState.GAME_OVER
		combat_ended.emit(true)
		print("🎉 Enemy defeated")

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_player_hp_changed(current: int, maximum: int):
	"""Player HP changed"""
	sync_player_to_combatant()

func _on_player_died():
	"""Player died"""
	current_state = CombatState.GAME_OVER
	combat_ended.emit(false)

func _on_enemy_died():
	"""Enemy died"""
	current_state = CombatState.GAME_OVER
	combat_ended.emit(true)

func _on_player_combatant_health_changed(new_health: int, max_health: int):
	"""Visual combatant health changed - sync back to player"""
	if player and player.current_hp != new_health:
		player.current_hp = new_health
		player.hp_changed.emit(player.current_hp, player.max_hp)
