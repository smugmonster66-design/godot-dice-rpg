# dice_pool_display.gd - Displays available dice from player's pool
extends HBoxContainer

# ============================================================================
# EXPORTS
# ============================================================================
@export var die_visual_scene: PackedScene = null


# ============================================================================
# STATE
# ============================================================================
var dice_pool = null  # PlayerDicePool reference (accept any type for flexibility)
var die_visuals: Array[Control] = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("🎲 DicePoolDisplay _ready")
	print("  - mouse_filter: %d" % mouse_filter)

func initialize(pool):
	"""Initialize with dice pool"""
	print("🎲 DicePoolDisplay.initialize() called")
	dice_pool = pool
	
	if not dice_pool:
		print("  ⚠️ WARNING: dice_pool is null!")
		return
	
	print("  ✅ Player dice pool has %d dice in pool, %d in hand" % [dice_pool.dice.size(), dice_pool.hand.size()])
	
	# Connect to hand signals (for combat)
	if dice_pool.has_signal("hand_rolled"):
		if not dice_pool.hand_rolled.is_connected(_on_hand_rolled):
			dice_pool.hand_rolled.connect(_on_hand_rolled)
			print("  ✅ Connected to hand_rolled signal")
	
	if dice_pool.has_signal("hand_changed"):
		if not dice_pool.hand_changed.is_connected(refresh):
			dice_pool.hand_changed.connect(refresh)
			print("  ✅ Connected to hand_changed signal")
	
	# Initial display
	refresh()

func _on_hand_rolled(_hand: Array):
	"""Hand was rolled - refresh display"""
	print("🎲 DicePoolDisplay: hand_rolled signal received")
	#refresh()

# ============================================================================
# DISPLAY
# ============================================================================

func refresh():
	"""Refresh the dice display"""
	print("🎲 DicePoolDisplay.refresh() called")
	
	if not dice_pool:
		print("  ⚠️ Cannot refresh: dice_pool is null")
		return
	
	# Clear existing visuals
	clear_display()
	
	# Create visuals for available dice
	var available = dice_pool.available_dice
	print("  📊 Displaying %d available dice" % available.size())
	
	for i in range(available.size()):
		var die = available[i]
		print("    Creating visual for die %d: %s" % [i, die.get_display_name()])
		var visual = create_die_visual(die)
		if visual:
			add_child(visual)
			die_visuals.append(visual)
			print("      ✅ Added to scene tree")
	
	print("  ✅ Total visuals in tree: %d" % get_child_count())

func clear_display():
	"""Remove all die visuals"""
	for visual in die_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	die_visuals.clear()
	
	# Also clear any remaining children
	for child in get_children():
		child.queue_free()

func create_die_visual(die: DieResource) -> Control:
	if not die_visual_scene:
		print("  ❌ ERROR: die_visual_scene not set in Inspector!")
		return null
	
	var visual = die_visual_scene.instantiate()
	
	# DieVisual uses set_die(), not initialize()
	if visual.has_method("set_die"):
		visual.set_die(die)
		print("      ✅ set_die() called with %s = %d" % [die.display_name, die.get_total_value()])
	else:
		print("      ⚠️ WARNING: No set_die method on visual")
	
	return visual




# ============================================================================
# UTILITY
# ============================================================================

func get_die_visual_at_position(pos: Vector2) -> Control:
	"""Get die visual at a specific position"""
	for visual in die_visuals:
		if visual and visual.get_global_rect().has_point(pos):
			return visual
	return null
