# res://scripts/ui/combat/combat_ui.gd
# Combat UI - dynamically creates action fields in scrollable grid
extends CanvasLayer

# ============================================================================
# NODE REFERENCES - All found from scene
# ============================================================================
var action_fields_scroll: ScrollContainer = null
var action_fields_grid: GridContainer = null
var player_health_display = null
var dice_pool_display = null
var end_turn_button: Button = null
var enemy_panel: EnemyPanel = null

# Action field scene for dynamic creation
var action_field_scene: PackedScene = null

# Dynamically created action fields
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

# Enemy turn state
var is_enemy_turn: bool = false
var enemy_action_fields: Array[ActionField] = []

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
	
	# Load action field scene
	action_field_scene = load("res://scenes/ui/combat/action_field.tscn")
	if not action_field_scene:
		push_error("Failed to load action_field.tscn!")
	
	# Find all UI nodes from scene
	_discover_all_nodes()
	
	# Connect signals
	_connect_all_signals()
	
	print("🎮 CombatUI ready")

func _discover_all_nodes():
	"""Find all UI nodes from the scene tree"""
	print("  🔍 Discovering UI nodes...")
	
	# Ensure scrollable grid exists
	_ensure_scrollable_grid()
	
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

func _ensure_scrollable_grid():
	"""Find scrollable action grid from scene"""
	var fields_area = find_child("ActionFieldsArea", true, false)
	if not fields_area:
		push_error("ActionFieldsArea not found!")
		return
	
	# Find scroll container
	action_fields_scroll = fields_area.find_child("ActionFieldsScroll", true, false) as ScrollContainer
	if not action_fields_scroll:
		push_error("ActionFieldsScroll not found!")
		return
	
	# Find grid (inside CenterContainer)
	action_fields_grid = action_fields_scroll.find_child("ActionFieldsGrid", true, false) as GridContainer
	if not action_fields_grid:
		push_error("ActionFieldsGrid not found!")
		return
	
	# Configure scroll settings
	_configure_scroll_container()
	
	print("    ActionFieldsScroll: ✓")
	print("    ActionFieldsGrid: ✓")

func _configure_scroll_container():
	"""Configure scroll container settings"""
	if not action_fields_scroll:
		return
	
	# Hide scrollbars but allow scrolling
	action_fields_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_fields_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	
	# Make vertical scrollbar invisible
	var v_scrollbar = action_fields_scroll.get_v_scroll_bar()
	if v_scrollbar:
		v_scrollbar.modulate.a = 0

func _connect_all_signals():
	"""Connect signals from discovered nodes"""
	print("  🔗 Connecting signals...")
	
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
		if action_manager.has_signal("actions_changed") and not action_manager.actions_changed.is_connected(_on_actions_changed):
			action_manager.actions_changed.connect(_on_actions_changed)
	
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
	
	is_enemy_turn = false
	
	# Refresh the hand display
	refresh_dice_pool()
	
	# Reset action fields
	for field in action_fields:
		if field.has_method("cancel_action") and field.placed_dice.size() > 0:
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
	
	# Refresh player actions
	refresh_action_fields()
	
	# Select first living enemy as default
	if enemy_panel:
		enemy_panel.select_first_living_enemy()

func set_player_turn(is_player: bool):
	"""Update UI for whose turn it is"""
	is_enemy_turn = not is_player
	
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
# ACTION FIELD MANAGEMENT - PLAYER
# ============================================================================

func _on_actions_changed():
	"""Called when ActionManager rebuilds actions"""
	if not is_enemy_turn:
		refresh_action_fields()

func refresh_action_fields():
	"""Rebuild action fields grid from player's available actions"""
	if not action_manager or not action_fields_grid:
		print("⚠️ Cannot refresh action fields - missing manager or grid")
		return
	
	if is_enemy_turn:
		return  # Don't overwrite enemy actions
	
	# Clear existing fields
	for child in action_fields_grid.get_children():
		child.queue_free()
	action_fields.clear()
	
	# Get all actions (unified list, no categories)
	var all_actions = action_manager.get_actions()
	
	print("🎮 Creating %d player action fields" % all_actions.size())
	
	# Wait a frame for children to be freed
	await get_tree().process_frame
	
	# Create action field for each action
	for action_data in all_actions:
		var field = _create_action_field(action_data)
		if field:
			action_fields_grid.add_child(field)
			action_fields.append(field)
	
	# Show message if no actions
	if all_actions.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No actions available\nEquip items to gain actions"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		action_fields_grid.add_child(empty_label)

