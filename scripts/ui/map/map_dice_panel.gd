# map_dice_panel.gd - Main dice panel for the map screen
# Contains dice grid, portrait, and health bar
extends PanelContainer
class_name MapDicePanel

# ============================================================================
# SIGNALS (bubble up)
# ============================================================================
signal dice_order_changed(from_index: int, to_index: int)
signal die_selected(die: DieResource)
signal die_info_requested(die: DieResource)

# ============================================================================
# EXPORTS
# ============================================================================
@export_group("Layout")
@export var panel_width: float = 350.0
@export var portrait_size: Vector2 = Vector2(80, 80)

@export_group("Dice Grid")
@export var grid_columns: int = 5
@export var slot_size: Vector2 = Vector2(56, 56)
@export var max_dice_slots: int = 10

# ============================================================================
# UI REFERENCES
# ============================================================================
var main_container: VBoxContainer
var header_container: HBoxContainer
var portrait_panel: PanelContainer
var portrait_texture: TextureRect
var info_container: VBoxContainer
var name_label: Label
var health_bar: ProgressBar
var health_label: Label
var dice_grid: DiceGrid
var footer_container: HBoxContainer
var roll_button: Button

# ============================================================================
# STATE
# ============================================================================
var player: Node = null  # Player reference
var dice_collection: PlayerDiceCollection = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("map_dice_panels")
	_setup_ui()
	print("🎲 MapDicePanel ready")

