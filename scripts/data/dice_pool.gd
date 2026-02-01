# dice_pool.gd - Visual display of player's DieData dice
extends HBoxContainer

var player: Player = null

func initialize(p_player: Player):
	player = p_player
	
	if player.dice_pool:
		player.dice_pool.dice_rolled.connect(_on_dice_rolled)
		display_dice()

func _on_dice_rolled(_dice: Array):
	display_dice()

func display_dice():
	# Clear existing
	for child in get_children():
		child.queue_free()
	
	if not player or not player.dice_pool:
		return
	
	# Create visual for each available die
	for die in player.dice_pool.available_dice:
		var die_visual = create_die_visual(die)
		add_child(die_visual)

func create_die_visual(die: DieResource) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(60, 60)
	
	# Enable drag detection on the panel itself
	var drag_detector = Control.new()
	drag_detector.set_anchors_preset(Control.PRESET_FULL_RECT)
	drag_detector.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Override drag functions on the drag detector
	drag_detector.set_script(preload("res://scripts/die_drag_handler.gd"))
	drag_detector.die_data = die
	
	panel.add_child(drag_detector)
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_detector.add_child(vbox)
	
	# Die type label
	var type_label = Label.new()
	type_label.text = "D%d" % die.die_type
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(type_label)
	
	# Current value
	var value_label = Label.new()
	value_label.text = str(die.get_total_value())
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 24)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(value_label)
	
	# Tags
	if die.tags.size() > 0:
		var tag_label = Label.new()
		tag_label.text = "[%s]" % ", ".join(die.tags)
		tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_label.add_theme_font_size_override("font_size", 8)
		tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(tag_label)
	
	# Color based on die
	panel.modulate = die.color
	
	return panel
