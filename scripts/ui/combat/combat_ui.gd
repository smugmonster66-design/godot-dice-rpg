# res://scripts/ui/combat/combat_ui.gd
# Combat UI - finds all nodes from scene, no programmatic creation
extends CanvasLayer

# ============================================================================
# NODE REFERENCES - All found from scene
# ============================================================================
var action_fields_grid: GridContainer = null
var player_health_display = null
var dice_pool_display = null
var end_turn_button: Button = null
var enemy_panel: EnemyPanel = null

# Action fields (pre-created in scene)
var action_fields: Array[ActionField] = []

# Action buttons (existing in scene)
var action_buttons_container: HBoxContainer = null
var confirm_button: Button = null
var cancel_button: Button = null

# Enemy turn display nodes
var enemy_hand_container: Control = null
var enemy_action_label: Label = null
var enemy_dice_visuals: Array[Control] = []
var current_enemy_display: Combatant = null

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var enemy = null  # Primary enemy (backwards compatibility)
var enemies: Array = []  # All enemies
var action_manager: ActionManager = null
var selected_action_field: ActionField = null

# Target selection
var selected_target_index: int = 0
var target_selection_active: bool = false

# ============================================================================
# SIGNALS
# ============================================================================
signal action_confirmed(action_data: Dictionary)
signal turn_ended()
signal target_selected(enemy: Combatant, index: int)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("🎮 CombatUI initializing...")
	
	# Find all UI nodes from scene
	_discover_all_nodes()
	
	# Connect signals
	_connect_all_signals()
	
	print("🎮 CombatUI ready")

func _discover_all_nodes():
	"""Find all UI nodes from the scene tree"""
	print("  🔍 Discovering UI nodes...")
	
	# Action fields grid
	action_fields_grid = find_child("ActionFieldsGrid", true, false) as GridContainer
	print("    ActionFieldsGrid: %s" % ("✓" if action_fields_grid else "✗"))
	
	# Player health display
	player_health_display = find_child("PlayerHealth", true, false)
	if not player_health_display:
		player_health_display = find_child("PlayerHealthDisplay", true, false)
	print("    PlayerHealth: %s" % ("✓" if player_health_display else "✗"))
	
	# Dice pool display
	dice_pool_display = find_child("DicePoolDisplay", true, false)
	if not dice_pool_display:
		dice_pool_display = find_child("DiceGrid", true, false)
	print("    DicePoolDisplay: %s" % ("✓" if dice_pool_display else "✗"))
	
	# End turn button
	end_turn_button = find_child("EndTurnButton", true, false) as Button
	print("    EndTurnButton: %s" % ("✓" if end_turn_button else "✗"))
	
	# Enemy panel
	enemy_panel = find_child("EnemyPanel", true, false) as EnemyPanel
	print("    EnemyPanel: %s" % ("✓" if enemy_panel else "✗"))
	
	# Action buttons container
	action_buttons_container = find_child("ActionButtonsContainer", true, false) as HBoxContainer
	if action_buttons_container:
		confirm_button = action_buttons_container.find_child("ConfirmButton", true, false) as Button
		cancel_button = action_buttons_container.find_child("CancelButton", true, false) as Button
	print("    ActionButtonsContainer: %s" % ("✓" if action_buttons_container else "✗"))
	print("      ConfirmButton: %s" % ("✓" if confirm_button else "✗"))
	print("      CancelButton: %s" % ("✓" if cancel_button else "✗"))
	
	# Enemy hand display (for enemy turns)
	enemy_hand_container = find_child("EnemyHandDisplay", true, false)
	if enemy_hand_container:
		enemy_action_label = enemy_hand_container.find_child("ActionLabel", true, false) as Label
	print("    EnemyHandDisplay: %s" % ("✓" if enemy_hand_container else "✗"))
	
	# Discover action fields
	_discover_action_fields()

func _discover_action_fields():
	"""Find all pre-created action fields"""
	action_fields.clear()
	
	if not action_fields_grid:
		print("    ⚠️ Cannot discover action fields - grid not found")
		return
	
	# Find ActionField nodes by name pattern
	for i in range(1, 17):  # ActionField1 through ActionField16
		var field = action_fields_grid.find_child("ActionField%d" % i, true, false) as ActionField
		if field:
			action_fields.append(field)
	
	# Fallback: find any ActionField children
	if action_fields.size() == 0:
		for child in action_fields_grid.get_children():
			if child is ActionField:
				action_fields.append(child)
	
	print("    ActionFields: %d found" % action_fields.size())

