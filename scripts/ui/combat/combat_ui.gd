# combat_ui.gd - Combat UI with action fields, dice display, and enemy turn support
extends CanvasLayer

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var action_fields_grid = $MarginContainer/VBox/ActionFieldsArea/CenterContainer/ActionFieldsGrid

# Found dynamically from scene
var player_health_display = null
var enemy_health_display = null
var dice_pool_display = null
var end_turn_button: Button = null

# Action fields (pre-created in scene)
var action_fields: Array[ActionField] = []

# Action buttons (existing in scene)
var action_buttons_container: HBoxContainer = null
var confirm_button: Button = null
var cancel_button: Button = null

# ============================================================================
# ENEMY TURN DISPLAY
# ============================================================================
var enemy_hand_container: Control = null
var enemy_action_label: Label = null
var enemy_dice_visuals: Array[Control] = []
var current_enemy_display: Combatant = null

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var enemy = null  # Primary enemy (for backwards compatibility)
var enemies: Array = []  # All enemies
var action_manager: ActionManager = null
var selected_action_field: ActionField = null

# ============================================================================
# SIGNALS
# ============================================================================
signal action_confirmed(action_data: Dictionary)
signal turn_ended()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("🎮 CombatUI initializing...")
	
	# Find UI nodes from scene
	find_ui_nodes()
	
	# Collect all action field nodes
	discover_action_fields()
	
	# Setup action buttons (connect existing, don't create new)
	setup_action_buttons()
	
	print("🎮 CombatUI ready")

func find_ui_nodes():
	"""Find UI nodes in the scene tree"""
	print("  🔍 Finding UI nodes...")
	
	# Find health displays
	player_health_display = get_node_or_null("MarginContainer/VBox/TopBar/PlayerHealth")
	enemy_health_display = get_node_or_null("MarginContainer/VBox/TopBar/EnemyHealth")
	
	if player_health_display:
		print("    ✅ Player health display found")
	if enemy_health_display:
		print("    ✅ Enemy health display found")
	
	# Find dice pool display
	dice_pool_display = get_node_or_null("MarginContainer/VBox/DicePoolArea/DicePoolDisplay")
	if dice_pool_display:
		print("    ✅ Dice pool display found")
	
	# Find action buttons container (existing in scene)
	action_buttons_container = get_node_or_null("MarginContainer/VBox/ButtonArea/VBoxContainer/ActionButtonsContainer")
	if action_buttons_container:
		confirm_button = action_buttons_container.get_node_or_null("ConfirmButton")
		cancel_button = action_buttons_container.get_node_or_null("CancelButton")
		print("    ✅ Action buttons container found")
		if confirm_button:
			print("      ✅ Confirm button found")
		if cancel_button:
			print("      ✅ Cancel button found")
	else:
		print("    ⚠️ Action buttons container NOT found!")
	
	# Find end turn button
	end_turn_button = get_node_or_null("MarginContainer/VBox/ButtonArea/VBoxContainer/EndTurnButton")
	if end_turn_button:
		print("    ✅ End turn button found")

func discover_action_fields():
	"""Find all pre-created action fields in the grid"""
	print("  🔍 Discovering action fields...")
	
	if not action_fields_grid:
		print("    ⚠️ Action fields grid not found!")
		return
	
	for i in range(16):
		var field = action_fields_grid.get_node_or_null("ActionField" + str(i + 1))
		if field and field is ActionField:
			action_fields.append(field)
			# Connect signals
			if not field.action_selected.is_connected(_on_action_field_selected):
				field.action_selected.connect(_on_action_field_selected)
			if not field.action_confirmed.is_connected(_on_action_field_confirmed):
				field.action_confirmed.connect(_on_action_field_confirmed)
			if not field.dice_returned.is_connected(_on_dice_returned):
				field.dice_returned.connect(_on_dice_returned)
	
	print("    ✅ Found %d action fields" % action_fields.size())

