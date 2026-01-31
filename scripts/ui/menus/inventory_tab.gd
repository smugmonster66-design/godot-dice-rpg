# inventory_tab.gd - Inventory management tab
# Self-registers with parent, emits signals upward
# Uses button-based category filtering with vertical sidebar
extends Control

# ============================================================================
# SIGNALS (emitted upward)
# ============================================================================
signal refresh_requested()
signal data_changed()
signal item_selected(item: Dictionary)
signal item_used(item: Dictionary)
signal item_equipped(item: Dictionary)

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var selected_item: Dictionary = {}
var item_buttons: Array[Button] = []
var category_buttons: Array[Button] = []

# UI references
var inventory_grid: GridContainer
var item_details_panel: PanelContainer

# Current filter
var current_category: String = "All"

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("menu_tabs")  # Self-register
	add_to_group("player_menu_tab_content")  # Register as tab content
	await get_tree().process_frame
	_discover_ui_elements()
	print("🎒 InventoryTab: Ready")

func _discover_ui_elements():
	"""Discover UI elements via self-registration groups"""
	# Find inventory grid by group
	var grids = get_tree().get_nodes_in_group("inventory_grid")
	if grids.size() > 0:
		inventory_grid = grids[0]
		print("  ✓ Inventory grid registered")
	else:
		print("  ⚠️ No inventory_grid found - add ItemGrid to group 'inventory_grid'")
	
	# Find category buttons by group
	var buttons = get_tree().get_nodes_in_group("inventory_category_button")
	for button in buttons:
		if button is Button:
			category_buttons.append(button)
		var cat_name = button.get_meta("category_name", "")
		if cat_name:
			button.toggled.connect(_on_category_button_toggled.bind(cat_name))
			print("  ✓ Connected category button: %s" % cat_name)
	
	# Find details panel by group (optional)
	var panels = get_tree().get_nodes_in_group("inventory_details_panel")
	if panels.size() > 0:
		item_details_panel = panels[0]
		print("  ✓ Details panel registered")
		_setup_details_panel()

func _setup_details_panel():
	"""Connect signals in details panel if it exists"""
	if not item_details_panel:
		return
	
	# Find buttons in details panel
	var buttons = item_details_panel.find_children("*", "Button", true, false)
	for button in buttons:
		var btn_name = button.name.to_lower()
		if "use" in btn_name:
			button.pressed.connect(_on_use_item_pressed)
		elif "equip" in btn_name:
			button.pressed.connect(_on_equip_item_pressed)

# ============================================================================
# PUBLIC API
# ============================================================================

func set_player(p_player: Player):
	"""Set player and refresh"""
	player = p_player
	refresh()

func refresh():
	"""Refresh all displayed data"""
	if not player:
		return
	
	print("🎒 Refreshing inventory - Total items: %d, Category: %s" % [player.inventory.size(), current_category])
	
	# Debug: print first few items
	if player.inventory.size() > 0:
		for i in range(min(3, player.inventory.size())):
			var item = player.inventory[i]
			print("  Item %d: %s (slot: %s, type: %s)" % [i, item.get("name", "?"), item.get("slot", "none"), item.get("type", "none")])
	
	_rebuild_inventory_grid()
	_update_item_details()

func on_external_data_change():
	"""Called when other tabs modify player data"""
	refresh()

# ============================================================================
# PRIVATE DISPLAY METHODS
# ============================================================================

func _rebuild_inventory_grid():
	"""Rebuild inventory item grid"""
	if not inventory_grid:
		return
	
	# Clear existing buttons
	for child in inventory_grid.get_children():
		child.queue_free()
	item_buttons.clear()
	
	if not player:
		return
	
	# Filter items by current category
	var filtered_items = _get_filtered_items()
	
	# Create button for each item in filtered inventory
	for item in filtered_items:
		var item_btn = _create_item_button(item)
		inventory_grid.add_child(item_btn)
		item_buttons.append(item_btn)

func _get_filtered_items() -> Array:
	"""Get items matching current category filter"""
	if not player:
		return []
	
	if current_category == "All":
		return player.inventory
	
	var filtered = []
	for item in player.inventory:
		var item_slot = item.get("slot", "")
		
		# Normalize slot names for comparison (remove spaces, lowercase)
		var normalized_item_slot = item_slot.replace(" ", "").to_lower()
		var normalized_category = current_category.replace(" ", "").to_lower()
		
		# Check if item matches category
		if normalized_item_slot == normalized_category:
			filtered.append(item)
		elif current_category == "Consumable" and item.get("type", "") == "Consumable":
			filtered.append(item)
	
	return filtered

func _create_item_button(item: Dictionary) -> Button:
	"""Create a button for an inventory item"""
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(80, 80)
	
	# Show icon if available
	if item.has("icon") and item.icon:
		btn.icon = item.icon
		btn.expand_icon = true
	else:
		# Show colored square based on type
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = _get_item_type_color(item)
		btn.add_theme_stylebox_override("normal", stylebox)
		
		# Show first letter of item name
		var item_name = item.get("name", "?")
		btn.text = item_name[0] if item_name.length() > 0 else "?"
	
	btn.pressed.connect(_on_item_button_pressed.bind(item))
	
	return btn

