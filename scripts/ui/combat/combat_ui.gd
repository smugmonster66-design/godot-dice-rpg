# combat_ui.gd - Combat UI with pre-created action field grid
extends CanvasLayer

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var player_health_display = $MarginContainer/VBox/TopBar/PlayerHealth
@onready var enemy_health_display = $MarginContainer/VBox/TopBar/EnemyHealth
@onready var dice_pool_display = $MarginContainer/VBox/DicePoolArea/DicePoolDisplay
@onready var end_turn_button = $MarginContainer/VBox/ButtonArea/EndTurnButton
@onready var action_fields_grid = $MarginContainer/VBox/ActionFieldsArea/ActionFieldsGrid

# Collect all pre-created action field references
var action_fields: Array[ActionField] = []

# Action buttons (created dynamically)
var action_buttons_container: HBoxContainer = null
var confirm_button: Button = null
var cancel_button: Button = null

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var enemy = null
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
	
	# Collect all action field nodes
	for i in range(16):
		var field = action_fields_grid.get_node_or_null("ActionField" + str(i + 1))
		if field:
			action_fields.append(field)
			# Connect signals
			field.action_selected.connect(_on_action_field_selected)
			field.action_confirmed.connect(_on_action_field_confirmed)
			field.dice_returned.connect(_on_dice_returned)
	
	print("  ✅ Found %d action fields" % action_fields.size())
	
	# Create action buttons
	create_action_buttons()

func initialize_ui(p_player: Player, p_enemy):
	"""Initialize the UI with player and enemy data"""
	print("🎮 CombatUI.initialize_ui called")
	player = p_player
	enemy = p_enemy
	
	# Create ActionManager
	if not action_manager:
		action_manager = ActionManager.new()
		action_manager.name = "ActionManager"
		add_child(action_manager)
		action_manager.actions_changed.connect(refresh_action_fields)
	
	# Initialize ActionManager with player
	action_manager.initialize(player)
	
	# Setup health displays
	setup_health_displays()
	
	# Setup dice pool
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
	if player_health_display:
		player_health_display.initialize("Player", player.current_hp, player.max_hp, Color.RED)
	
	# Enemy health
	if enemy_health_display:
		enemy_health_display.initialize("Enemy", 100, 100, Color.ORANGE)
		print("    ✅ Enemy health display initialized")

func update_player_health(current: int, maximum: int):
	"""Update player health display"""
	if player_health_display:
		player_health_display.update_health(current, maximum)

func update_enemy_health(current: int, maximum: int):
	"""Update enemy health display"""
	if enemy_health_display:
		enemy_health_display.update_health(current, maximum)

# ============================================================================
# DICE POOL
# ============================================================================

func setup_dice_pool():
	"""Setup dice pool display"""
	print("  🎲 Setting up dice pool...")
	
	if dice_pool_display and player and player.dice_pool:
		dice_pool_display.initialize(player.dice_pool)
		print("    ✅ Dice pool display initialized")

func refresh_dice_pool():
	"""Refresh the dice pool display"""
	if dice_pool_display:
		dice_pool_display.refresh()

# ============================================================================
# ACTION BUTTONS
# ============================================================================

func create_action_buttons():
	"""Create confirm/cancel action buttons"""
	# Create container
	action_buttons_container = HBoxContainer.new()
	action_buttons_container.name = "ActionButtonsContainer"
	action_buttons_container.add_theme_constant_override("separation", 10)
	action_buttons_container.hide()  # Hidden by default
	
	# Confirm button
	confirm_button = Button.new()
	confirm_button.text = "✓ Confirm"
	confirm_button.custom_minimum_size = Vector2(120, 40)
	confirm_button.pressed.connect(_on_confirm_pressed)
	action_buttons_container.add_child(confirm_button)
	
	# Cancel button
	cancel_button = Button.new()
	cancel_button.text = "✗ Cancel"
	cancel_button.custom_minimum_size = Vector2(120, 40)
	cancel_button.pressed.connect(_on_cancel_pressed)
	action_buttons_container.add_child(cancel_button)
	
	# Add to ButtonArea
	if has_node("MarginContainer/VBox/ButtonArea"):
		var button_area = $MarginContainer/VBox/ButtonArea
		button_area.add_child(action_buttons_container)
		print("  ✅ Action buttons created")

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
	"""Action field was clicked"""
	print("🎯 Action field selected: %s" % field.action_name)
	
	# Deselect other fields
	deselect_all_fields()
	
	selected_action_field = field
	
	# Show action buttons
	if action_buttons_container:
		action_buttons_container.show()
	
	# Disable end turn
	if end_turn_button:
		end_turn_button.disabled = true

func _on_action_field_confirmed(action_data: Dictionary):
	"""Action field confirmed (shouldn't happen with our flow)"""
	print("⚠️ Action field auto-confirmed: %s" % action_data.get("name"))

func deselect_all_fields():
	"""Deselect all action fields"""
	for field in action_fields:
		if field.visible:
			# Visual deselection if needed
			pass

func _on_dice_returned(die: DieData):
	"""Die was returned from action field"""
	print("🔄 Die returned to pool: %s" % die.get_display_name())
	
	# Restore die to player's available pool
	if player and player.dice_pool:
		player.dice_pool.restore_die(die)
	
	# Refresh dice pool display
	refresh_dice_pool()

# ============================================================================
# ACTION BUTTON HANDLERS
# ============================================================================

func _on_confirm_pressed():
	"""Confirm button pressed"""
	if not selected_action_field:
		return
	
	print("✅ Confirming action: %s" % selected_action_field.action_name)
	
	# Confirm the action
	if selected_action_field.has_method("confirm_action"):
		selected_action_field.confirm_action()
	
	# Hide action buttons
	if action_buttons_container:
		action_buttons_container.hide()
	
	# Enable end turn
	if end_turn_button:
		end_turn_button.disabled = false
	
	selected_action_field = null

func _on_cancel_pressed():
	"""Cancel button pressed"""
	if not selected_action_field:
		return
	
	print("❌ Canceling action: %s" % selected_action_field.action_name)
	
	# Cancel the action (returns dice)
	if selected_action_field.has_method("cancel_action"):
		selected_action_field.cancel_action()
	
	# Hide action buttons
	if action_buttons_container:
		action_buttons_container.hide()
	
	# Enable end turn
	if end_turn_button:
		end_turn_button.disabled = false
	
	selected_action_field = null

# ============================================================================
# TURN MANAGEMENT
# ============================================================================

func _on_end_turn_pressed():
	"""End turn button pressed"""
	print("🎮 End turn button pressed")
	turn_ended.emit()