func setup_action_buttons():
	"""Connect existing action buttons and set initial state"""
	print("  🔘 Setting up action buttons...")
	
	# Connect confirm button
	if confirm_button:
		if not confirm_button.pressed.is_connected(_on_confirm_pressed):
			confirm_button.pressed.connect(_on_confirm_pressed)
		print("    ✅ Confirm button connected")
	else:
		print("    ⚠️ Confirm button not found!")
	
	# Connect cancel button
	if cancel_button:
		if not cancel_button.pressed.is_connected(_on_cancel_pressed):
			cancel_button.pressed.connect(_on_cancel_pressed)
		print("    ✅ Cancel button connected")
	else:
		print("    ⚠️ Cancel button not found!")
	
	# Hide buttons initially
	if action_buttons_container:
		action_buttons_container.hide()
		print("    ✅ Action buttons hidden initially")

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
	
	# Create ActionManager if needed
	if not action_manager:
		action_manager = ActionManager.new()
		action_manager.name = "ActionManager"
		add_child(action_manager)
		if not action_manager.actions_changed.is_connected(refresh_action_fields):
			action_manager.actions_changed.connect(refresh_action_fields)
	
	# Initialize ActionManager with player
	action_manager.initialize(player)
	
	# Setup health displays
	setup_health_displays()
	
	# Setup dice pool (HAND mode for combat)
	setup_dice_pool()
	
	# Initial field refresh
	refresh_action_fields()
	
	# Connect end turn button
	if end_turn_button and not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)
		print("  ✅ End turn button connected")
	
	print("🎮 CombatUI initialization complete")

# ============================================================================
# HEALTH DISPLAYS
# ============================================================================

func setup_health_displays():
	"""Setup health display components"""
	print("  💚 Setting up health displays...")
	
	# Player health
	if player_health_display and player_health_display.has_method("initialize"):
		player_health_display.initialize("Player", player.current_hp, player.max_hp, Color.RED)
		print("    ✅ Player health display initialized")
	
	# Enemy health (primary enemy)
	if enemy_health_display and enemy_health_display.has_method("initialize"):
		var enemy_hp = 100
		var enemy_max = 100
		var enemy_name = "Enemy"
		
		if enemy:
			if "current_health" in enemy:
				enemy_hp = enemy.current_health
				enemy_max = enemy.max_health
			if "combatant_name" in enemy:
				enemy_name = enemy.combatant_name
		
		enemy_health_display.initialize(enemy_name, enemy_hp, enemy_max, Color.ORANGE)
		print("    ✅ Enemy health display initialized")

func update_player_health(current: int, maximum: int):
	"""Update player health display"""
	if player_health_display and player_health_display.has_method("update_health"):
		player_health_display.update_health(current, maximum)

func update_enemy_health(enemy_index: int, current: int, maximum: int):
	"""Update an enemy's health display"""
	# For now, just update the primary enemy display
	if enemy_index == 0 and enemy_health_display:
		if enemy_health_display.has_method("update_health"):
			enemy_health_display.update_health(current, maximum)
		elif enemy_health_display.has_method("update_values"):
			enemy_health_display.update_values(current, maximum)

# ============================================================================
# DICE POOL / HAND DISPLAY
# ============================================================================

func setup_dice_pool():
	"""Setup dice pool display (shows HAND in combat)"""
	print("  🎲 Setting up combat hand display...")
	
	if not dice_pool_display:
		print("    ⚠️ Dice pool display not found!")
		return
	
	# Debug info
	if player and player.dice_pool:
		print("    📊 Player dice_pool type: %s" % player.dice_pool.get_class())
		print("    📊 Player dice_pool instance ID: %d" % player.dice_pool.get_instance_id())
		print("    📊 Pool dice count: %d" % player.dice_pool.dice.size())
		print("    📊 Hand dice count: %d" % player.dice_pool.hand.size() if "hand" in player.dice_pool else 0)
		print("    📊 Pool contents:")
		for i in range(player.dice_pool.dice.size()):
			var die = player.dice_pool.dice[i]
			print("      [%d] %s (D%d) from %s" % [i, die.display_name, die.die_type, die.source])
	
	# If using DiceGrid, set it to HAND mode
	if dice_pool_display.has_method("set") and "grid_mode" in dice_pool_display:
		dice_pool_display.grid_mode = 1  # HAND mode
		print("    ✅ Set to HAND mode")
	
	if dice_pool_display.has_method("initialize"):
		if player and player.dice_pool:
			dice_pool_display.initialize(player.dice_pool)
			print("    ✅ Combat hand display initialized")

