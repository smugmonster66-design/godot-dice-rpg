# res://scripts/ui/combat/enemy_slot.gd
# Individual enemy slot - attach to PanelContainer with child nodes
extends PanelContainer
class_name EnemySlot

# ============================================================================
# SIGNALS
# ============================================================================
signal slot_clicked(slot: EnemySlot)
signal slot_hovered(slot: EnemySlot)
signal slot_unhovered(slot: EnemySlot)

# ============================================================================
# EXPORTS
# ============================================================================
@export var slot_index: int = 0
@export var default_portrait: Texture2D = null

@export_group("Colors")
@export var empty_slot_color: Color = Color(0.2, 0.2, 0.2, 0.5)
@export var filled_slot_color: Color = Color(0.3, 0.2, 0.2, 0.9)
@export var selected_slot_color: Color = Color(0.5, 0.4, 0.2, 0.95)
@export var dead_slot_color: Color = Color(0.15, 0.1, 0.1, 0.8)

# ============================================================================
# NODE REFERENCES - Found via groups or names
# ============================================================================
var portrait_rect: TextureRect = null
var name_label: Label = null
var health_bar: ProgressBar = null
var health_label: Label = null
var selection_indicator: Control = null

# ============================================================================
# STATE
# ============================================================================
var enemy: Combatant = null
var enemy_data: EnemyData = null
var is_selected: bool = false
var is_empty: bool = true
var style_box: StyleBoxFlat = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_nodes()
	_setup_style()
	_connect_signals()
	set_empty()

func _discover_nodes():
	"""Find child nodes by group or name"""
	# Portrait - look for group first, then by name
	var portraits = _find_in_group("enemy_portrait")
	if portraits.size() > 0:
		portrait_rect = portraits[0] as TextureRect
	else:
		portrait_rect = find_child("Portrait", true, false) as TextureRect
		if not portrait_rect:
			portrait_rect = find_child("PortraitRect", true, false) as TextureRect
	
	# Name label
	var names = _find_in_group("enemy_name")
	if names.size() > 0:
		name_label = names[0] as Label
	else:
		name_label = find_child("NameLabel", true, false) as Label
		if not name_label:
			name_label = find_child("Name", true, false) as Label
	
	# Health bar
	var bars = _find_in_group("enemy_health_bar")
	if bars.size() > 0:
		health_bar = bars[0] as ProgressBar
	else:
		health_bar = find_child("HealthBar", true, false) as ProgressBar
	
	# Health label
	var health_labels = _find_in_group("enemy_health_label")
	if health_labels.size() > 0:
		health_label = health_labels[0] as Label
	else:
		health_label = find_child("HealthLabel", true, false) as Label
	
	# Selection indicator (optional overlay)
	var indicators = _find_in_group("selection_indicator")
	if indicators.size() > 0:
		selection_indicator = indicators[0]
	else:
		selection_indicator = find_child("SelectionIndicator", true, false)
	
	# Debug output
	print("🎯 EnemySlot%d nodes:" % slot_index)
	print("  Portrait: %s" % ("✓" if portrait_rect else "✗"))
	print("  Name: %s" % ("✓" if name_label else "✗"))
	print("  HealthBar: %s" % ("✓" if health_bar else "✗"))
	print("  HealthLabel: %s" % ("✓" if health_label else "✗"))
	print("  SelectionIndicator: %s" % ("✓" if selection_indicator else "✗"))

func _find_in_group(group_name: String) -> Array:
	"""Find children in a specific group"""
	var result = []
	for child in get_children():
		if child.is_in_group(group_name):
			result.append(child)
		# Check grandchildren too
		for grandchild in child.get_children():
			if grandchild.is_in_group(group_name):
				result.append(grandchild)
	return result

func _setup_style():
	"""Setup or get the panel's StyleBox"""
	var current_style = get_theme_stylebox("panel")
	if current_style is StyleBoxFlat:
		style_box = current_style.duplicate()
	else:
		style_box = StyleBoxFlat.new()
		style_box.set_corner_radius_all(8)
		style_box.set_border_width_all(2)
	
	style_box.bg_color = empty_slot_color
	style_box.border_color = Color(0.3, 0.3, 0.3)
	add_theme_stylebox_override("panel", style_box)