func _get_item_type_color(item: Dictionary) -> Color:
	"""Get color for item type"""
	if item.has("slot"):
		return Color(0.4, 0.6, 0.4)  # Equipment - green
	
	match item.get("type", ""):
		"Consumable": return Color(0.6, 0.4, 0.6)  # Purple
		"Quest": return Color(0.7, 0.6, 0.2)  # Gold
		"Material": return Color(0.5, 0.5, 0.5)  # Gray
		_: return Color(0.4, 0.4, 0.4)

func _update_item_details():
	"""Update the item details panel"""
	if not item_details_panel:
		return
	
	# Find UI elements in details panel
	var name_labels = item_details_panel.find_children("ItemName", "Label", true, false)
	var image_rects = item_details_panel.find_children("ItemImage", "TextureRect", true, false)
	var desc_labels = item_details_panel.find_children("ItemDescription", "Label", true, false)
	var affixes_container = item_details_panel.find_children("AffixesContainer", "VBoxContainer", true, false)
	var action_containers = item_details_panel.find_children("ActionButtons", "HBoxContainer", true, false)
	
	if selected_item.is_empty():
		# No item selected
		if name_labels.size() > 0:
			name_labels[0].text = "No Item Selected"
		if image_rects.size() > 0:
			image_rects[0].texture = null
		if desc_labels.size() > 0:
			desc_labels[0].text = ""
		if affixes_container.size() > 0:
			for child in affixes_container[0].get_children():
				child.queue_free()
		if action_containers.size() > 0:
			action_containers[0].hide()
		return
	
	# Show item name
	if name_labels.size() > 0:
		name_labels[0].text = selected_item.get("name", "Unknown")
	
	# Show item image
	if image_rects.size() > 0:
		if selected_item.has("icon") and selected_item.icon:
			image_rects[0].texture = selected_item.icon
		else:
			# Create colored placeholder
			var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
			img.fill(_get_item_type_color(selected_item))
			image_rects[0].texture = ImageTexture.create_from_image(img)
	
	# Show item description
	if desc_labels.size() > 0:
		desc_labels[0].text = selected_item.get("description", "")
	
	# Show affixes
	if affixes_container.size() > 0:
		var affix_vbox = affixes_container[0]
		
		# Clear existing affixes
		for child in affix_vbox.get_children():
			child.queue_free()
		
		# Add affix displays
		if selected_item.has("affixes") and selected_item.affixes.size() > 0:
			for affix in selected_item.affixes:
				var affix_panel = _create_affix_display(affix)
				affix_vbox.add_child(affix_panel)
	
	# Update action buttons visibility
	if action_containers.size() > 0:
		action_containers[0].show()
		
		var buttons = action_containers[0].find_children("*", "Button", false, false)
		for btn in buttons:
			var btn_name = btn.name.to_lower()
			if "use" in btn_name:
				btn.visible = selected_item.get("type", "") == "Consumable"
			elif "equip" in btn_name:
				btn.visible = selected_item.has("slot")

func _create_affix_display(affix) -> PanelContainer:
	"""Create a visual display for a single affix"""
	var panel = PanelContainer.new()
	
	# Style the panel
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.2, 0.2, 0.3, 0.5)
	stylebox.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", stylebox)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	
	# Affix name
	var name_label = Label.new()
	var prefix_suffix = " (Prefix)" if affix.get("is_prefix", true) else " (Suffix)"
	name_label.text = affix.get("display_name", "Unknown") + prefix_suffix
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))  # Purple tint
	vbox.add_child(name_label)
	
	# Affix description
	var desc_label = Label.new()
	desc_label.text = affix.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	return panel

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_category_button_toggled(button_pressed: bool, category_name: String):
	"""Category button toggled"""
	if button_pressed:
		current_category = category_name
		print("🎒 Category changed to: %s" % category_name)
		refresh()

func _on_item_button_pressed(item: Dictionary):
	"""Item button clicked"""
	selected_item = item
	_update_item_details()
	item_selected.emit(item)  # Bubble up

func _on_use_item_pressed():
	"""Use item button pressed"""
	if selected_item.is_empty():
		return
	
	# Handle consumable items
	if selected_item.get("type", "") == "Consumable":
		_use_consumable(selected_item)
		item_used.emit(selected_item)  # Bubble up
		data_changed.emit()  # Bubble up

func _use_consumable(item: Dictionary):
	"""Use a consumable item"""
	if not player:
		return
	
	var effect = item.get("effect", "")
	var amount = item.get("amount", 0)
	
	match effect:
		"heal":
			player.heal(amount)
			print("💊 Used %s - Healed %d HP" % [item.get("name", ""), amount])
		"restore_mana":
			player.restore_mana(amount)
			print("💊 Used %s - Restored %d Mana" % [item.get("name", ""), amount])
		_:
			print("❓ Unknown consumable effect: %s" % effect)
	
	# Remove from inventory
	player.inventory.erase(item)
	selected_item = {}
	refresh()

func _on_equip_item_pressed():
	"""Equip item button pressed"""
	if selected_item.is_empty() or not player:
		return
	
	if player.equip_item(selected_item):
		item_equipped.emit(selected_item)  # Bubble up
		data_changed.emit()  # Bubble up
		selected_item = {}
		refresh()
		print("✅ Equipped: %s" % selected_item.get("name", ""))
