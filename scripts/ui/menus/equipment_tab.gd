# equipment_tab.gd - Equipment management tab
# Self-registers with parent, emits signals upward
extends Control

# ============================================================================
# SIGNALS (emitted upward)
# ============================================================================
signal refresh_requested()
signal data_changed()
signal item_equipped(slot: String, item: Dictionary)
signal item_unequipped(slot: String)

# ============================================================================
# STATE
# ============================================================================
var player: Player = null

# Equipment slot buttons (discovered dynamically)
var slot_buttons: Dictionary = {}

# UI references
var equipment_grid: GridContainer
var item_popup: Control

# ============================================================================
# EQUIPMENT SLOTS LAYOUT
# ============================================================================
const SLOT_LAYOUT = [
	["", "Head", ""],
	["Main Hand", "Torso", "Off Hand"],
	["Gloves", "Boots", "Accessory"]
]

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("menu_tabs")  # Self-register
	_discover_ui_elements()
	_setup_equipment_slots()
	_create_item_popup()
	print("⚔️ EquipmentTab: Ready")

func _discover_ui_elements():
	"""Discover UI elements via self-registration groups"""
	await get_tree().process_frame  # Let children register themselves
	
	# Find equipment grid by group
	var grids = get_tree().get_nodes_in_group("equipment_grid")
	if grids.size() > 0:
		equipment_grid = grids[0]
		print("  ✓ Equipment grid registered")
	
	# Create grid if not found
	if not equipment_grid:
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(vbox)
		
		var label = Label.new()
		label.text = "Equipment"
		label.add_theme_font_size_override("font_size", 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)
		
		equipment_grid = GridContainer.new()
		equipment_grid.name = "EquipmentGrid"
		equipment_grid.columns = 3
		equipment_grid.add_theme_constant_override("h_separation", 20)
		equipment_grid.add_theme_constant_override("v_separation", 20)
		vbox.add_child(equipment_grid)

func _setup_equipment_slots():
	"""Create equipment slot buttons"""
	if not equipment_grid:
		return
	
	# Clear existing
	for child in equipment_grid.get_children():
		child.queue_free()
	slot_buttons.clear()
	
	# Create slots based on layout
	for row in SLOT_LAYOUT:
		for slot_name in row:
			if slot_name == "":
				# Empty spacer
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(100, 100)
				equipment_grid.add_child(spacer)
			else:
				var slot_container = _create_equipment_slot(slot_name)
				slot_buttons[slot_name] = slot_container
				equipment_grid.add_child(slot_container)

func _create_equipment_slot(slot_name: String) -> Control:
	"""Create a single equipment slot button"""
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(100, 120)
	container.add_to_group("equipment_slots")  # Self-identify
	
	# Slot button
	var button = Button.new()
	button.name = "SlotButton"
	button.custom_minimum_size = Vector2(100, 100)
	button.text = "Empty"
	button.pressed.connect(_on_slot_clicked.bind(slot_name))
	container.add_child(button)
	
	# Label
	var label = Label.new()
	label.text = slot_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	container.add_child(label)
	
	return container

func _create_item_popup():
	"""Create popup for item details"""
	item_popup = Control.new()
	item_popup.name = "ItemPopup"
	item_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	item_popup.hide()
	add_child(item_popup)
	
	# Semi-transparent overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(_on_overlay_input)
	item_popup.add_child(overlay)
	
	# Centered panel
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(300, 400)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	item_popup.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Item name
	var name_label = Label.new()
	name_label.name = "ItemName"
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Item image
	var image_rect = TextureRect.new()
	image_rect.name = "ItemImage"
	image_rect.custom_minimum_size = Vector2(100, 100)
	image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(image_rect)
	
	# Description
	var desc_label = RichTextLabel.new()
	desc_label.name = "ItemDescription"
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(desc_label)
	
	# Stats
	var stats_label = RichTextLabel.new()
	stats_label.name = "ItemStats"
	stats_label.bbcode_enabled = true
	stats_label.fit_content = true
	stats_label.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(stats_label)
	
	# Unequip button
	var unequip_btn = Button.new()
	unequip_btn.name = "UnequipButton"
	unequip_btn.text = "Unequip"
	vbox.add_child(unequip_btn)

# ============================================================================
# PUBLIC API
# ============================================================================

func set_player(p_player: Player):
	"""Set player and refresh"""
	player = p_player
	
	# Connect to player equipment signals
	if player:
		if not player.equipment_changed.is_connected(_on_player_equipment_changed):
			player.equipment_changed.connect(_on_player_equipment_changed)
	
	refresh()