func _connect_signals():
	"""Connect input signals"""
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func set_enemy(p_enemy: Combatant, p_enemy_data: EnemyData = null):
	"""Set the enemy for this slot"""
	enemy = p_enemy
	enemy_data = p_enemy_data
	is_empty = false
	
	# Update visuals
	_update_display()
	
	# Connect to enemy signals
	if enemy:
		if enemy.has_signal("health_changed") and not enemy.health_changed.is_connected(_on_enemy_health_changed):
			enemy.health_changed.connect(_on_enemy_health_changed)
		if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
			enemy.died.connect(_on_enemy_died)

func set_empty():
	"""Set slot to empty state"""
	enemy = null
	enemy_data = null
	is_empty = true
	is_selected = false
	
	if portrait_rect:
		portrait_rect.texture = default_portrait
		portrait_rect.modulate = Color(0.5, 0.5, 0.5, 0.5)
	
	if name_label:
		name_label.text = "Empty"
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	
	if health_bar:
		health_bar.hide()
	
	if health_label:
		health_label.text = ""
	
	if style_box:
		style_box.bg_color = empty_slot_color
		style_box.border_color = Color(0.3, 0.3, 0.3)
	
	if selection_indicator:
		selection_indicator.hide()

func set_selected(selected: bool):
	"""Set selection state"""
	is_selected = selected
	
	if selection_indicator:
		selection_indicator.visible = selected and not is_empty and is_alive()
	
	if style_box:
		if selected and not is_empty and is_alive():
			style_box.bg_color = selected_slot_color
			style_box.border_color = Color(1.0, 0.9, 0.2)
		elif not is_empty and is_alive():
			style_box.bg_color = filled_slot_color
			style_box.border_color = Color(0.6, 0.3, 0.3)

func update_health(current: int, maximum: int):
	"""Update health display"""
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
	
	if health_label:
		health_label.text = "%d / %d" % [current, maximum]

func get_enemy() -> Combatant:
	"""Get the enemy in this slot"""
	return enemy

func is_alive() -> bool:
	"""Check if enemy is alive"""
	return enemy != null and enemy.is_alive()

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _update_display():
	"""Update all display elements"""
	if not enemy:
		set_empty()
		return
	
	# Portrait
	if portrait_rect:
		if enemy_data and enemy_data.portrait:
			portrait_rect.texture = enemy_data.portrait
		elif enemy.enemy_data and enemy.enemy_data.portrait:
			portrait_rect.texture = enemy.enemy_data.portrait
		elif default_portrait:
			portrait_rect.texture = default_portrait
		portrait_rect.modulate = Color.WHITE
	
	# Name
	if name_label:
		name_label.text = enemy.combatant_name
		name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.9))
	
	# Health
	if health_bar:
		health_bar.show()
		health_bar.max_value = enemy.max_health
		health_bar.value = enemy.current_health
	
	if health_label:
		health_label.text = "%d / %d" % [enemy.current_health, enemy.max_health]
	
	# Style
	if style_box:
		style_box.bg_color = filled_slot_color
		style_box.border_color = Color(0.6, 0.3, 0.3)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_gui_input(event: InputEvent):
	"""Handle input on the slot"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not is_empty and is_alive():
				slot_clicked.emit(self)

func _on_mouse_entered():
	"""Handle mouse enter"""
	if not is_empty and is_alive():
		slot_hovered.emit(self)
		if style_box and not is_selected:
			style_box.border_color = Color(0.9, 0.7, 0.3)

func _on_mouse_exited():
	"""Handle mouse exit"""
	if not is_empty:
		slot_unhovered.emit(self)
		if style_box and not is_selected:
			if is_alive():
				style_box.border_color = Color(0.6, 0.3, 0.3)
			else:
				style_box.border_color = Color(0.3, 0.2, 0.2)

func _on_enemy_health_changed(current: int, maximum: int):
	"""Handle enemy health change"""
	update_health(current, maximum)

func _on_enemy_died():
	"""Handle enemy death"""
	if portrait_rect:
		portrait_rect.modulate = Color(0.3, 0.3, 0.3, 0.7)
	
	if name_label:
		name_label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.3))
	
	if style_box:
		style_box.bg_color = dead_slot_color
		style_box.border_color = Color(0.3, 0.2, 0.2)
	
	if selection_indicator:
		selection_indicator.hide()
	
	is_selected = false
