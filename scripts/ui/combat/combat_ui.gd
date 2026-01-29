# combat_ui.gd - Combat UI with scrollable action categories
extends CanvasLayer

# ============================================================================
# ENUMS
# ============================================================================
enum ActionCategory {
	ITEMS,
	SKILLS
}

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var enemy: Node2D = null
var action_manager: ActionManager = null
var current_category: ActionCategory = ActionCategory.ITEMS
var selected_action_field: ActionField = null

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var dice_pool_display = $MarginContainer/VBox/DicePoolArea/DicePoolDisplay
@onready var end_turn_button = $MarginContainer/VBox/ButtonArea/EndTurnButton

# Health displays
var player_health_display = null
var enemy_health_display = null

# Action area nodes (created dynamically)
var action_area_container: VBoxContainer = null
var category_nav: HBoxContainer = null
var left_button: Button = null
var category_label: Label = null
var right_button: Button = null
var action_scroller: Control = null
var items_column: ScrollContainer = null
var items_grid: GridContainer = null
var skills_column: ScrollContainer = null
var skills_grid: GridContainer = null

# Action buttons
var action_buttons_container: HBoxContainer = null
var confirm_button: Button = null
var cancel_button: Button = null

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
	
	# Find health displays
	if has_node("MarginContainer/VBox/TopBar"):
		var top_bar = $MarginContainer/VBox/TopBar
		if top_bar.get_child_count() >= 2:
			player_health_display = top_bar.get_child(0)
			enemy_health_display = top_bar.get_child(1)
			print("  ✅ Found health displays in TopBar")
	
	# Create action area UI
	create_action_area()
	
	# Create action buttons
	create_action_buttons()

func initialize_ui(p_player: Player, p_enemy: Node2D):
	"""Initialize UI with player and enemy"""
	print("🎮 CombatUI.initialize_ui called")
	player = p_player
	enemy = p_enemy
	
	# Create action manager
	action_manager = ActionManager.new()
	action_manager.name = "ActionManager"
	add_child(action_manager)
	action_manager.initialize(player)
	action_manager.actions_changed.connect(_on_actions_changed)
	
	# Setup displays
	setup_health_displays()
	setup_dice_pool()
	
	# Build action fields
	rebuild_action_fields()
	
	# Connect end turn button
	if end_turn_button and not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)
		print("  ✅ End turn button connected")
	
	# Hide action buttons initially
	if action_buttons_container:
		action_buttons_container.hide()
	
	print("🎮 CombatUI initialization complete")

# ============================================================================
# UI CREATION
# ============================================================================

func create_action_area():
	"""Create the scrollable action area with category navigation"""
	print("  🎨 Creating action area...")
	
	# Find the VBox
	var vbox = $MarginContainer/VBox
	
	# Find or create ActionAreaContainer (should be between CenterArea and DicePoolArea)
	var center_area_index = -1
	for i in range(vbox.get_child_count()):
		var child = vbox.get_child(i)
		if child.name == "CenterArea":
			center_area_index = i
			break
	
	action_area_container = VBoxContainer.new()
	action_area_container.name = "ActionAreaContainer"
	action_area_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_area_container.add_theme_constant_override("separation", 8)
	
	if center_area_index >= 0:
		vbox.add_child(action_area_container)
		vbox.move_child(action_area_container, center_area_index + 1)
	else:
		vbox.add_child(action_area_container)
	
	# Category Navigation (arrows + label)
	category_nav = HBoxContainer.new()
	category_nav.name = "CategoryNavigation"
	category_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	category_nav.add_theme_constant_override("separation", 20)
	action_area_container.add_child(category_nav)
	
	left_button = Button.new()
	left_button.text = "◀"
	left_button.custom_minimum_size = Vector2(40, 40)
	left_button.pressed.connect(_on_left_button_pressed)
	category_nav.add_child(left_button)
	
	category_label = Label.new()
	category_label.text = "Items"
	category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	category_label.custom_minimum_size = Vector2(200, 0)
	category_label.add_theme_font_size_override("font_size", 18)
	category_nav.add_child(category_label)
	
	right_button = Button.new()
	right_button.text = "▶"
	right_button.custom_minimum_size = Vector2(40, 40)
	right_button.pressed.connect(_on_right_button_pressed)
	category_nav.add_child(right_button)
	
	# Action Fields Scroller (contains both columns)
	action_scroller = Control.new()
	action_scroller.name = "ActionFieldsScroller"
	action_scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_scroller.clip_contents = true
	action_area_container.add_child(action_scroller)
	
	# Items Column
	items_column = ScrollContainer.new()
	items_column.name = "ItemsColumn"
	items_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_scroller.add_child(items_column)
	
	items_grid = GridContainer.new()
	items_grid.name = "ItemsGrid"
	items_grid.columns = 2
	items_grid.add_theme_constant_override("h_separation", 10)
	items_grid.add_theme_constant_override("v_separation", 10)
	items_column.add_child(items_grid)
	
	# Skills Column (initially hidden off-screen)
	skills_column = ScrollContainer.new()
	skills_column.name = "SkillsColumn"
	skills_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skills_column.visible = false
	action_scroller.add_child(skills_column)
	
	skills_grid = GridContainer.new()
	skills_grid.name = "SkillsGrid"
	skills_grid.columns = 2
	skills_grid.add_theme_constant_override("h_separation", 10)
	skills_grid.add_theme_constant_override("v_separation", 10)
	skills_column.add_child(skills_grid)
	
	# Set initial button states
	update_category_buttons()
	
	print("    ✅ Action area created")

