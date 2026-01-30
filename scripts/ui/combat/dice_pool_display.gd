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
	
	print("  ✅ Player dice pool has %d dice" % dice_pool.available_dice.size())
	
	# Connect to dice rolled signal
	if dice_pool.has_signal("dice_rolled"):
		if not dice_pool.dice_rolled.is_connected(refresh):
			dice_pool.dice_rolled.connect(refresh)
			print("  ✅ Connected to dice_rolled signal")
	
	# Initial display
	refresh()

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

func create_die_visual(die: DieData) -> Control:
	"""Create a visual representation of a die"""
	# Check if scene is set
	if not die_visual_scene:
		print("  ❌ ERROR: die_visual_scene not set in Inspector!")
		return null
	
	var visual = die_visual_scene.instantiate()
	
	# Initialize it
	print("    🔧 Calling initialize() on visual...")
	if visual.has_method("initialize"):
		visual.initialize(die)  # true = can drag
		print("      ✅ Initialized with %s" % die.get_display_name())
	else:
		print("      ⚠️ WARNING: DieVisual has no initialize method")
	
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