func _connect_all_signals():
	"""Connect signals from discovered nodes"""
	print("  🔗 Connecting signals...")
	
	# Action fields
	for field in action_fields:
		if field.has_signal("action_selected") and not field.action_selected.is_connected(_on_action_field_selected):
			field.action_selected.connect(_on_action_field_selected)
		if field.has_signal("action_confirmed") and not field.action_confirmed.is_connected(_on_action_field_confirmed):
			field.action_confirmed.connect(_on_action_field_confirmed)
		if field.has_signal("dice_returned") and not field.dice_returned.is_connected(_on_dice_returned):
			field.dice_returned.connect(_on_dice_returned)
	
	# Confirm/Cancel buttons
	if confirm_button and not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)
	if cancel_button and not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)
	
	# End turn button
	if end_turn_button and not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	# Enemy panel
	if enemy_panel:
		if not enemy_panel.enemy_selected.is_connected(_on_enemy_panel_selection):
			enemy_panel.enemy_selected.connect(_on_enemy_panel_selection)
		if not enemy_panel.selection_changed.is_connected(_on_target_selection_changed):
			enemy_panel.selection_changed.connect(_on_target_selection_changed)
	
	# Hide action buttons initially
	if action_buttons_container:
		action_buttons_container.hide()
	
	print("  ✅ Signals connected")

# ============================================================================
# INITIALIZATION WITH PLAYER/ENEMIES
# ============================================================================

func initialize_ui(p_player: Player, p_enemies):
	"""Initialize the UI with player and enemies"""
	print("🎮 CombatUI.initialize_ui called")
	player = p_player
	
	# Handle both single enemy and array
	if p_enemies is Array:
		enemies = p_enemies
		enemy = enemies[0] if enemies.size() > 0 else null
	elif p_enemies:
		enemies = [p_enemies]
		enemy = p_enemies
	else:
		enemies = []
		enemy = null
	
	print("  Enemies: %d" % enemies.size())
	
	# Initialize enemy panel
	if enemy_panel:
		enemy_panel.initialize_enemies(enemies)
		print("  ✅ Enemy panel initialized")
	else:
		print("  ⚠️ No enemy panel found")
	
	# Create ActionManager if needed
	if not action_manager:
		action_manager = ActionManager.new()
		action_manager.name = "ActionManager"
		add_child(action_manager)
		if action_manager.has_signal("actions_changed") and not action_manager.actions_changed.is_connected(refresh_action_fields):
			action_manager.actions_changed.connect(refresh_action_fields)
	
	# Initialize ActionManager with player
	action_manager.initialize(player)
	
	# Setup displays
	_setup_health_display()
	_setup_dice_pool()
	
	# Initial field refresh
	refresh_action_fields()
	
	print("🎮 CombatUI initialization complete")

func _setup_health_display():
	"""Setup health display"""
	if player_health_display and player_health_display.has_method("initialize"):
		player_health_display.initialize("Player", player.current_hp, player.max_hp, Color.RED)

func _setup_dice_pool():
	"""Setup dice pool display (HAND mode for combat)"""
	if not dice_pool_display:
		return
	
	# Set to HAND mode if supported
	if "grid_mode" in dice_pool_display:
		dice_pool_display.grid_mode = 1  # HAND mode
	
	if dice_pool_display.has_method("initialize") and player and player.dice_pool:
		dice_pool_display.initialize(player.dice_pool)

# ============================================================================
# HEALTH UPDATES
# ============================================================================

func update_player_health(current: int, maximum: int):
	"""Update player health display"""
	if player_health_display and player_health_display.has_method("update_health"):
		player_health_display.update_health(current, maximum)

func update_enemy_health(enemy_index: int, current: int, maximum: int):
	"""Update an enemy's health display"""
	if enemy_panel:
		enemy_panel.update_enemy_health(enemy_index, current, maximum)

# ============================================================================
# TARGET SELECTION SYSTEM
# ============================================================================

func enable_target_selection():
	"""Enable target selection mode"""
	target_selection_active = true
	
	if enemy_panel:
		enemy_panel.set_selection_enabled(true)
	
	_update_enemy_selection_visuals()

func disable_target_selection():
	"""Disable target selection mode"""
	target_selection_active = false
	
	if enemy_panel:
		enemy_panel.set_selection_enabled(false)
	
	# Remove selection shader from all enemies
	for e in enemies:
		if e and e.has_method("set_target_selected"):
			e.set_target_selected(false)

func get_selected_target() -> Combatant:
	"""Get the currently selected target enemy"""
	if enemy_panel:
		return enemy_panel.get_selected_enemy()
	return enemy

