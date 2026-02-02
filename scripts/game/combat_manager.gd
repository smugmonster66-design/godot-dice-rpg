# res://scripts/game/combat_manager.gd
# Combat manager - handles combat flow with encounter spawning
extends Node2D

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var encounter_spawner: EncounterSpawner = $EncounterSpawner

var player_combatant: Combatant = null
var enemy_combatants: Array[Combatant] = []
var combat_ui = null

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var current_encounter: CombatEncounter = null
var _combat_initialized: bool = false  # Add this line

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
	
	# Find nodes
	find_combat_nodes()
	
	# Setup encounter spawner
	setup_encounter_spawner()
	
	# Setup UI connections
	setup_ui_connections()
	
	# Check for pending encounter from GameManager
	await get_tree().process_frame
	check_pending_encounter()

func find_combat_nodes():
	"""Find combat nodes in the scene tree"""
	print("🔍 Finding combat nodes...")
	
	# Find player combatant
	player_combatant = find_child("PlayerCombatant", true, false) as Combatant
	if player_combatant:
		player_combatant.is_player_controlled = true
		print("  ✅ Player combatant found")
	else:
		push_error("  ❌ Player combatant NOT FOUND")
	
	# Find encounter spawner
	if not encounter_spawner:
		encounter_spawner = find_child("EncounterSpawner", true, false) as EncounterSpawner
	if not encounter_spawner:
		# Create one if not found
		encounter_spawner = EncounterSpawner.new()
		encounter_spawner.name = "EncounterSpawner"
		add_child(encounter_spawner)
		print("  ✅ Created EncounterSpawner")
	else:
		print("  ✅ EncounterSpawner found")
	
	# Find UI
	combat_ui = find_child("CombatUILayer", true, false)
	if not combat_ui:
		combat_ui = find_child("CombatUI", true, false)
	print("  CombatUI: %s" % ("✓" if combat_ui else "✗"))

func setup_encounter_spawner():
	"""Setup encounter spawner signals"""
	if encounter_spawner:
		if not encounter_spawner.enemies_spawned.is_connected(_on_enemies_spawned):
			encounter_spawner.enemies_spawned.connect(_on_enemies_spawned)
		if not encounter_spawner.spawn_failed.is_connected(_on_spawn_failed):
			encounter_spawner.spawn_failed.connect(_on_spawn_failed)

func setup_ui_connections():
	"""Setup combat UI signal connections"""
	if combat_ui:
		if combat_ui.has_signal("action_confirmed") and not combat_ui.action_confirmed.is_connected(_on_action_confirmed):
			combat_ui.action_confirmed.connect(_on_action_confirmed)
		if combat_ui.has_signal("turn_ended") and not combat_ui.turn_ended.is_connected(_on_player_end_turn):
			combat_ui.turn_ended.connect(_on_player_end_turn)

func check_pending_encounter():
	"""Check if GameManager has a pending encounter"""
	if GameManager and GameManager.pending_encounter:
		current_encounter = GameManager.pending_encounter
		GameManager.pending_encounter = null
		print("⚔️ Found pending encounter: %s" % current_encounter.encounter_name)
		
		if GameManager.player:
			initialize_combat(GameManager.player)

# ============================================================================
# ENCOUNTER SPAWNING
# ============================================================================

func _on_enemies_spawned(enemies: Array[Combatant]):
	"""Handle enemies spawned by EncounterSpawner"""
	enemy_combatants = enemies
	
	# Connect signals for each enemy
	for i in range(enemy_combatants.size()):
		_connect_enemy_signals(enemy_combatants[i], i)
	
	print("⚔️ %d enemies ready for combat" % enemy_combatants.size())

func _on_spawn_failed(reason: String):
	"""Handle spawn failure"""
	push_error("⚔️ Encounter spawn failed: %s" % reason)

func _connect_enemy_signals(enemy: Combatant, index: int):
	"""Connect signals for an enemy combatant"""
	if not enemy.health_changed.is_connected(_on_enemy_health_changed):
		enemy.health_changed.connect(_on_enemy_health_changed.bind(index))
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died.bind(enemy))
	if not enemy.turn_completed.is_connected(_on_combatant_turn_completed):
		enemy.turn_completed.connect(_on_combatant_turn_completed.bind(enemy))

# ============================================================================
# COMBAT INITIALIZATION
# ============================================================================

func initialize_combat(p_player: Player):
	"""Initialize combat with player data"""
	print("⚔️ Initializing combat...")
	player = p_player
	combat_state = CombatState.INITIALIZING
	
	# Spawn enemies from encounter if we have one
	if current_encounter and encounter_spawner:
		encounter_spawner.spawn_encounter(current_encounter)
	
	# Continue initialization after spawning
	await get_tree().process_frame
	_finalize_combat_init(p_player)

