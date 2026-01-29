# inventory_tab.gd - Inventory management tab
extends Control

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var category_tabs = $VBoxContainer/CategoryTabs
@onready var item_grid = $VBoxContainer/ScrollContainer/ItemGrid

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var item_popup: Control = null

# Categories
var categories = ["All", "Head", "Torso", "Gloves", "Boots", "Main Hand", "Off Hand", "Accessory", "Consumable"]

# ============================================================================
# SIGNALS
# ============================================================================
signal item_equipped(item: Dictionary)
signal item_used(item: Dictionary)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	setup_category_tabs()
	create_item_popup()

func setup_category_tabs():
	"""Create category tabs"""
	if not category_tabs:
		return
	
	# Clear existing
	for child in category_tabs.get_children():
		child.queue_free()
	
	# Create tabs
	for category in categories:
		var tab = Control.new()
		tab.name = category
		category_tabs.add_child(tab)
	
	# Connect tab changed
	if not category_tabs.tab_changed.is_connected(_on_category_changed):
		category_tabs.tab_changed.connect(_on_category_changed)

# ============================================================================
# PUBLIC API
# ============================================================================

func set_player(p_player: Player):
	"""Set player and refresh"""
	player = p_player
	refresh()

func refresh():
	"""Refresh display"""
	if not player:
		return
	
	var current_tab = category_tabs.current_tab
	if current_tab >= 0 and current_tab < categories.size():
		refresh_category(categories[current_tab])

func refresh_category(category: String):
	"""Refresh specific category"""
	if not player or not item_grid:
		return
	
	# Clear grid
	for child in item_grid.get_children():
		child.queue_free()
	
	# Filter items
	var items_to_show = []
	if category == "All":
		items_to_show = player.inventory.duplicate()
	else:
		for item in player.inventory:
			if item.get("slot", "") == category or item.get("type", "") == category:
				items_to_show.append(item)
	
	# Show items or empty message
	if items_to_show.size() == 0:
		var empty = Label.new()
		empty.text = "No items in this category"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		item_grid.add_child(empty)
	else:
		for item in items_to_show:
			var item_card = create_item_card(item)
			item_grid.add_child(item_card)

func create_item_card(item: Dictionary) -> Control:
	"""Create visual card for item"""
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(80, 100)
	
	# Button
	var button = Button.new()
	button.custom_minimum_size = Vector2(80, 80)
	button.pressed.connect(func(): _on_item_clicked(item))
	
	if item.has("icon") and item.icon:
		button.icon = item.icon
	else:
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = get_item_color(item)
		button.add_theme_stylebox_override("normal", stylebox)
	
	container.add_child(button)
	
	# Name
	var label = Label.new()
	label.text = item.get("name", "Unknown")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(80, 0)
	label.add_theme_font_size_override("font_size", 10)
	container.add_child(label)
	
	return container

func get_item_color(item: Dictionary) -> Color:
	"""Get color for item type"""
	match item.get("slot", item.get("type", "")):
		"Head": return Color(0.6, 0.4, 0.4)
		"Torso": return Color(0.4, 0.6, 0.4)
		"Gloves": return Color(0.4, 0.4, 0.6)
		"Boots": return Color(0.5, 0.5, 0.3)
		"Main Hand": return Color(0.7, 0.3, 0.3)
		"Off Hand": return Color(0.3, 0.5, 0.5)
		"Accessory": return Color(0.6, 0.3, 0.6)
		"Consumable": return Color(0.3, 0.6, 0.6)
		_: return Color(0.5, 0.5, 0.5)

# ============================================================================
# ITEM POPUP
# ============================================================================

func create_item_popup():
	"""Create item detail popup"""
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
	panel.custom_minimum_size = Vector2(400, 400)
	panel.position = Vector2(-200, -200)
	item_popup.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	panel.add_child(vbox)
	
	# Name
	var name_label = Label.new()
	name_label.name = "ItemName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
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
	
	# Requirements
	var req_label = Label.new()
	req_label.name = "RequirementsLabel"
	req_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	req_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	req_label.hide()
	vbox.add_child(req_label)
	
	# Action button
	var action_btn = Button.new()
	action_btn.name = "ActionButton"
	action_btn.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(action_btn)