func get_selected_target_index() -> int:
	"""Get the selected target index"""
	if enemy_panel:
		return enemy_panel.get_selected_slot_index()
	return 0

func _update_enemy_selection_visuals():
	"""Update visual selection on enemies"""
	if not target_selection_active:
		return
	
	var selected_index = get_selected_target_index()
	
	for i in range(enemies.size()):
		var e = enemies[i]
		if e and e.has_method("set_target_selected"):
			e.set_target_selected(i == selected_index)

func _on_enemy_panel_selection(enemy_combatant: Combatant, slot_index: int):
	"""Handle enemy selection from panel"""
	print("🎯 Target selected: %s (slot %d)" % [enemy_combatant.combatant_name, slot_index])
	selected_target_index = slot_index
	
	_update_enemy_selection_visuals()
	target_selected.emit(enemy_combatant, slot_index)

func _on_target_selection_changed(slot_index: int):
	"""Handle selection change"""
	selected_target_index = slot_index
	_update_enemy_selection_visuals()

# ============================================================================
# TURN MANAGEMENT
# ============================================================================

func on_turn_start():
	"""Called at start of player turn"""
	print("🎮 CombatUI: Player turn started")
	
	# Refresh the hand display
	refresh_dice_pool()
	
	# Reset action fields
	for field in action_fields:
		if field.visible and field.has_method("cancel_action"):
			if field.placed_dice.size() > 0:
				field.cancel_action()
	
	# Hide action buttons
	if action_buttons_container:
		action_buttons_container.hide()
	
	# Disable target selection until action is selected
	disable_target_selection()
	
	# Enable end turn button
	if end_turn_button:
		end_turn_button.disabled = false
	
	# Show dice pool
	if dice_pool_display:
		dice_pool_display.show()
	
	# Hide enemy hand
	hide_enemy_hand()
	
	# Clear selection
	selected_action_field = null
	
	# Select first living enemy as default
	if enemy_panel:
		enemy_panel.select_first_living_enemy()

func set_player_turn(is_player: bool):
	"""Update UI for whose turn it is"""
	if is_player:
		if end_turn_button:
			end_turn_button.disabled = false
		if dice_pool_display:
			dice_pool_display.show()
		hide_enemy_hand()
	else:
		if end_turn_button:
			end_turn_button.disabled = true
		if action_buttons_container:
			action_buttons_container.hide()
		if dice_pool_display:
			dice_pool_display.hide()
		disable_target_selection()

func refresh_dice_pool():
	"""Refresh the dice pool/hand display"""
	if dice_pool_display and dice_pool_display.has_method("refresh"):
		dice_pool_display.refresh()

# ============================================================================
# ACTION FIELD MANAGEMENT
# ============================================================================

func refresh_action_fields():
	"""Update visible action fields with player's current actions"""
	if not action_manager:
		return
	
	var item_actions = action_manager.get_item_actions()
	var skill_actions = action_manager.get_skill_actions()
	var all_actions = item_actions + skill_actions
	
	for i in range(action_fields.size()):
		var field = action_fields[i]
		
		if i < all_actions.size():
			var action_data = all_actions[i]
			if field.has_method("configure_from_dict"):
				field.configure_from_dict(action_data)
			field.show()
		else:
			field.hide()

func _on_action_field_selected(field: ActionField):
	"""Action field was clicked or had die dropped"""
	print("🎯 Action field selected: %s" % field.action_name)
	
	selected_action_field = field
	
	# Enable target selection for attack actions
	var action_type = field.action_type
	if action_type == ActionField.ActionType.ATTACK:
		enable_target_selection()
	else:
		disable_target_selection()
	
	# Show action buttons
	if action_buttons_container:
		action_buttons_container.show()
	
	# Disable end turn while action pending
	if end_turn_button:
		end_turn_button.disabled = true

func _on_action_field_confirmed(action_data: Dictionary):
	"""Action field auto-confirmed"""
	pass

func _on_dice_returned(die: DieResource):
	"""Die was returned from action field"""
	if player and player.dice_pool:
		if player.dice_pool.has_method("restore_to_hand"):
			player.dice_pool.restore_to_hand(die)
		elif player.dice_pool.has_method("restore_die"):
			player.dice_pool.restore_die(die)
	
	refresh_dice_pool()

# ============================================================================
# ACTION BUTTON HANDLERS
# ============================================================================

