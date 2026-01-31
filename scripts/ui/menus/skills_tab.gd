# skills_tab.gd - Skills and skill trees display
# Self-registers with parent, emits signals upward
extends Control

# ============================================================================
# SIGNALS (emitted upward)
# ============================================================================
signal refresh_requested()
signal data_changed()
signal skill_learned(skill: Skill)

# ============================================================================
# STATE
# ============================================================================
var player: Player = null

# UI references (discovered dynamically)
var skill_points_label: Label
var class_label: Label
var tree_tabs: TabContainer
var reset_button: Button

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("menu_tabs")  # Self-register
	_discover_ui_elements()
	print("🌳 SkillsTab: Ready")

func _discover_ui_elements():
	"""Discover UI elements via self-registration groups"""
	await get_tree().process_frame  # Let children register themselves
	
	# Find UI elements by group and metadata
	var ui_elements = get_tree().get_nodes_in_group("skills_tab_ui")
	for element in ui_elements:
		match element.get_meta("ui_role", ""):
			"skill_points_label": skill_points_label = element
			"class_label": class_label = element
			"tree_tabs": tree_tabs = element
			"reset_button": 
				reset_button = element
				reset_button.pressed.connect(_on_reset_pressed)
	
	# Create UI if not found
	if not tree_tabs:
		_create_ui_structure()

func _create_ui_structure():
	"""Create UI if not defined in scene"""
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	
	# Skill points label
	skill_points_label = Label.new()
	skill_points_label.name = "SkillPointsLabel"
	skill_points_label.add_theme_font_size_override("font_size", 18)
	skill_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(skill_points_label)
	
	# Class label
	class_label = Label.new()
	class_label.name = "ClassLabel"
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(class_label)
	
	# Tree tabs
	tree_tabs = TabContainer.new()
	tree_tabs.name = "TreeTabs"
	tree_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tree_tabs)
	
	# Reset button
	reset_button = Button.new()
	reset_button.name = "ResetButton"
	reset_button.text = "Reset Skills"
	reset_button.pressed.connect(_on_reset_pressed)
	vbox.add_child(reset_button)

# ============================================================================
# PUBLIC API
# ============================================================================

func set_player(p_player: Player):
	"""Set player and refresh"""
	player = p_player
	
	# Connect to player signals
	if player and player.active_class:
		# Listen for class changes
		if not player.class_changed.is_connected(_on_player_class_changed):
			player.class_changed.connect(_on_player_class_changed)
	
	refresh()

func refresh():
	"""Refresh all skill displays"""
	if not player or not player.active_class:
		_show_no_class_message()
		return
	
	_update_header_info()
	_rebuild_skill_trees()

func on_external_data_change():
	"""Called when other tabs modify player data"""
	refresh()

# ============================================================================
# PRIVATE DISPLAY METHODS
# ============================================================================

func _update_header_info():
	"""Update skill points and class name"""
	var active_class = player.active_class
	
	if skill_points_label:
		var available = active_class.get_available_skill_points()
		var total = active_class.total_skill_points
		skill_points_label.text = "Skill Points: %d / %d" % [available, total]
	
	if class_label:
		class_label.text = "Class: %s" % active_class.player_class_name

func _rebuild_skill_trees():
	"""Rebuild all skill tree tabs"""
	if not tree_tabs:
		return
	
	# Clear existing tabs
	for child in tree_tabs.get_children():
		child.queue_free()
	
	# Create tab for each skill tree
	var active_class = player.active_class
	for tree_name in active_class.skill_trees:
		var skill_tree = active_class.skill_trees[tree_name]
		var tree_tab = _create_skill_tree_tab(skill_tree)
		tree_tabs.add_child(tree_tab)
		tree_tab.name = tree_name

func _create_skill_tree_tab(skill_tree) -> Control:
	"""Create a tab for a skill tree"""
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	
	# Add skill buttons
	for skill in skill_tree.skills:
		var skill_panel = _create_skill_panel(skill)
		vbox.add_child(skill_panel)
	
	return scroll

func _create_skill_panel(skill) -> Control:
	"""Create a panel for a single skill"""
	var panel = PanelContainer.new()
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	# Skill name
	var name_label = Label.new()
	name_label.text = skill.skill_name
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	# Rank display
	var rank_label = Label.new()
	rank_label.text = "Rank: %d / %d" % [skill.current_rank, skill.max_rank]
	vbox.add_child(rank_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = skill.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	# Learn button
	var learn_button = Button.new()
	learn_button.text = "Learn" if skill.current_rank == 0 else "Upgrade"
	learn_button.disabled = not player.active_class.can_learn_skill(skill)
	learn_button.pressed.connect(_on_skill_learn_pressed.bind(skill))
	vbox.add_child(learn_button)
	
	# Requirements (if any)
	if skill.requirements.size() > 0:
		var req_label = RichTextLabel.new()
		req_label.bbcode_enabled = true
		req_label.custom_minimum_size = Vector2(0, 40)
		req_label.fit_content = true
		
		var req_text = "[color=gray]Requires:[/color]\n"
		for req in skill.requirements:
			var req_skill = player.active_class.find_skill_by_name(req.skill_name)
			var has_req = req_skill and req_skill.current_rank >= req.required_rank
			var color = "green" if has_req else "red"
			req_text += "[color=%s]• %s (Rank %d)[/color]\n" % [color, req.skill_name, req.required_rank]
		
		req_label.text = req_text
		vbox.add_child(req_label)
	
	return panel

func _show_no_class_message():
	"""Display message when no class is active"""
	if skill_points_label:
		skill_points_label.text = "No Class Selected"
	if class_label:
		class_label.text = ""
	
	# Clear tree tabs
	if tree_tabs:
		for child in tree_tabs.get_children():
			child.queue_free()

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_skill_learn_pressed(skill):
	"""Skill learn button pressed"""
	if not player or not player.active_class:
		return
	
	if player.active_class.learn_skill(skill):
		skill_learned.emit(skill)  # Bubble up
		data_changed.emit()  # Bubble up
		refresh()  # Refresh this tab
		print("✅ Learned skill: %s" % skill.skill_name)

func _on_reset_pressed():
	"""Reset button pressed"""
	if not player or not player.active_class:
		return
	
	# Reset all skills
	for tree_name in player.active_class.skill_trees:
		var tree = player.active_class.skill_trees[tree_name]
		tree.reset_all_skills()
	
	# Refund skill points
	player.active_class.spent_skill_points = 0
	
	data_changed.emit()  # Bubble up
	refresh()
	print("🔄 Skills reset")

func _on_player_class_changed(_new_class):
	"""Player switched classes"""
	refresh()