func create_action_buttons():
	"""Create Confirm and Cancel buttons"""
	action_buttons_container = HBoxContainer.new()
	action_buttons_container.name = "ActionButtonsContainer"
	action_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	action_buttons_container.add_theme_constant_override("separation", 20)
	
	# Create Confirm button
	confirm_button = Button.new()
	confirm_button.text = "✓ Confirm"
	confirm_button.custom_minimum_size = Vector2(120, 40)
	confirm_button.pressed.connect(_on_confirm_pressed)
	action_buttons_container.add_child(confirm_button)
	
	# Create Cancel button
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

func rebuild_action_fields():
	"""Rebuild all action fields from action manager"""
	if not action_manager:
		return
	
	print("  ⚔️ Rebuilding action fields...")
	
	# Clear existing fields
	for child in items_grid.get_children():
		child.queue_free()
	for child in skills_grid.get_children():
		child.queue_free()
	
	# Create item action fields
	var item_actions = action_manager.get_item_actions()
	for action_data in item_actions:
		var field = create_action_field(action_data)
		items_grid.add_child(field)
	
	# Create skill action fields
	var skill_actions = action_manager.get_skill_actions()
	for action_data in skill_actions:
		var field = create_action_field(action_data)
		skills_grid.add_child(field)
	
	print("    ✅ Created %d item fields, %d skill fields" % [item_actions.size(), skill_actions.size()])

func create_action_field(action_data: Dictionary) -> ActionField:
	"""Create an ActionField from action data"""
	var field = ActionField.new()
	
	# Set properties from data
	field.action_category = action_data.get("category", ActionField.ActionCategory.ITEM)
	field.action_type = action_data.get("action_type", ActionField.ActionType.ATTACK)
	field.action_name = action_data.get("name", "Action")
	field.action_icon = action_data.get("icon", null)
	field.action_description = action_data.get("description", "Does something.")
	field.die_slots = action_data.get("die_slots", 1)
	field.base_damage = action_data.get("base_damage", 0)
	field.damage_multiplier = action_data.get("damage_multiplier", 1.0)
	field.required_tags = action_data.get("required_tags", [])
	field.restricted_tags = action_data.get("restricted_tags", [])
	field.source = action_data.get("source", "")
	
	# Connect signals
	field.action_selected.connect(_on_action_field_selected)
	field.action_confirmed.connect(_on_action_field_confirmed)
	field.dice_returned.connect(_on_dice_returned)
	
	return field

func _on_actions_changed():
	"""Action manager detected changes"""
	rebuild_action_fields()

# ============================================================================
# CATEGORY NAVIGATION
# ============================================================================

func _on_left_button_pressed():
	"""Switch to Items category"""
	if current_category == ActionCategory.SKILLS:
		switch_to_category(ActionCategory.ITEMS)

func _on_right_button_pressed():
	"""Switch to Skills category"""
	if current_category == ActionCategory.ITEMS:
		switch_to_category(ActionCategory.SKILLS)