func _on_confirm_pressed():
	"""Confirm button pressed"""
	if not selected_action_field:
		return
	
	print("✅ Confirming action: %s" % selected_action_field.action_name)
	
	# Get action data
	var action_data = {}
	if selected_action_field.has_method("get_action_data"):
		action_data = selected_action_field.get_action_data()
	
	# Add target for attack actions
	if selected_action_field.action_type == ActionField.ActionType.ATTACK:
		action_data["target_index"] = get_selected_target_index()
		action_data["target"] = get_selected_target()
	
	# Emit signal
	action_confirmed.emit(action_data)
	
	# Cleanup
	if action_buttons_container:
		action_buttons_container.hide()
	
	disable_target_selection()
	
	if end_turn_button:
		end_turn_button.disabled = false
	
	if selected_action_field.has_method("clear_placed_dice"):
		selected_action_field.clear_placed_dice()
	
	selected_action_field = null

func _on_cancel_pressed():
	"""Cancel button pressed"""
	if not selected_action_field:
		return
	
	print("❌ Canceling action: %s" % selected_action_field.action_name)
	
	if selected_action_field.has_method("cancel_action"):
		selected_action_field.cancel_action()
	
	if action_buttons_container:
		action_buttons_container.hide()
	
	disable_target_selection()
	
	if end_turn_button:
		end_turn_button.disabled = false
	
	selected_action_field = null

func _on_end_turn_pressed():
	"""End turn button pressed"""
	print("🎮 End turn pressed")
	
	if action_buttons_container:
		action_buttons_container.hide()
	
	disable_target_selection()
	selected_action_field = null
	
	turn_ended.emit()

# ============================================================================
# ENEMY TURN DISPLAY
# ============================================================================

func show_enemy_hand(enemy_combatant: Combatant):
	"""Show an enemy's dice hand"""
	current_enemy_display = enemy_combatant
	
	if enemy_hand_container:
		enemy_hand_container.show()
		_refresh_enemy_hand_display(enemy_combatant)
		
		if enemy_action_label:
			enemy_action_label.text = "%s's Turn" % enemy_combatant.combatant_name

func hide_enemy_hand():
	"""Hide enemy hand display"""
	if enemy_hand_container:
		enemy_hand_container.hide()
	current_enemy_display = null

func _refresh_enemy_hand_display(enemy_combatant: Combatant):
	"""Refresh enemy dice display"""
	if not enemy_hand_container:
		return
	
	var dice_row = enemy_hand_container.find_child("DiceRow", true, false)
	if not dice_row:
		return
	
	# Clear existing
	for child in dice_row.get_children():
		child.queue_free()
	enemy_dice_visuals.clear()
	
	# Create visuals
	var dice_array = enemy_combatant.get_available_dice()
	for die in dice_array:
		var visual = _create_enemy_die_visual(die)
		dice_row.add_child(visual)
		enemy_dice_visuals.append(visual)

func _create_enemy_die_visual(die: DieResource) -> Control:
	"""Create a simple die visual for enemy display"""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(70, 90)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.5, 0.2, 0.2, 0.95)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.8, 0.3, 0.3)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var type_lbl = Label.new()
	type_lbl.text = "D%d" % die.die_type
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_lbl)
	
	var value_lbl = Label.new()
	value_lbl.text = str(die.get_total_value())
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.add_theme_font_size_override("font_size", 28)
	vbox.add_child(value_lbl)
	
	return panel

func show_enemy_action(enemy_combatant: Combatant, action: Dictionary):
	"""Show what action the enemy is using"""
	if enemy_action_label:
		enemy_action_label.text = "%s uses %s!" % [
			enemy_combatant.combatant_name,
			action.get("name", "Attack")
		]

func animate_enemy_die_placement(_enemy_combatant: Combatant, _die: DieResource, die_index: int):
	"""Animate a die being consumed"""
	if die_index >= enemy_dice_visuals.size():
		await get_tree().create_timer(0.4).timeout
		return
	
	var visual = enemy_dice_visuals[die_index]
	
	if not is_instance_valid(visual):
		await get_tree().create_timer(0.4).timeout
		return
	
	# Flash
	var flash_tween = create_tween()
	flash_tween.tween_property(visual, "modulate", Color(1.5, 1.5, 0.5), 0.15)
	flash_tween.tween_property(visual, "modulate", Color.WHITE, 0.15)
	await flash_tween.finished
	
	# Fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "modulate:a", 0.0, 0.3)
	tween.tween_property(visual, "scale", Vector2(0.5, 0.5), 0.3)
	
	await tween.finished

func on_enemy_died(enemy_index: int):
	"""Handle enemy death"""
	if enemy_panel:
		enemy_panel.on_enemy_died(enemy_index)