func refresh():
	"""Refresh all equipment slot displays"""
	if not player:
		return
	
	for slot_name in slot_buttons:
		_update_equipment_slot(slot_name)

func on_external_data_change():
	"""Called when other tabs modify player data"""
	refresh()

# ============================================================================
# PRIVATE DISPLAY METHODS
# ============================================================================

func _update_equipment_slot(slot_name: String):
	"""Update a single slot's display"""
	var slot_container = slot_buttons.get(slot_name)
	if not slot_container:
		return
	
	var button = slot_container.get_node("SlotButton")
	if not button:
		return
	
	var item = player.equipment.get(slot_name)
	
	if item:
		# Show equipped item
		_apply_item_visual(button, item)
	else:
		# Empty slot
		_apply_empty_visual(button)

func _apply_item_visual(button: Button, item: Dictionary):
	"""Apply item visual to button"""
	if item.has("icon") and item.icon:
		button.icon = item.icon
		button.text = ""
	else:
		button.text = ""
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = _get_item_color(item)
		button.add_theme_stylebox_override("normal", stylebox)

func _apply_empty_visual(button: Button):
	"""Apply empty slot visual"""
	button.icon = null
	button.text = "Empty"
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.2, 0.2, 0.2)
	stylebox.border_color = Color(0.4, 0.4, 0.4)
	stylebox.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", stylebox)

func _get_item_color(item: Dictionary) -> Color:
	"""Get color based on item slot type"""
	match item.get("slot", ""):
		"Head": return Color(0.6, 0.4, 0.4)
		"Torso": return Color(0.4, 0.6, 0.4)
		"Gloves": return Color(0.4, 0.4, 0.6)
		"Boots": return Color(0.5, 0.5, 0.3)
		"Main Hand": return Color(0.7, 0.3, 0.3)
		"Off Hand": return Color(0.3, 0.5, 0.5)
		"Accessory": return Color(0.6, 0.3, 0.6)
		_: return Color(0.5, 0.5, 0.5)

func _show_item_popup(item: Dictionary, slot_name: String):
	"""Display popup with item details"""
	if not item_popup:
		return
	
	var panel = item_popup.get_node("Panel")
	var vbox = panel.get_node("VBox")
	
	# Set item data
	var name_label = vbox.get_node("ItemName")
	name_label.text = item.get("name", "Unknown")
	
	var image_rect = vbox.get_node("ItemImage")
	if item.has("icon") and item.icon:
		image_rect.texture = item.icon
	else:
		var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
		img.fill(_get_item_color(item))
		image_rect.texture = ImageTexture.create_from_image(img)
	
	var desc_label = vbox.get_node("ItemDescription")
	desc_label.text = item.get("description", "")
	
	var stats_label = vbox.get_node("ItemStats")
	var stats_text = ""
	if item.has("stats"):
		stats_text = "[b]Stats:[/b]\n"
		for stat in item.stats:
			stats_text += "  %s: [color=green]+%d[/color]\n" % [stat.capitalize(), item.stats[stat]]
	stats_label.text = stats_text
	
	# Setup unequip button
	var unequip_btn = vbox.get_node("UnequipButton")
	# Disconnect old connections
	for connection in unequip_btn.pressed.get_connections():
		unequip_btn.pressed.disconnect(connection.callable)
	unequip_btn.pressed.connect(_on_unequip_pressed.bind(slot_name))
	
	item_popup.show()

func _hide_item_popup():
	"""Hide the item popup"""
	if item_popup:
		item_popup.hide()

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_slot_clicked(slot_name: String):
	"""Equipment slot clicked"""
	if not player:
		return
	
	var item = player.equipment.get(slot_name)
	if item:
		_show_item_popup(item, slot_name)

func _on_unequip_pressed(slot_name: String):
	"""Unequip button pressed in popup"""
	if not player:
		return
	
	if player.unequip_item(slot_name):
		item_unequipped.emit(slot_name)  # Bubble up
		data_changed.emit()  # Bubble up
		_hide_item_popup()
		refresh()
		print("✅ Unequipped: %s" % slot_name)

func _on_overlay_input(event: InputEvent):
	"""Popup overlay clicked"""
	if event is InputEventMouseButton and event.pressed:
		_hide_item_popup()

func _on_player_equipment_changed(_slot: String, _item):
	"""Player equipment changed (bubbled from Player)"""
	refresh()
	data_changed.emit()  # Bubble further up