func refresh_dice_pool():
	"""Refresh the dice pool/hand display"""
	if dice_pool_display and dice_pool_display.has_method("refresh"):
		dice_pool_display.refresh()

# ============================================================================
# TURN MANAGEMENT
# ============================================================================

func on_turn_start():
	"""Called at start of player turn"""
	print("🎮 CombatUI: Player turn started")
	
	# Refresh the hand display
	refresh_dice_pool()
	
	# Reset all action fields (return any placed dice)
	for field in action_fields:
		if field.visible and field.has_method("cancel_action"):
			if field.placed_dice.size() > 0:
				field.cancel_action()
	
	# Hide action buttons
	if action_buttons_container:
		action_buttons_container.hide()
	
	# Enable end turn button
	if end_turn_button:
		end_turn_button.disabled = false
	
	# Show player dice pool
	if dice_pool_display:
		dice_pool_display.show()
	
	# Hide enemy hand if showing
	hide_enemy_hand()
	
	# Clear selection
	selected_action_field = null

func set_player_turn(is_player: bool):
	"""Update UI for whose turn it is"""
	if is_player:
		# Enable player controls
		if end_turn_button:
			end_turn_button.disabled = false
		# Show player hand
		if dice_pool_display:
			dice_pool_display.show()
		# Hide enemy hand
		hide_enemy_hand()
	else:
		# Disable player controls
		if end_turn_button:
			end_turn_button.disabled = true
		if action_buttons_container:
			action_buttons_container.hide()
		# Hide player dice pool (enemy turn will show enemy hand)
		if dice_pool_display:
			dice_pool_display.hide()

# ============================================================================
# ACTION FIELD MANAGEMENT
# ============================================================================

func refresh_action_fields():
	"""Update visible action fields with player's current actions"""
	print("  ⚔️ Refreshing action fields...")
	
	if not action_manager:
		print("    ⚠️ No action_manager!")
		return
	
	# Get all actions
	var item_actions = action_manager.get_item_actions()
	var skill_actions = action_manager.get_skill_actions()
	var all_actions = item_actions + skill_actions
	
	print("    Total actions: %d (items: %d, skills: %d)" % [all_actions.size(), item_actions.size(), skill_actions.size()])
	
	# Update each action field
	for i in range(action_fields.size()):
		var field = action_fields[i]
		
		if i < all_actions.size():
			# Show and configure this field
			var action_data = all_actions[i]
			if field.has_method("configure_from_dict"):
				field.configure_from_dict(action_data)
			field.show()
			print("      Field %d: %s (visible)" % [i, action_data.get("name")])
		else:
			# Hide unused fields
			field.hide()
	
	print("    ✅ Action fields refreshed")

# ============================================================================
# ACTION FIELD INTERACTION
# ============================================================================

func _on_action_field_selected(field: ActionField):
	"""Action field was clicked or had die dropped"""
	print("🎯 Action field selected: %s" % field.action_name)
	
	# Deselect other fields
	deselect_all_fields()
	
	selected_action_field = field
	
	# Show action buttons
	if action_buttons_container:
		action_buttons_container.show()
		print("  ✅ Showing Confirm/Cancel buttons")
	
	# Disable end turn while action is pending
	if end_turn_button:
		end_turn_button.disabled = true

