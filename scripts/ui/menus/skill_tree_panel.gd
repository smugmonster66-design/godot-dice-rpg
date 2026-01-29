# skill_tree_panel.gd - Node-based skill tree display
extends Control

# ============================================================================
# EXPORTS
# ============================================================================
@export var skill_button_scene: PackedScene = null

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var tree_name_label = $VBox/TreeNameLabel
@onready var tree_desc_label = $VBox/TreeDescLabel
@onready var skill_grid = $VBox/ScrollContainer/SkillGrid

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var skill_tree = null  # SkillTree resource

# Track created skill buttons for refresh (don't recreate!)
var skill_buttons: Array = []

# Pending setup data (in case setup() is called before _ready())
var pending_setup: Dictionary = {}

# ============================================================================
# SIGNALS
# ============================================================================
signal skill_clicked(skill)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("🌳 SkillTreePanel ready")
	
	# Verify skill button scene is set
	if not skill_button_scene:
		print("  ⚠️ WARNING: skill_button_scene not set in Inspector!")
	
	# If setup was called before _ready, apply it now
	if pending_setup.size() > 0:
		print("  🔄 Applying pending setup...")
		setup(pending_setup.player, pending_setup.tree)
		pending_setup.clear()

# ============================================================================
# SETUP
# ============================================================================

func setup(p_player: Player, p_tree):
	"""Setup with player and skill tree"""
	print("🌳 Setting up skill tree: %s" % (p_tree.tree_name if p_tree else "null"))
	
	player = p_player
	skill_tree = p_tree
	
	# If nodes aren't ready yet, store setup data for later
	if not is_node_ready():
		print("  ⏳ Nodes not ready yet, deferring setup...")
		pending_setup = {"player": p_player, "tree": p_tree}
		return
	
	# Set tree info
	if skill_tree:
		tree_name_label.text = skill_tree.tree_name
		tree_desc_label.text = skill_tree.description
	
	# Build skill tree (creates buttons once)
	build_skill_tree()

# ============================================================================
# SKILL DISPLAY
# ============================================================================

func build_skill_tree():
	"""Build the visual skill tree (called once on setup)"""
	if not is_node_ready():
		print("  ⏳ Nodes not ready yet, cannot build tree")
		return
	
	if not skill_button_scene:
		print("  ❌ Cannot build skill tree: skill_button_scene not set!")
		return
	
	# Only create if empty
	if skill_buttons.size() > 0:
		print("  ℹ️ Skill buttons already exist, refreshing instead...")
		refresh_skill_buttons()
		return
	
	# Clear existing (just in case)
	for child in skill_grid.get_children():
		child.queue_free()
	
	skill_buttons.clear()
	
	# Create skills
	if skill_tree and skill_tree.skills:
		print("  🔨 Building %d skills..." % skill_tree.skills.size())
		for skill in skill_tree.skills:
			var skill_button = create_skill_button(skill)
			if skill_button:
				skill_grid.add_child(skill_button)
				skill_buttons.append(skill_button)
		print("  ✅ Tree built successfully")

func create_skill_button(skill):
	"""Create a skill button from scene"""
	var button = skill_button_scene.instantiate()
	
	# Connect signal FIRST
	if button.has_signal("learn_clicked"):
		button.learn_clicked.connect(func(): _on_skill_learn_clicked(skill))
	else:
		print("  ⚠️ WARNING: skill_button has no learn_clicked signal")
	
	# Initialize the button with skill data
	if button.has_method("initialize"):
		button.initialize(skill, player)
	else:
		print("  ⚠️ WARNING: skill_button has no initialize method")
	
	return button

func refresh_skill_buttons():
	"""Refresh existing skill buttons (don't recreate!)"""
	print("  🔄 Refreshing %d skill buttons..." % skill_buttons.size())
	for button in skill_buttons:
		if button and is_instance_valid(button) and button.has_method("update_display"):
			button.update_display()

# ============================================================================
# INTERACTION
# ============================================================================

func _on_skill_learn_clicked(skill):
	"""Skill learn button clicked"""
	print("🌳 Skill clicked: %s" % skill.skill_name)
	skill_clicked.emit(skill)
	# Refresh just this tree
	refresh()

func refresh():
	"""Refresh the skill tree display (updates existing buttons)"""
	if is_node_ready() and skill_buttons.size() > 0:
		refresh_skill_buttons()
	else:
		print("  ⏳ Cannot refresh: not ready or no buttons")
