# character_tab.gd - Character stats display with dynamic UI
extends Control

var player: Player = null

# UI references (created dynamically)
var stats_container: VBoxContainer
var class_label: Label
var level_label: Label
var exp_bar: ProgressBar
var exp_label: Label

func _ready():
	print("👤 Character tab initializing...")
	setup_ui()
	print("👤 Character tab ready")

func setup_ui():
	"""Create UI structure dynamically"""
	print("  Creating character UI...")
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	
	# Class label
	class_label = Label.new()
	class_label.name = "ClassLabel"
	class_label.text = "Class: None"
	class_label.add_theme_font_size_override("font_size", 20)
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(class_label)
	
	# Level label
	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "Level: 1"
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_label)
	
	# Experience bar
	exp_bar = ProgressBar.new()
	exp_bar.name = "ExpBar"
	exp_bar.custom_minimum_size = Vector2(300, 30)
	exp_bar.show_percentage = false
	vbox.add_child(exp_bar)
	
	# Experience label
	exp_label = Label.new()
	exp_label.name = "ExpLabel"
	exp_label.text = "XP: 0 / 100"
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(exp_label)
	
	# Stats container
	stats_container = VBoxContainer.new()
	stats_container.name = "StatsContainer"
	stats_container.add_theme_constant_override("separation", 5)
	vbox.add_child(stats_container)
	
	# Connect to responsive system
	if has_node("/root/ResponsiveUI"):
		ResponsiveUI.screen_size_changed.connect(_on_screen_size_changed)
		print("  ✓ Connected to responsive system")
	
	print("  ✓ Character UI created")

func set_player(p_player: Player):
	"""Set player and refresh display"""
	print("👤 Character tab: Setting player")
	player = p_player
	refresh()

func refresh():
	"""Refresh all character stats"""
	if not player:
		print("  No player data")
		return
	
	print("  Refreshing character stats...")
	
	# Update class info
	if player.active_class:
		class_label.text = "Class: %s" % player.active_class.player_class_name
		level_label.text = "Level: %d" % player.active_class.level
		
		# Update experience bar
		var exp_progress = player.active_class.get_exp_progress()
		exp_bar.value = exp_progress * 100
		exp_label.text = "XP: %d / %d" % [player.active_class.experience, player.active_class.get_exp_for_next_level()]
	else:
		class_label.text = "No Class Selected"
		level_label.text = ""
		exp_label.text = ""
	
	# Clear old stats
	for child in stats_container.get_children():
		child.queue_free()
	
	# Display core stats
	add_stat_display("HP", "%d / %d" % [player.current_hp, player.max_hp], Color.RED)
	add_stat_display("Mana", "%d / %d" % [player.current_mana, player.max_mana], Color.CYAN)
	
	add_separator()
	
	# Display defensive stats
	add_stat_display("Armor", str(player.get_armor()), Color.GRAY)
	add_stat_display("Barrier", str(player.get_barrier()), Color.LIGHT_BLUE)
	
	add_separator()
	
	# Display primary stats
	add_stat_display("Strength", str(player.get_total_stat("strength")), Color.ORANGE_RED)
	add_stat_display("Agility", str(player.get_total_stat("agility")), Color.GREEN)
	add_stat_display("Intellect", str(player.get_total_stat("intellect")), Color.MEDIUM_PURPLE)
	add_stat_display("Luck", str(player.get_total_stat("luck")), Color.GOLD)
	
	add_separator()
	
	# Display derived stats
	add_stat_display("Crit Chance", "%.1f%%" % player.get_crit_chance(), Color.YELLOW)
	add_stat_display("Physical Damage", "+%d" % player.get_physical_damage_bonus(), Color.ORANGE_RED)
	add_stat_display("Magical Damage", "+%d" % player.get_magical_damage_bonus(), Color.MEDIUM_PURPLE)
	
	print("  ✓ Stats refreshed")

func add_stat_display(stat_name: String, value: String, color: Color = Color.WHITE):
	"""Add a stat display row"""
	var hbox = HBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = stat_name + ":"
	name_label.custom_minimum_size = Vector2(150, 0)
	name_label.add_theme_color_override("font_color", color)
	hbox.add_child(name_label)
	
	var value_label = Label.new()
	value_label.text = value
	value_label.add_theme_color_override("font_color", color)
	value_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(value_label)
	
	stats_container.add_child(hbox)

func add_separator():
	"""Add a visual separator"""
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 10)
	stats_container.add_child(separator)

func _on_screen_size_changed(screen_size: int):
	"""React to screen size changes"""
	print("👤 Character tab: Screen size changed to %s" % ResponsiveUI.get_size_name(screen_size))
	# Refresh display if needed
	if player:
		refresh()