func _on_action_field_confirmed(action_data: Dictionary):
	"""Action field auto-confirmed (shouldn't happen with our flow)"""
	print("⚠️ Action field auto-confirmed: %s" % action_data.get("name"))

func deselect_all_fields():
	"""Deselect all action fields"""
	for field in action_fields:
		if field.visible:
			# Visual deselection if needed
			pass

func _on_dice_returned(die: DieResource):
	"""Die was returned from action field - restore to hand"""
	print("🔄 Die returned to hand: %s" % die.display_name)
	
	# Restore die to player's hand
	if player and player.dice_pool:
		if player.dice_pool.has_method("restore_to_hand"):
			player.dice_pool.restore_to_hand(die)
		elif player.dice_pool.has_method("restore_die"):
			player.dice_pool.restore_die(die)
	
	# Refresh hand display
	refresh_dice_pool()

# ============================================================================
# ACTION BUTTON HANDLERS
# ============================================================================

func _on_confirm_pressed():
	"""Confirm button pressed"""
	print("🔘 Confirm button clicked!")
	
	if not selected_action_field:
		print("  ❌ No action field selected!")
		return
	
	print("✅ Confirming action: %s" % selected_action_field.action_name)
	print("  Placed dice: %d" % selected_action_field.placed_dice.size())
	
	# Get the action data
	var action_data = {}
	if selected_action_field.has_method("get_action_data"):
		action_data = selected_action_field.get_action_data()
		print("  Action data: %s" % str(action_data))
	
	# Emit the action_confirmed signal
	action_confirmed.emit(action_data)
	print("  ✅ action_confirmed signal emitted")
	
	# Hide action buttons
	if action_buttons_container:
		action_buttons_container.hide()
	
	# Enable end turn
	if end_turn_button:
		end_turn_button.disabled = false
	
	# Clear placed dice from the field (they were consumed)
	if selected_action_field.has_method("clear_placed_dice"):
		selected_action_field.clear_placed_dice()
	
	selected_action_field = null
	print("  ✅ Confirm complete")

func _on_cancel_pressed():
	"""Cancel button pressed"""
	if not selected_action_field:
		return
	
	print("❌ Canceling action: %s" % selected_action_field.action_name)
	
	# Cancel the action (returns dice to hand)
	if selected_action_field.has_method("cancel_action"):
		selected_action_field.cancel_action()
	
	# Hide action buttons
	if action_buttons_container:
		action_buttons_container.hide()
	
	# Enable end turn
	if end_turn_button:
		end_turn_button.disabled = false
	
	selected_action_field = null

func _on_end_turn_pressed():
	"""End turn button pressed"""
	print("🎮 End turn button pressed")
	
	# Hide action buttons if showing
	if action_buttons_container:
		action_buttons_container.hide()
	
	# Clear any selected field
	selected_action_field = null
	
	turn_ended.emit()

# ============================================================================
# ENEMY TURN DISPLAY
# ============================================================================

func show_enemy_hand(enemy_combatant: Combatant):
	"""Show an enemy's dice hand"""
	current_enemy_display = enemy_combatant
	
	if not enemy_hand_container:
		_create_enemy_hand_display()
	
	enemy_hand_container.show()
	refresh_enemy_hand(enemy_combatant)
	
	if enemy_action_label:
		enemy_action_label.text = "%s's Turn" % enemy_combatant.combatant_name

func hide_enemy_hand():
	"""Hide enemy hand display"""
	if enemy_hand_container:
		enemy_hand_container.hide()
	current_enemy_display = null

func refresh_enemy_hand(enemy_combatant: Combatant):
	"""Refresh enemy dice display"""
	if not enemy_hand_container:
		return
	
	var dice_row = enemy_hand_container.get_node_or_null("DiceRow")
	if not dice_row:
		return
	
	# Clear existing
	for child in dice_row.get_children():
		child.queue_free()
	enemy_dice_visuals.clear()
	
	# Create visuals for each die in enemy's hand
	var dice_array = enemy_combatant.get_available_dice()
	for die in dice_array:
		var visual = _create_enemy_die_visual(die)
		dice_row.add_child(visual)
		enemy_dice_visuals.append(visual)