func show_item_popup(item: Dictionary):
	"""Show popup with item details"""
	if not item_popup:
		return
	
	var panel = item_popup.get_node("Panel")
	var vbox = panel.get_node("VBox")
	
	# Set data
	vbox.get_node("ItemName").text = item.get("name", "Unknown")
	
	var image_rect = vbox.get_node("ItemImage")
	if item.has("icon") and item.icon:
		image_rect.texture = item.icon
	else:
		var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
		img.fill(get_item_color(item))
		image_rect.texture = ImageTexture.create_from_image(img)
	
	vbox.get_node("ItemDescription").text = item.get("description", "")
	
	# Stats
	var stats_text = ""
	if item.has("stats"):
		stats_text = "Stats:\n"
		for stat in item.stats:
			stats_text += "  %s: +%d\n" % [stat.capitalize(), item.stats[stat]]
	vbox.get_node("ItemStats").text = stats_text
	
	# Check if can equip
	var req_label = vbox.get_node("RequirementsLabel")
	var can_equip = can_equip_item(item)
	if item.has("slot") and not can_equip:
		req_label.text = "Cannot equip - Requirements not met"
		req_label.show()
	else:
		req_label.hide()
	
	# Action button
	var action_btn = vbox.get_node("ActionButton")
	for connection in action_btn.pressed.get_connections():
		action_btn.pressed.disconnect(connection.callable)
	
	var is_equippable = item.has("slot") and item.slot != ""
	var is_consumable = item.get("type", "") == "Consumable"
	
	if is_equippable:
		action_btn.text = "Equip"
		action_btn.disabled = not can_equip
		action_btn.pressed.connect(func(): _on_equip_pressed(item))
	elif is_consumable:
		action_btn.text = "Use"
		action_btn.disabled = false
		action_btn.pressed.connect(func(): _on_use_pressed(item))
	else:
		action_btn.text = "N/A"
		action_btn.disabled = true
	
	item_popup.show()

func can_equip_item(item: Dictionary) -> bool:
	"""Check if player can equip item"""
	if not player or not item.has("slot"):
		return false
	
	if item.has("requirements"):
		for req_stat in item.requirements:
			if player.get_total_stat(req_stat) < item.requirements[req_stat]:
				return false
	
	return true

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_category_changed(tab: int):
	"""Category tab changed"""
	if tab >= 0 and tab < categories.size():
		refresh_category(categories[tab])

func _on_item_clicked(item: Dictionary):
	"""Item clicked"""
	show_item_popup(item)

func _on_equip_pressed(item: Dictionary):
	"""Equip button pressed"""
	if player and player.equip_item(item):
		print("✅ Equipped: %s" % item.get("name", "item"))
		item_equipped.emit(item)
		hide_item_popup()
		refresh()

func _on_use_pressed(item: Dictionary):
	"""Use button pressed"""
	if not player:
		return
	
	# Handle consumable
	if item.has("effect"):
		match item.effect:
			"heal":
				player.heal(item.get("amount", 0))
			"restore_mana":
				player.restore_mana(item.get("amount", 0))
			"cure_poison":
				player.remove_status_effect("poison")
			"remove_bleed":
				player.remove_status_effect("bleed")
	
	player.remove_from_inventory(item)
	item_used.emit(item)
	hide_item_popup()
	refresh()
	print("✅ Used: %s" % item.get("name", "item"))

func _on_overlay_clicked(event: InputEvent):
	"""Overlay clicked"""
	if event is InputEventMouseButton and event.pressed:
		hide_item_popup()

func hide_item_popup():
	"""Hide popup"""
	if item_popup:
		item_popup.hide()