func _finalize_combat_init(p_player: Player):
	"""Finalize combat initialization after enemies are ready"""
	if _combat_initialized:
		print("⚠️ Combat already initialized, skipping")
		return
	_combat_initialized = true
	
	player = p_player
	
	# Sync player to combatant
	_sync_player_to_combatant()
	
	# Connect player combatant signals
	if player_combatant:
		if not player_combatant.health_changed.is_connected(_on_player_health_changed):
			player_combatant.health_changed.connect(_on_player_health_changed)
		if not player_combatant.died.is_connected(_on_player_died):
			player_combatant.died.connect(_on_player_died)
	
	# Build turn order
	_build_turn_order()
	
	# Initialize UI
	if combat_ui:
		combat_ui.initialize_ui(player, enemy_combatants)
	
	# Connect cleanup
	if not combat_ended.is_connected(_on_combat_ended):
		combat_ended.connect(_on_combat_ended)
	
	print("⚔️ Combat initialization complete")
	print("  Turn order: %s" % [turn_order.map(func(c): return c.combatant_name)])
	
	# Start first round
	_start_round()

func _sync_player_to_combatant():
	"""Sync player stats to combatant"""
	if player and player_combatant:
		player_combatant.current_health = player.current_hp
		player_combatant.max_health = player.max_hp
		player_combatant.combatant_name = "Player"
		player_combatant.update_display()
		print("  ✅ Synced player to combatant")

func _build_turn_order():
	"""Build the turn order array"""
	turn_order.clear()
	
	# Check encounter settings for turn order
	var player_first = true
	if current_encounter:
		player_first = current_encounter.player_starts_first
	
	if player_first:
		turn_order.append(player_combatant)
		for enemy in enemy_combatants:
			if enemy.is_alive():
				turn_order.append(enemy)
	else:
		for enemy in enemy_combatants:
			if enemy.is_alive():
				turn_order.append(enemy)
		turn_order.append(player_combatant)

# ============================================================================
# TURN ORDER MANAGEMENT
# ============================================================================

func _start_round():
	"""Start a new round"""
	current_round += 1
	current_turn_index = 0
	
	print("\n⚔️ === ROUND %d ===" % current_round)
	
	# Check turn limit
	if current_encounter and current_encounter.turn_limit > 0:
		if current_round > current_encounter.turn_limit:
			print("⏰ Turn limit reached!")
			end_combat(false)
			return
	
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
	
	if _check_combat_end():
		return
	
	_start_round()

func _check_combat_end() -> bool:
	"""Check if combat should end"""
	if not player_combatant.is_alive():
		end_combat(false)
		return true
	
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
	
	if player and player.dice_pool:
		player.dice_pool.roll_hand()
	
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
	
	# Get target for damage calculation
	var target = action_data.get("target", null) as Combatant
	var target_index = action_data.get("target_index", 0)
	
	# Fallback to first living enemy if no target specified
	if not target or not target.is_alive():
		target = _get_first_living_enemy()
		target_index = enemy_combatants.find(target)
	
	# Calculate damage with attacker (player) and defender (target)
	var damage = _calculate_damage(action_data, player, target)
	
	print("⚔️ Player uses %s (type=%d, value=%d)" % [action_name, action_type, damage])
	
	match action_type:
		0:  # ATTACK
			if target:
				print("  → Attacking %s" % target.combatant_name)
				target.take_damage(damage)
				_update_enemy_health(target_index)
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
	
	if combat_ui and combat_ui.has_method("set_player_turn"):
		combat_ui.set_player_turn(false)
	
	enemy.start_turn()
	
	if combat_ui and combat_ui.has_method("show_enemy_hand"):
		combat_ui.show_enemy_hand(enemy)
	
	# Small delay to let UI update
	await get_tree().create_timer(0.3).timeout
	
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
	
	_animate_enemy_action(enemy, decision)