func switch_to_category(category: ActionCategory):
	"""Switch visible category"""
	current_category = category
	
	match category:
		ActionCategory.ITEMS:
			items_column.visible = true
			skills_column.visible = false
			category_label.text = "Items"
		ActionCategory.SKILLS:
			items_column.visible = false
			skills_column.visible = true
			category_label.text = "Skills"
	
	update_category_buttons()
	print("📂 Switched to category: %s" % category_label.text)

func update_category_buttons():
	"""Update button enabled/disabled states"""
	left_button.disabled = (current_category == ActionCategory.ITEMS)
	right_button.disabled = (current_category == ActionCategory.SKILLS)

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
	"""Action field confirmed internally (shouldn't happen with our flow)"""
	pass

func deselect_all_fields():
	"""Deselect all action fields"""
	for field in items_grid.get_children():
		if field is ActionField:
			# Visual deselection if needed
			pass
	for field in skills_grid.get_children():
		if field is ActionField:
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
	
	# Get action data (before field clears itself)
	var action_data = {
		"type": selected_action_field.action_type,
		"name": selected_action_field.action_name,
		"value": selected_action_field.get_total_value(),
		"dice": selected_action_field.placed_dice.duplicate(),
		"base_damage": selected_action_field.base_damage,
		"multiplier": selected_action_field.damage_multiplier,
		"source": selected_action_field.source
	}
	
	# Emit to combat manager
	action_confirmed.emit(action_data)
	
	# Clear selection
	selected_action_field = null
	
	# Hide action buttons
	if action_buttons_container:
		action_buttons_container.hide()
	
	# Enable end turn
	if end_turn_button:
		end_turn_button.disabled = false
	
	# Refresh dice pool
	refresh_dice_pool()

func _on_cancel_pressed():
	"""Cancel button pressed"""
	if not selected_action_field:
		return
	
	print("❌ Canceling action: %s" % selected_action_field.action_name)
	
	# Cancel the action (returns dice)
	if selected_action_field.has_method("cancel_action"):
		selected_action_field.cancel_action()
	
	# Clear selection
	selected_action_field = null
	
	# Hide action buttons
	if action_buttons_container:
		action_buttons_container.hide()
	
	# Enable end turn
	if end_turn_button:
		end_turn_button.disabled = false

# ============================================================================
# HEALTH & DICE POOL SETUP
# ============================================================================

func setup_health_displays():
	"""Initialize health stat displays"""
	print("  💚 Setting up health displays...")
	
	if player_health_display and player_health_display.has_method("initialize"):
		player_health_display.initialize("Player HP", player.current_hp, player.max_hp, Color.RED)
		print("    ✅ Player health display initialized")
	
	if enemy_health_display and enemy and enemy_health_display.has_method("initialize"):
		enemy_health_display.initialize("Enemy HP", enemy.current_health, enemy.max_health, Color.ORANGE)
		print("    ✅ Enemy health display initialized")
	
	# Connect to updates
	if player:
		if not player.hp_changed.is_connected(_on_player_hp_changed):
			player.hp_changed.connect(_on_player_hp_changed)
	
	if enemy and enemy.has_signal("health_changed"):
		if not enemy.health_changed.is_connected(_on_enemy_health_changed):
			enemy.health_changed.connect(_on_enemy_health_changed)

func setup_dice_pool():
	"""Initialize dice pool display"""
	print("  🎲 Setting up dice pool...")
	
	if dice_pool_display and dice_pool_display.has_method("initialize"):
		dice_pool_display.initialize(player)
		print("    ✅ Dice pool display initialized")

# ============================================================================
# REFRESH & UPDATES
# ============================================================================

func refresh_dice_pool():
	"""Refresh dice pool display"""
	if dice_pool_display and dice_pool_display.has_method("refresh"):
		dice_pool_display.refresh()
		print("🎲 Dice pool refreshed")

func _on_player_hp_changed(current: int, maximum: int):
	"""Update player health display"""
	if player_health_display and player_health_display.has_method("update_values"):
		player_health_display.update_values(current, maximum)

func _on_enemy_health_changed(current: int, maximum: int):
	"""Update enemy health display"""
	if enemy_health_display and enemy_health_display.has_method("update_values"):
		enemy_health_display.update_values(current, maximum)

func _on_end_turn_pressed():
	"""End turn button pressed"""
	print("🎮 End turn button pressed")
	turn_ended.emit()
