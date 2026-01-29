# dice_pool_display.gd - Visual dice pool
extends HBoxContainer

# ============================================================================
# CONSTANTS
# ============================================================================
const DIE_VISUAL_SCENE = preload("res://scenes/ui/components/die_visual.tscn")

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var die_visuals: Array[Control] = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("🎲 DicePoolDisplay _ready")
	
	# Don't block input to children
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Clear any pre-existing children
	for child in get_children():
		print("  ⚠️ Removing pre-existing child: %s" % child.name)
		child.queue_free()
	
	print("  - mouse_filter: %s" % mouse_filter)

func initialize(p_player: Player):
	"""Initialize with player"""
	print("🎲 DicePoolDisplay.initialize() called")
	player = p_player
	
	if not player:
		print("  ❌ Player is null!")
		return
	
	if not player.dice_pool:
		print("  ❌ Player has no dice pool!")
		return
	
	print("  ✅ Player dice pool has %d dice" % player.dice_pool.available_dice.size())
	
	# Connect to dice rolled signal
	if not player.dice_pool.dice_rolled.is_connected(_on_dice_rolled):
		player.dice_pool.dice_rolled.connect(_on_dice_rolled)
		print("  ✅ Connected to dice_rolled signal")
	
	# Display current dice
	refresh()

# ============================================================================
# PUBLIC API
# ============================================================================

func refresh():
	"""Refresh displayed dice"""
	print("🎲 DicePoolDisplay.refresh() called")
	
	# Clear existing visuals
	for visual in die_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	die_visuals.clear()
	
	# Clear container children
	for child in get_children():
		child.queue_free()
	
	if not player or not player.dice_pool:
		print("  ❌ No player or dice pool")
		return
	
	var available = player.dice_pool.available_dice
	print("  📊 Displaying %d available dice" % available.size())
	
	if available.size() == 0:
		print("  ⚠️ No dice available to display!")
		var empty_label = Label.new()
		empty_label.text = "No dice available"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(empty_label)
		return
	
	# Create visual for each available die
	for i in range(available.size()):
		var die = available[i]
		print("    Creating visual for die %d: %s" % [i, die.get_display_name()])
		
		var visual = create_die_visual(die)
		if visual:
			add_child(visual)
			die_visuals.append(visual)
			print("      ✅ Added to scene tree")
		else:
			print("      ❌ Failed to create visual")
	
	print("  ✅ Total visuals in tree: %d" % get_child_count())
	
	# Verify after one frame
	await get_tree().process_frame
	print("  🔍 Post-frame verification:")
	for i in range(get_child_count()):
		var child = get_child(i)
		if child.has_method("initialize"):
			print("    - Die %d: visible=%s, mouse_filter=%s, has_die_data=%s" % [
				i, 
				child.visible, 
				child.mouse_filter,
				child.die_data != null
			])

func create_die_visual(die: DieData) -> Control:
	"""Create visual for a die"""
	if not DIE_VISUAL_SCENE:
		print("    ❌ DIE_VISUAL_SCENE not loaded!")
		return null
	
	var visual = DIE_VISUAL_SCENE.instantiate()
	
	if not visual:
		print("    ❌ Failed to instantiate scene")
		return null
	
	# CRITICAL: Initialize with die data BEFORE adding to tree
	if visual.has_method("initialize"):
		print("    🔧 Calling initialize() on visual...")
		visual.initialize(die)
		print("      ✅ Initialized with %s" % die.get_display_name())
	else:
		print("    ❌ Visual has no initialize() method!")
		visual.queue_free()
		return null
	
	return visual

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_dice_rolled(dice: Array):
	"""Dice were rolled"""
	print("🎲 Dice rolled signal received: %d dice" % dice.size())
	refresh()
