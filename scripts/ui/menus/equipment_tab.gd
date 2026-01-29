# equipment_tab.gd - Equipment management tab
extends Control

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var equipment_grid = $VBoxContainer/EquipmentGrid

# Equipment slot buttons (created dynamically or in scene)
var slot_buttons: Dictionary = {}

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var item_popup: Control = null

# ============================================================================
# SIGNALS
# ============================================================================
signal item_unequipped(slot: String)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	setup_equipment_slots()
	create_item_popup()

func setup_equipment_slots():
	"""Create equipment slot grid"""
	if not equipment_grid:
		return
	
	# Clear existing
	for child in equipment_grid.get_children():
		child.queue_free()
	slot_buttons.clear()
	
	# Define slot layout (3x3)
	var slot_layout = [
		["", "Head", ""],
		["Main Hand", "Torso", "Off Hand"],
		["Gloves", "Boots", "Accessory"]
	]
	
	for row in slot_layout:
		for slot_name in row:
			if slot_name == "":
				# Empty cell
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(100, 100)
				equipment_grid.add_child(spacer)
			else:
				var slot_container = create_equipment_slot(slot_name)
				slot_buttons[slot_name] = slot_container
				equipment_grid.add_child(slot_container)

func create_equipment_slot(slot_name: String) -> Control:
	"""Create a single equipment slot"""
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(100, 120)
	
	# Slot button
	var button = Button.new()
	button.name = "SlotButton"
	button.custom_minimum_size = Vector2(100, 100)
	button.pressed.connect(func(): _on_slot_clicked(slot_name))
	container.add_child(button)
	
	# Label
	var label = Label.new()
	label.text = slot_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	container.add_child(label)
	
	return container

# ============================================================================
# PUBLIC API
# ============================================================================

func set_player(p_player: Player):
	"""Set player and refresh"""
	player = p_player
	
	if player and not player.equipment_changed.is_connected(_on_equipment_changed):
		player.equipment_changed.connect(_on_equipment_changed)
	
	refresh()

func refresh():
	"""Refresh all equipment slots"""
	if not player:
		return
	
	for slot_name in slot_buttons:
		update_equipment_slot(slot_name)

func update_equipment_slot(slot_name: String):
	"""Update single slot display"""
	var slot_container = slot_buttons.get(slot_name)
	if not slot_container:
		return
	
	var button = slot_container.get_node("SlotButton")
	if not button:
		return
	
	var item = player.equipment.get(slot_name)
	
	if item:
		# Show equipped item
		if item.has("icon") and item.icon:
			button.icon = item.icon
			button.text = ""
		else:
			button.text = ""
			var stylebox = StyleBoxFlat.new()
			stylebox.bg_color = get_item_color(item)
			button.add_theme_stylebox_override("normal", stylebox)
	else:
		# Empty slot
		button.icon = null
		button.text = "Empty"
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color(0.2, 0.2, 0.2)
		stylebox.border_color = Color(0.4, 0.4, 0.4)
		stylebox.border_width_left = 2
		stylebox.border_width_right = 2
		stylebox.border_width_top = 2
		stylebox.border_width_bottom = 2
		button.add_theme_stylebox_override("normal", stylebox)

func get_item_color(item: Dictionary) -> Color:
	"""Get color for item type"""
	match item.get("slot", ""):
		"Head": return Color(0.6, 0.4, 0.4)
		"Torso": return Color(0.4, 0.6, 0.4)
		"Gloves": return Color(0.4, 0.4, 0.6)
		"Boots": return Color(0.5, 0.5, 0.3)
		"Main Hand": return Color(0.7, 0.3, 0.3)
		"Off Hand": return Color(0.3, 0.5, 0.5)
		"Accessory": return Color(0.6, 0.3, 0.6)
		_: return Color(0.5, 0.5, 0.5)

# ============================================================================
# ITEM POPUP
# ============================================================================

func create_item_popup():
	"""Create popup for item details"""
	item_popup = Control.new()
	item_popup.name = "ItemPopup"
	item_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	item_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_popup.hide()
	add_child(item_popup)
	
	# Overlay
	var overlay = Panel.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var overlay_style = StyleBoxFlat.new()
	overlay_style.bg_color = Color(0, 0, 0, 0.7)
	overlay.add_theme_stylebox_override("panel", overlay_style)
	overlay.gui_input.connect(_on_overlay_clicked)
	item_popup.add_child(overlay)
	
	# Panel
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 300)
	panel.position = Vector2(-200, -150)
	item_popup.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	panel.add_child(vbox)
	
	# Name
	var name_label = Label.new()
	name_label.name = "ItemName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)
	
	# Image
	var image_rect = TextureRect.new()
	image_rect.name = "ItemImage"
	image_rect.custom_minimum_size = Vector2(100, 100)
	image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(image_rect)
	
	# Description
	var desc_label = Label.new()
	desc_label.name = "ItemDescription"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(380, 0)
	vbox.add_child(desc_label)
	
	# Stats
	var stats_label = Label.new()
	stats_label.name = "ItemStats"
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(stats_label)
	
	# Unequip button
	var unequip_btn = Button.new()
	unequip_btn.name = "UnequipButton"
	unequip_btn.text = "Unequip"
	unequip_btn.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(unequip_btn)

func show_item_popup(item: Dictionary, slot_name: String):
	"""Show popup with item details"""
	if not item_popup:
		return
	
	var panel = item_popup.get_node("Panel")
	var vbox = panel.get_node("VBox")
	
	# Set data
	var name_label = vbox.get_node("ItemName")
	name_label.text = item.get("name", "Unknown")
	
	var image_rect = vbox.get_node("ItemImage")
	if item.has("icon") and item.icon:
		image_rect.texture = item.icon
	else:
		var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
		img.fill(get_item_color(item))
		image_rect.texture = ImageTexture.create_from_image(img)
	
	var desc_label = vbox.get_node("ItemDescription")
	desc_label.text = item.get("description", "")
	
	var stats_label = vbox.get_node("ItemStats")
	var stats_text = ""
	if item.has("stats"):
		stats_text = "Stats:\n"
		for stat in item.stats:
			stats_text += "  %s: +%d\n" % [stat.capitalize(), item.stats[stat]]
	stats_label.text = stats_text
	
	# Setup unequip button
	var unequip_btn = vbox.get_node("UnequipButton")
	for connection in unequip_btn.pressed.get_connections():
		unequip_btn.pressed.disconnect(connection.callable)
	unequip_btn.pressed.connect(func(): _on_unequip_pressed(slot_name))
	
	item_popup.show()

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_slot_clicked(slot_name: String):
	"""Slot clicked"""
	if not player:
		return
	
	var item = player.equipment.get(slot_name)
	if item:
		show_item_popup(item, slot_name)

func _on_unequip_pressed(slot_name: String):
	"""Unequip button pressed"""
	if player and player.unequip_item(slot_name):
		print("✅ Unequipped from: %s" % slot_name)
		item_unequipped.emit(slot_name)
		hide_item_popup()
		refresh()

func _on_overlay_clicked(event: InputEvent):
	"""Overlay clicked"""
	if event is InputEventMouseButton and event.pressed:
		hide_item_popup()

func hide_item_popup():
	"""Hide item popup"""
	if item_popup:
		item_popup.hide()

func _on_equipment_changed(slot: String, _item):
	"""Equipment changed"""
	update_equipment_slot(slot)