func _setup_ui():
	"""Build the panel UI structure"""
	custom_minimum_size.x = panel_width
	
	# Main stylebox
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.set_corner_radius_all(8)
	panel_style.border_color = Color(0.3, 0.3, 0.4)
	panel_style.border_width_bottom = 2
	panel_style.border_width_top = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", panel_style)
	
	# Main VBox
	main_container = VBoxContainer.new()
	main_container.add_theme_constant_override("separation", 10)
	add_child(main_container)
	
	# === HEADER: Portrait + Info ===
	header_container = HBoxContainer.new()
	header_container.add_theme_constant_override("separation", 10)
	main_container.add_child(header_container)
	
	# Portrait
	portrait_panel = PanelContainer.new()
	portrait_panel.custom_minimum_size = portrait_size
	var portrait_style = StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.2, 0.2, 0.25)
	portrait_style.set_corner_radius_all(4)
	portrait_style.border_color = Color(0.4, 0.4, 0.5)
	portrait_style.border_width_bottom = 1
	portrait_style.border_width_top = 1
	portrait_style.border_width_left = 1
	portrait_style.border_width_right = 1
	portrait_panel.add_theme_stylebox_override("panel", portrait_style)
	header_container.add_child(portrait_panel)
	
	portrait_texture = TextureRect.new()
	portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_panel.add_child(portrait_texture)
	
	# Info container (name + health)
	info_container = VBoxContainer.new()
	info_container.size_flags_horizontal = SIZE_EXPAND_FILL
	info_container.add_theme_constant_override("separation", 5)
	header_container.add_child(info_container)
	
	# Name label
	name_label = Label.new()
	name_label.text = "Player"
	name_label.add_theme_font_size_override("font_size", 16)
	info_container.add_child(name_label)
	
	# Health bar container
	var health_container = VBoxContainer.new()
	health_container.add_theme_constant_override("separation", 2)
	info_container.add_child(health_container)
	
	# Health label
	health_label = Label.new()
	health_label.text = "HP: 100/100"
	health_label.add_theme_font_size_override("font_size", 10)
	health_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	health_container.add_child(health_label)
	
	# Health progress bar
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size.y = 16
	health_bar.value = 100
	health_bar.show_percentage = false
	
	# Style the health bar
	var health_bg = StyleBoxFlat.new()
	health_bg.bg_color = Color(0.15, 0.15, 0.15)
	health_bg.set_corner_radius_all(3)
	health_bar.add_theme_stylebox_override("background", health_bg)
	
	var health_fill = StyleBoxFlat.new()
	health_fill.bg_color = Color(0.8, 0.2, 0.2)
	health_fill.set_corner_radius_all(3)
	health_bar.add_theme_stylebox_override("fill", health_fill)
	
	health_container.add_child(health_bar)
	
	# === SEPARATOR ===
	var separator = HSeparator.new()
	main_container.add_child(separator)
	
	# === DICE SECTION ===
	var dice_section = VBoxContainer.new()
	dice_section.add_theme_constant_override("separation", 5)
	main_container.add_child(dice_section)
	
	# Dice header
	var dice_header = HBoxContainer.new()
	dice_section.add_child(dice_header)
	
	var dice_title = Label.new()
	dice_title.text = "Dice"
	dice_title.add_theme_font_size_override("font_size", 14)
	dice_header.add_child(dice_title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	dice_header.add_child(spacer)
	
	# Dice count label
	var dice_count_label = Label.new()
	dice_count_label.name = "DiceCountLabel"
	dice_count_label.text = "0/10"
	dice_count_label.add_theme_font_size_override("font_size", 12)
	dice_count_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	dice_header.add_child(dice_count_label)
	
	# Dice grid
	dice_grid = DiceGrid.new()
	dice_grid.max_columns = grid_columns
	dice_grid.slot_size = slot_size
	dice_grid.max_slots = max_dice_slots
	dice_grid.show_empty_slots = true
	dice_grid.add_theme_constant_override("h_separation", 4)
	dice_grid.add_theme_constant_override("v_separation", 4)
	dice_section.add_child(dice_grid)
	
	# Connect grid signals
	dice_grid.dice_reordered.connect(_on_dice_reordered)
	dice_grid.die_selected.connect(_on_die_selected)
	dice_grid.die_double_clicked.connect(_on_die_double_clicked)
	
	# === FOOTER: Roll button ===
	footer_container = HBoxContainer.new()
	footer_container.add_theme_constant_override("separation", 10)
	main_container.add_child(footer_container)
	
	var footer_spacer = Control.new()
	footer_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	footer_container.add_child(footer_spacer)
	
	roll_button = Button.new()
	roll_button.text = "Roll Dice"
	roll_button.custom_minimum_size = Vector2(100, 30)
	roll_button.pressed.connect(_on_roll_pressed)
	footer_container.add_child(roll_button)
	
	var footer_spacer2 = Control.new()
	footer_spacer2.size_flags_horizontal = SIZE_EXPAND_FILL
	footer_container.add_child(footer_spacer2)

# ============================================================================
# INITIALIZATION WITH PLAYER
# ============================================================================

func initialize(p_player: Node):
	"""Initialize panel with player reference"""
	player = p_player
	
	# Get or create dice collection
	if player.has_node("DiceCollection"):
		dice_collection = player.get_node("DiceCollection")
	elif player.get("dice_collection"):
		dice_collection = player.dice_collection
	else:
		# Create one
		dice_collection = PlayerDiceCollection.new()
		dice_collection.name = "DiceCollection"
		player.add_child(dice_collection)
	
	# Initialize grid with collection
	if dice_grid:
		dice_grid.initialize(dice_collection)
	
	# Connect player signals
	if player.has_signal("hp_changed"):
		player.hp_changed.connect(_on_player_hp_changed)
	
	# Update displays
	_update_player_info()
	_update_dice_count()
	
	print("🎲 MapDicePanel initialized with player")

func set_dice_collection(collection: PlayerDiceCollection):
	"""Directly set dice collection (alternative initialization)"""
	dice_collection = collection
	
	if dice_grid:
		dice_grid.initialize(dice_collection)
	
	# Connect signals
	if dice_collection:
		if not dice_collection.dice_changed.is_connected(_update_dice_count):
			dice_collection.dice_changed.connect(_update_dice_count)
	
	_update_dice_count()

# ============================================================================
# DISPLAY UPDATES
# ============================================================================

func _update_player_info():
	"""Update player name and portrait"""
	if not player:
		return
	
	# Update name
	if player.get("active_class") and player.active_class:
		name_label.text = "%s (Lv.%d)" % [
			player.active_class.player_class_name,
			player.active_class.level
		]
	else:
		name_label.text = "Adventurer"
	
	# Update health
	if player.get("current_hp") != null and player.get("max_hp") != null:
		_on_player_hp_changed(player.current_hp, player.max_hp)

func _update_dice_count():
	"""Update the dice count label"""
	if not dice_collection:
		return
	
	var count_label = find_child("DiceCountLabel")
	if count_label:
		count_label.text = "%d/%d" % [
			dice_collection.get_total_count(),
			dice_collection.max_dice
		]

func set_portrait(texture: Texture2D):
	"""Set the portrait image"""
	if portrait_texture:
		portrait_texture.texture = texture

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_player_hp_changed(current: int, maximum: int):
	"""Update health display"""
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
		
		# Color based on health percentage
		var percent = float(current) / float(maximum) if maximum > 0 else 0
		var fill_style = health_bar.get_theme_stylebox("fill").duplicate()
		if fill_style is StyleBoxFlat:
			if percent > 0.5:
				fill_style.bg_color = Color(0.2, 0.8, 0.2)  # Green
			elif percent > 0.25:
				fill_style.bg_color = Color(0.8, 0.8, 0.2)  # Yellow
			else:
				fill_style.bg_color = Color(0.8, 0.2, 0.2)  # Red
			health_bar.add_theme_stylebox_override("fill", fill_style)
	
	if health_label:
		health_label.text = "HP: %d/%d" % [current, maximum]

func _on_dice_reordered(from_index: int, to_index: int):
	"""Handle dice reordering from grid"""
	_update_dice_count()
	dice_order_changed.emit(from_index, to_index)

func _on_die_selected(slot: DieSlot, die: DieResource):
	"""Handle die selected in grid"""
	die_selected.emit(die)

func _on_die_double_clicked(slot: DieSlot, die: DieResource):
	"""Handle double-click - show die info"""
	die_info_requested.emit(die)

func _on_roll_pressed():
	"""Handle roll button press"""
	if dice_collection:
		dice_collection.roll_all_dice()
		_play_roll_feedback()

func _play_roll_feedback():
	"""Visual feedback for rolling"""
	# Flash the roll button
	var original_color = roll_button.modulate
	roll_button.modulate = Color(1.5, 1.5, 1.5)
	
	var tween = create_tween()
	tween.tween_property(roll_button, "modulate", original_color, 0.3)

# ============================================================================
# PUBLIC API
# ============================================================================

func refresh():
	"""Refresh all displays"""
	if dice_grid:
		dice_grid.refresh()
	_update_player_info()
	_update_dice_count()

func get_selected_die() -> DieResource:
	"""Get currently selected die"""
	if dice_grid:
		return dice_grid.get_selected_die()
	return null

func set_roll_button_enabled(enabled: bool):
	"""Enable/disable the roll button"""
	if roll_button:
		roll_button.disabled = not enabled

func show_roll_button(show: bool):
	"""Show/hide the roll button"""
	if roll_button:
		roll_button.visible = show