func _create_enemy_hand_display():
	"""Create the enemy hand display UI"""
	enemy_hand_container = VBoxContainer.new()
	enemy_hand_container.name = "EnemyHandDisplay"
	
	# Add some padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	enemy_hand_container.add_child(margin)
	
	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(inner_vbox)
	
	# Label showing whose turn / what action
	enemy_action_label = Label.new()
	enemy_action_label.name = "ActionLabel"
	enemy_action_label.text = "Enemy Turn"
	enemy_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_action_label.add_theme_font_size_override("font_size", 20)
	enemy_action_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	inner_vbox.add_child(enemy_action_label)
	
	# Dice row
	var dice_row = HBoxContainer.new()
	dice_row.name = "DiceRow"
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_row.add_theme_constant_override("separation", 10)
	inner_vbox.add_child(dice_row)
	
	# Add to scene - find the dice pool area
	var dice_area = get_node_or_null("MarginContainer/VBox/DicePoolArea")
	if dice_area:
		dice_area.add_child(enemy_hand_container)
	else:
		# Fallback: add directly
		var vbox = get_node_or_null("MarginContainer/VBox")
		if vbox:
			vbox.add_child(enemy_hand_container)
		else:
			add_child(enemy_hand_container)
	
	enemy_hand_container.hide()
	print("  ✅ Enemy hand display created")

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
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	
	var type_lbl = Label.new()
	type_lbl.text = "D%d" % die.die_type
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.add_theme_font_size_override("font_size", 14)
	type_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.7))
	vbox.add_child(type_lbl)
	
	var value_lbl = Label.new()
	value_lbl.text = str(die.get_total_value())
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.add_theme_font_size_override("font_size", 28)
	value_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(value_lbl)
	
	return panel

func show_enemy_action(enemy_combatant: Combatant, action: Dictionary):
	"""Show what action the enemy is using"""
	if enemy_action_label:
		enemy_action_label.text = "%s uses %s!" % [
			enemy_combatant.combatant_name, 
			action.get("name", "Attack")
		]

func animate_enemy_die_placement(enemy_combatant: Combatant, die: DieResource, die_index: int):
	"""Animate a die being consumed from enemy's hand"""
	# Find the die visual at this index
	if die_index >= enemy_dice_visuals.size():
		await get_tree().create_timer(0.4).timeout
		return
	
	var visual = enemy_dice_visuals[die_index]
	
	if not is_instance_valid(visual):
		await get_tree().create_timer(0.4).timeout
		return
	
	# Flash the die
	var flash_tween = create_tween()
	flash_tween.tween_property(visual, "modulate", Color(1.5, 1.5, 0.5), 0.15)
	flash_tween.tween_property(visual, "modulate", Color.WHITE, 0.15)
	await flash_tween.finished
	
	# Animate fade/shrink
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "modulate:a", 0.0, 0.3)
	tween.tween_property(visual, "scale", Vector2(0.5, 0.5), 0.3)
	tween.tween_property(visual, "position:y", visual.position.y - 20, 0.3)
	
	await tween.finished

# ============================================================================
# UTILITY
# ============================================================================

func show_action_buttons():
	"""Show the confirm/cancel buttons"""
	if action_buttons_container:
		action_buttons_container.show()

func hide_action_buttons():
	"""Hide the confirm/cancel buttons"""
	if action_buttons_container:
		action_buttons_container.hide()

func set_end_turn_enabled(enabled: bool):
	"""Enable or disable the end turn button"""
	if end_turn_button:
		end_turn_button.disabled = not enabled

func on_round_start(round_number: int):
	"""Called at start of each round"""
	print("🎮 CombatUI: Round %d started" % round_number)
	# Could show round indicator here