func _animate_enemy_action(enemy: Combatant, decision: EnemyAI.Decision):
	"""Animate enemy placing dice and executing action"""
	combat_state = CombatState.ANIMATING
	
	var action_name = decision.action.get("name", "Attack")
	
	enemy.prepare_action(decision.action, decision.dice)
	
	# Highlight the action field being used
	if combat_ui and combat_ui.has_method("highlight_enemy_action"):
		combat_ui.highlight_enemy_action(action_name)
	
	# Animate each die being used
	for i in range(decision.dice.size()):
		var die = decision.dice[i]
		
		# Find the FIRST VISIBLE die visual (not by index)
		var die_visual: Control = null
		if combat_ui and combat_ui.enemy_panel:
			for vis in combat_ui.enemy_panel.hand_dice_visuals:
				if is_instance_valid(vis) and vis.visible:
					die_visual = vis
					break
		
		# Animate die to action field - pass the actual die resource
		if combat_ui.has_method("animate_die_to_action_field"):
			await combat_ui.animate_die_to_action_field(die_visual, action_name, die)
		else:
			await get_tree().create_timer(enemy.dice_drag_duration).timeout
		
		enemy.consume_action_die(die)
	
	# Brief pause before action executes
	await get_tree().create_timer(0.3).timeout
	
	# Execute the action
	var action_data = decision.action.duplicate()
	action_data["placed_dice"] = decision.dice
	
	var action_type = decision.action.get("action_type", 0)
	
	match action_type:
		0:  # ATTACK
			var damage = _calculate_damage(action_data, enemy, player)
			print("  💥 %s attacks player for %d!" % [enemy.combatant_name, damage])
			player_combatant.take_damage(damage)
			_update_player_health()
			if _check_player_death():
				return
		1:  # DEFEND
			print("  🛡️ %s defends" % enemy.combatant_name)
		2:  # HEAL
			var heal_amount = _calculate_heal(action_data, enemy)
			print("  💚 %s heals for %d" % [enemy.combatant_name, heal_amount])
			enemy.heal(heal_amount)
			_update_enemy_health(enemy_combatants.find(enemy))
	
	# Flash the action field to show it executed
	if combat_ui and combat_ui.has_method("animate_enemy_action_confirm"):
		await combat_ui.animate_enemy_action_confirm(action_name)
	
	enemy.action_executed.emit(decision.action, 0)
	
	await get_tree().create_timer(enemy.action_delay).timeout
	
	combat_state = CombatState.ENEMY_TURN
	_process_enemy_turn(enemy)

func _finish_enemy_turn(enemy: Combatant):
	"""Finish enemy's turn"""
	print("  %s's turn complete" % enemy.combatant_name)
	
	if combat_ui and combat_ui.has_method("hide_enemy_hand"):
		combat_ui.hide_enemy_hand()
	
	enemy.end_turn()
	_end_current_turn()

func _on_combatant_turn_completed(_combatant: Combatant):
	pass

# ============================================================================
# DAMAGE CALCULATION
# ============================================================================

func _calculate_damage(action_data: Dictionary, attacker, defender) -> int:
	"""Calculate damage using the new system"""
	var placed_dice: Array = action_data.get("placed_dice", [])
	
	# Get dice values
	var dice_values: Array[int] = []
	for die in placed_dice:
		if die is DieResource:
			dice_values.append(die.get_total_value())
	
	# Get action effects (from Action resource if available)
	var effects: Array[ActionEffect] = []
	if action_data.has("action_resource") and action_data.action_resource is Action:
		effects = action_data.action_resource.effects
	elif action_data.has("effects") and action_data.effects is Array:
		for effect in action_data.effects:
			if effect is ActionEffect:
				effects.append(effect)
	
	# Legacy fallback - create a basic damage effect if no effects found
	if effects.is_empty():
		var legacy_effect = ActionEffect.new()
		legacy_effect.effect_type = ActionEffect.EffectType.DAMAGE
		legacy_effect.base_damage = action_data.get("base_damage", 0)
		legacy_effect.damage_multiplier = action_data.get("damage_multiplier", 1.0)
		legacy_effect.dice_count = dice_values.size()
		effects = [legacy_effect]
	
	# Get attacker's affix manager (players have one, enemies might not)
	var attacker_affixes: AffixPoolManager = null
	if attacker is Player:
		attacker_affixes = attacker.affix_manager
	elif attacker is Combatant and attacker.has_method("get_affix_manager"):
		attacker_affixes = attacker.get_affix_manager()
	
	# Get defender stats
	var defender_stats = _get_defender_stats(defender)
	
	# Use CombatCalculator if available
	if attacker_affixes:
		var result = CombatCalculator.calculate_attack_damage(
			attacker_affixes,
			effects,
			dice_values,
			defender_stats
		)
		return result.total_damage
	
	# Simple fallback calculation
	var dice_total = 0
	for v in dice_values:
		dice_total += v
	
	var base = action_data.get("base_damage", 0)
	var mult = action_data.get("damage_multiplier", 1.0)
	var raw_damage = int((dice_total + base) * mult)
	
	# Apply armor
	var armor = defender_stats.get("armor", 0)
	return max(0, raw_damage - armor)