func _create_action_field(action_data: Dictionary) -> ActionField:
	"""Create a single action field from data"""
	if not action_field_scene:
		push_error("ActionField scene not loaded!")
		return null
	
	var field = action_field_scene.instantiate() as ActionField
	if not field:
		push_error("Failed to instantiate ActionField!")
		return null
	
	# Configure from data
	field.configure_from_dict(action_data)
	
	# Connect signals
	field.action_selected.connect(_on_action_field_selected)
	field.dice_returned.connect(_on_dice_returned)
	
	return field

func _on_action_field_selected(field: ActionField):
	"""Action field was clicked or had die dropped"""
	if is_enemy_turn:
		return  # Ignore during enemy turn
	
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
	"""Action was confirmed from field directly"""
	action_confirmed.emit(action_data)

func _on_dice_returned(die: DieResource):
	"""Die was returned from action field"""
	print("🎲 Die returned: %s" % die.display_name)
	# Dice pool will refresh automatically via signals

# ============================================================================
# ENEMY TURN DISPLAY - Action Fields
# ============================================================================

func show_enemy_actions(enemy_combatant: Combatant):
	"""Display enemy's available actions in the ActionFieldsGrid"""
	is_enemy_turn = true
	
	if not action_fields_grid:
		return
	
	# Clear existing fields
	for child in action_fields_grid.get_children():
		child.queue_free()
	action_fields.clear()
	enemy_action_fields.clear()
	
	# Wait for children to be freed
	await get_tree().process_frame
	
	# Get enemy's actions
	var actions = enemy_combatant.actions
	
	print("🎮 Showing %d enemy actions" % actions.size())
	
	# Create action field for each enemy action
	for action_data in actions:
		var field = _create_enemy_action_field(action_data)
		if field:
			action_fields_grid.add_child(field)
			action_fields.append(field)
			enemy_action_fields.append(field)
	
	# Show empty message if no actions
	if actions.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No actions"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		action_fields_grid.add_child(empty_label)

func _create_enemy_action_field(action_data: Dictionary) -> ActionField:
	"""Create an action field for enemy display (non-interactive)"""
	if not action_field_scene:
		push_error("ActionField scene not loaded!")
		return null
	
	var field = action_field_scene.instantiate() as ActionField
	if not field:
		push_error("Failed to instantiate ActionField!")
		return null
	
	# Configure from data
	field.configure_from_dict(action_data)
	
	# Disable player interaction
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	return field

func find_action_field_by_name(action_name: String) -> ActionField:
	"""Find an action field by its action name"""
	for field in action_fields:
		if field.action_name == action_name:
			return field
	return null

func highlight_enemy_action(action_name: String):
	"""Highlight the action field the enemy is using"""
	var field = find_action_field_by_name(action_name)
	if field:
		# Visual highlight
		var tween = create_tween()
		tween.tween_property(field, "modulate", Color(1.3, 1.2, 0.8), 0.2)

