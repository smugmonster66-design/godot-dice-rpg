# skills_tab.gd - Scene-based skills tab (no dynamic UI creation!)
extends Control

# ============================================================================
# EXPORTS - Configure in Inspector
# ============================================================================
@export var skill_tree_panel_scene: PackedScene = null

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var skill_points_label = $VBox/SkillPointsLabel
@onready var class_label = $VBox/ClassLabel
@onready var tree_tabs = $VBox/TreeTabs
@onready var reset_button = $VBox/ResetButton

# ============================================================================
# STATE
# ============================================================================
var player: Player = null

# Store references to tree panels (created once, reused forever)
var tree_panels: Dictionary = {}
var is_initialized: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("📚 Skills tab ready")
	
	# Verify scene is set
	if not skill_tree_panel_scene:
		print("  ⚠️ WARNING: skill_tree_panel_scene not set in Inspector!")
	
	# Connect reset button
	reset_button.pressed.connect(_on_reset_pressed)
	
	# Connect to responsive system
	if has_node("/root/ResponsiveUI"):
		ResponsiveUI.screen_size_changed.connect(_on_screen_size_changed)
		print("  ✓ Connected to responsive system")

# ============================================================================
# PLAYER SETUP
# ============================================================================

func set_player(p_player: Player):
	"""Set player and refresh display"""
	print("📚 Skills tab: Setting player")
	player = p_player
	
	# Create tabs on first setup only
	if not is_initialized:
		setup_tree_tabs()
		is_initialized = true
	else:
		# Just refresh existing tabs
		print("  🔄 Refreshing existing tabs...")
		refresh()

# ============================================================================
# TAB CREATION (ONCE!)
# ============================================================================

func setup_tree_tabs():
	"""Create tabs for each skill tree (called once)"""
	if not player or not player.active_class:
		print("  No player or active class")
		return
	
	# Verify scene is set
	if not skill_tree_panel_scene:
		print("  ❌ ERROR: Cannot create skill trees - skill_tree_panel_scene not set!")
		return
	
	print("  🏗️ Creating skill tree tabs (first time)...")
	
	# Update header info
	update_header()
	
	# Create a tab for each skill tree
	if player.active_class and player.active_class.skill_trees:
		for tree_name in player.active_class.skill_trees:
			var tree = player.active_class.skill_trees[tree_name]
			var tree_panel = create_skill_tree_panel(tree)
			if tree_panel:
				tree_panel.name = tree_name
				tree_tabs.add_child(tree_panel)
				tree_panels[tree_name] = tree_panel
				print("  ✓ Created tab: %s" % tree_name)

func create_skill_tree_panel(tree):
	"""Create a panel from scene (called once per tree)"""
	if not skill_tree_panel_scene:
		print("  ❌ Cannot create panel: scene not set")
		return null
	
	# Instance the scene
	var panel = skill_tree_panel_scene.instantiate()
	
	# Connect signal BEFORE adding to tree
	if panel.has_signal("skill_clicked"):
		panel.skill_clicked.connect(_on_skill_clicked)
	else:
		print("  ⚠️ WARNING: skill_tree_panel has no skill_clicked signal")
	
	# Add to tree (triggers _ready)
	tree_tabs.add_child(panel)
	
	# Now setup (nodes are ready)
	if panel.has_method("setup"):
		panel.setup(player, tree)
	else:
		print("  ⚠️ WARNING: skill_tree_panel has no setup method")
	
	return panel

# ============================================================================
# REFRESH (REUSES EXISTING TABS)
# ============================================================================

func refresh():
	"""Refresh the display (doesn't recreate tabs!)"""
	if not player or not player.active_class:
		return
	
	# Update header
	update_header()
	
	# Refresh all existing tree panels
	for tree_name in tree_panels:
		if tree_panels[tree_name] and tree_panels[tree_name].has_method("refresh"):
			tree_panels[tree_name].refresh()

func update_header():
	"""Update the header labels"""
	if player and player.active_class:
		class_label.text = "Class: %s (Level %d)" % [player.active_class.player_class_name, player.active_class.level]
		skill_points_label.text = "Available Skill Points: %d" % player.active_class.get_available_skill_points()
	else:
		class_label.text = "Class: None"
		skill_points_label.text = "Available Skill Points: 0"

# ============================================================================
# SKILL INTERACTION
# ============================================================================

func _on_skill_clicked(skill):
	"""Skill was clicked - try to learn it"""
	if player and player.active_class and player.active_class.learn_skill(skill):
		refresh()
		print("✅ Learned skill: %s" % skill.skill_name)
	else:
		print("❌ Cannot learn skill: %s" % skill.skill_name)

func _on_reset_pressed():
	"""Reset button clicked"""
	if not player or not player.active_class:
		return
	
	print("🔄 Resetting all skills...")
	player.active_class.reset_skills()
	refresh()
	print("✅ Skills reset")

# ============================================================================
# RESPONSIVE UI
# ============================================================================

func _on_screen_size_changed(screen_size: int):
	"""React to screen size changes"""
	print("📚 Skills tab: Screen size changed to %s" % ResponsiveUI.get_size_name(screen_size))