func _calculate_heal(action_data: Dictionary, healer) -> int:
	"""Calculate healing amount"""
	var placed_dice: Array = action_data.get("placed_dice", [])
	
	# Get dice values
	var dice_total = 0
	for die in placed_dice:
		if die is DieResource:
			dice_total += die.get_total_value()
	
	# Get heal values from action
	var base_heal = action_data.get("base_damage", 0)
	var multiplier = action_data.get("damage_multiplier", 1.0)
	
	# Check for ActionEffect-based healing
	var effects: Array[ActionEffect] = []
	if action_data.has("action_resource") and action_data.action_resource is Action:
		effects = action_data.action_resource.effects
	elif action_data.has("effects"):
		effects = action_data.effects
	
	# If we have heal effects, use those
	for effect in effects:
		if effect and effect.effect_type == ActionEffect.EffectType.HEAL:
			var effect_dice_total = 0
			if effect.heal_uses_dice:
				effect_dice_total = dice_total
			return int((effect_dice_total + effect.base_heal) * effect.heal_multiplier)
	
	# Legacy fallback
	return int((dice_total + base_heal) * multiplier)

func _get_defender_stats(defender) -> Dictionary:
	"""Get defense stats from defender"""
	if defender is Player:
		return defender.get_defense_stats()
	elif defender is Combatant:
		return {
			"armor": defender.armor,
			"fire_resist": defender.get("fire_resist") if defender.get("fire_resist") else 0,
			"ice_resist": defender.get("ice_resist") if defender.get("ice_resist") else 0,
			"shock_resist": defender.get("shock_resist") if defender.get("shock_resist") else 0,
			"poison_resist": defender.get("poison_resist") if defender.get("poison_resist") else 0,
			"shadow_resist": defender.get("shadow_resist") if defender.get("shadow_resist") else 0,
		}
	return {"armor": 0}

# ============================================================================
# HEALTH MANAGEMENT
# ============================================================================

func _on_player_health_changed(current: int, maximum: int):
	if player:
		player.current_hp = current
	_update_player_health()

func _on_enemy_health_changed(_current: int, _maximum: int, enemy_index: int):
	_update_enemy_health(enemy_index)

func _update_player_health():
	"""Update player health display"""
	if combat_ui and player_combatant:
		combat_ui.update_player_health(player_combatant.current_health, player_combatant.max_health)

func _update_enemy_health(enemy_index: int):
	"""Update enemy health display"""
	if combat_ui and enemy_index >= 0 and enemy_index < enemy_combatants.size():
		var enemy = enemy_combatants[enemy_index]
		combat_ui.update_enemy_health(enemy_index, enemy.current_health, enemy.max_health)

func _check_player_death() -> bool:
	"""Check if player died"""
	if not player_combatant.is_alive():
		end_combat(false)
		return true
	return false

func _check_enemy_death(enemy: Combatant):
	"""Check if enemy died and handle it"""
	if not enemy.is_alive():
		var index = enemy_combatants.find(enemy)
		if combat_ui:
			combat_ui.on_enemy_died(index)

func _on_enemy_died(enemy: Combatant):
	"""Handle enemy death"""
	print("☠️ %s defeated!" % enemy.combatant_name)
	
	var index = enemy_combatants.find(enemy)
	if combat_ui:
		combat_ui.on_enemy_died(index)
	
	_check_combat_end()

func _on_player_died():
	"""Handle player death"""
	print("☠️ Player defeated!")
	end_combat(false)

func _get_first_living_enemy() -> Combatant:
	"""Get first living enemy"""
	for enemy in enemy_combatants:
		if enemy.is_alive():
			return enemy
	return null

# ============================================================================
# COMBAT END
# ============================================================================

func end_combat(player_won: bool):
	print("\n=== COMBAT ENDED ===")
	combat_state = CombatState.ENDED
	_combat_initialized = false  # Reset for next combat
	
	if player_won:
		print("🎉 Victory!")
	else:
		print("💀 Defeat!")
	
	combat_ended.emit(player_won)

func _on_combat_ended(player_won: bool):
	"""Handle combat end cleanup"""
	if player_won:
		# Calculate rewards
		var total_exp = 0
		var total_gold = 0
		
		for enemy in enemy_combatants:
			var rewards = enemy.get_rewards()
			total_exp += rewards.experience
			total_gold += rewards.gold
		
		print("  Rewards: %d XP, %d Gold" % [total_exp, total_gold])
		
		# Apply rewards to player
		if player:
			player.gold += total_gold
			if player.active_class:
				player.active_class.add_experience(total_exp)