func animate_die_to_action_field(die_visual: Control, action_name: String) -> void:
	"""Animate a die moving from hand to action field"""
	var field = find_action_field_by_name(action_name)
	if not field or not is_instance_valid(die_visual):
		await get_tree().create_timer(0.3).timeout
		return
	
	# Get target position (center of action field)
	var target_pos = field.global_position + field.size / 2 - die_visual.size / 2
	
	# Flash the die
	var flash_tween = create_tween()
	flash_tween.tween_property(die_visual, "modulate", Color(1.5, 1.5, 0.5), 0.1)
	flash_tween.tween_property(die_visual, "modulate", Color.WHITE, 0.1)
	await flash_tween.finished
	
	# Move die to action field
	var move_tween = create_tween()
	move_tween.set_parallel(true)
	move_tween.tween_property(die_visual, "global_position", target_pos, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	move_tween.tween_property(die_visual, "scale", Vector2(0.7, 0.7), 0.35)
	await move_tween.finished
	
	# Fade out but DON'T free - panel will clean up later
	var fade_tween = create_tween()
	fade_tween.tween_property(die_visual, "modulate:a", 0.0, 0.15)
	await fade_tween.finished
	
	# Hide instead of free
	die_visual.hide()

func animate_enemy_action_confirm(action_name: String) -> void:
	"""Animate the enemy confirming their action"""
	var field = find_action_field_by_name(action_name)
	if not field:
		return
	
	# Flash confirm effect
	var tween = create_tween()
	tween.tween_property(field, "modulate", Color(1.5, 1.0, 0.5), 0.15)
	tween.tween_property(field, "modulate", Color.WHITE, 0.15)
	await tween.finished

func clear_enemy_turn_display():
	"""Clear enemy turn display and restore player actions"""
	is_enemy_turn = false
	enemy_action_fields.clear()

# ============================================================================
# ACTION BUTTONS
# ============================================================================

func _on_confirm_pressed():
	"""Confirm button pressed"""
	if not selected_action_field:
		return
	
	if not selected_action_field.is_ready_to_confirm():
		print("⚠️ Action not ready - need more dice")
		return
	
	# Build action data
	var action_data = {
		"name": selected_action_field.action_name,
		"action_type": selected_action_field.action_type,
		"base_damage": selected_action_field.base_damage,
		"damage_multiplier": selected_action_field.damage_multiplier,
		"placed_dice": selected_action_field.placed_dice.duplicate(),
		"source": selected_action_field.source,
		"action_resource": selected_action_field.action_resource,
		"target": get_selected_target(),
		"target_index": get_selected_target_index()
	}
	
	print("✅ Confirming action: %s with %d dice" % [action_data.name, action_data.placed_dice.size()])
	
	# Clear the action field
	selected_action_field.clear_dice()
	
	# Hide buttons
	if action_buttons_container:
		action_buttons_container.hide()
	
	# Re-enable end turn
	if end_turn_button:
		end_turn_button.disabled = false
	
	# Disable target selection
	disable_target_selection()
	
	# Clear selection
	selected_action_field = null
	
	# Emit signal
	action_confirmed.emit(action_data)

func _on_cancel_pressed():
	"""Cancel button pressed"""
	if selected_action_field:
		selected_action_field.cancel_action()
	
	selected_action_field = null
	
	if action_buttons_container:
		action_buttons_container.hide()
	
	if end_turn_button:
		end_turn_button.disabled = false
	
	disable_target_selection()

func _on_end_turn_pressed():
	"""End turn button pressed"""
	print("🎮 End turn pressed")
	
	# Return any placed dice
	for field in action_fields:
		if field.has_method("cancel_action") and field.placed_dice.size() > 0:
			field.cancel_action()
	
	if action_buttons_container:
		action_buttons_container.hide()
	
	turn_ended.emit()

# ============================================================================
# ENEMY TURN DISPLAY - Hand
# ============================================================================

func show_enemy_hand(enemy_combatant: Combatant):
	"""Show enemy's dice hand and actions during their turn"""
	current_enemy_display = enemy_combatant
	
	# Show enemy actions in the action fields grid
	await show_enemy_actions(enemy_combatant)
	
	# Show dice hand in enemy panel
	if enemy_panel and enemy_panel.has_method("show_dice_hand"):
		enemy_panel.show_dice_hand(enemy_combatant)
	
	# Legacy: enemy hand container (if still used)
	if enemy_hand_container:
		enemy_hand_container.show()
		
		# Clear previous dice visuals
		for visual in enemy_dice_visuals:
			if is_instance_valid(visual):
				visual.queue_free()
		enemy_dice_visuals.clear()
		
		# Get dice grid in hand container
		var dice_grid = enemy_hand_container.find_child("DiceGrid", true, false)
		if dice_grid:
			for child in dice_grid.get_children():
				child.queue_free()
			
			# Add dice visuals
			var hand_dice = enemy_combatant.get_available_dice()
			for die in hand_dice:
				var die_visual_scene = load("res://scenes/ui/components/die_visual.tscn")
				if die_visual_scene:
					var visual = die_visual_scene.instantiate()
					if visual.has_method("set_die"):
						visual.set_die(die)
					dice_grid.add_child(visual)
					enemy_dice_visuals.append(visual)

func hide_enemy_hand():
	"""Hide enemy hand display and restore player UI"""
	current_enemy_display = null
	
	# Hide enemy panel dice hand
	if enemy_panel and enemy_panel.has_method("hide_dice_hand"):
		enemy_panel.hide_dice_hand()
	
	# Legacy hand container
	if enemy_hand_container:
		enemy_hand_container.hide()
	
	for visual in enemy_dice_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	enemy_dice_visuals.clear()
	
	# Clear enemy turn display
	clear_enemy_turn_display()

func refresh_enemy_hand(enemy_combatant: Combatant):
	"""Refresh enemy hand after dice used"""
	if current_enemy_display == enemy_combatant:
		# Refresh dice hand in enemy panel
		if enemy_panel and enemy_panel.has_method("refresh_dice_hand"):
			enemy_panel.refresh_dice_hand()

func show_enemy_action(enemy_combatant: Combatant, action: Dictionary):
	"""Show what action enemy is using"""
	var action_name = action.get("name", "Attack")
	
	if enemy_action_label:
		enemy_action_label.text = "%s uses %s!" % [
			enemy_combatant.combatant_name,
			action_name
		]
	
	# Also show in enemy panel
	if enemy_panel and enemy_panel.has_method("show_current_action"):
		enemy_panel.show_current_action(action_name)

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
