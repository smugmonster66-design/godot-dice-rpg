# skill_button.gd - Individual skill button component
extends PanelContainer

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var name_label = $VBox/NameLabel
@onready var rank_label = $VBox/RankLabel
@onready var desc_label = $VBox/DescLabel
@onready var learn_button = $VBox/LearnButton
@onready var requirements_label = $VBox/RequirementsLabel

# ============================================================================
# STATE
# ============================================================================
var skill = null  # Skill resource
var player: Player = null

# Pending initialization data
var pending_init: Dictionary = {}

# ============================================================================
# SIGNALS
# ============================================================================
signal learn_clicked()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	# Connect button
	if learn_button:
		learn_button.pressed.connect(_on_learn_pressed)
	
	# If initialize was called before _ready, apply it now
	if pending_init.size() > 0:
		print("  🔄 Applying pending skill initialization...")
		initialize(pending_init.skill, pending_init.player)
		pending_init.clear()

func initialize(p_skill, p_player: Player):
	"""Initialize with skill data and player"""
	skill = p_skill
	player = p_player
	
	# If nodes aren't ready yet, store init data for later
	if not is_node_ready():
		pending_init = {"skill": p_skill, "player": p_player}
		return
	
	update_display()

# ============================================================================
# DISPLAY
# ============================================================================

func update_display():
	"""Update all visual elements"""
	if not skill:
		return
	
	if not is_node_ready():
		print("  ⏳ Cannot update display: nodes not ready")
		return
	
	# Set text
	name_label.text = skill.skill_name
	rank_label.text = "%d / %d" % [skill.current_rank, skill.max_rank]
	desc_label.text = skill.description
	
	# Update rank color
	if skill.current_rank > 0:
		rank_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		rank_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Update button state
	update_button_state()
	
	# Update background color
	update_background_color()
	
	# Update requirements
	update_requirements()

func update_button_state():
	"""Update learn button text and state"""
	if not is_node_ready() or not skill:
		return
	
	if skill.current_rank >= skill.max_rank:
		learn_button.text = "MAXED"
		learn_button.disabled = true
	elif skill.current_rank > 0:
		learn_button.text = "Upgrade"
		learn_button.disabled = not can_learn()
	else:
		learn_button.text = "Learn"
		learn_button.disabled = not can_learn()

func update_background_color():
	"""Update background based on skill state"""
	if not skill:
		return
	
	var stylebox = StyleBoxFlat.new()
	
	if skill.current_rank >= skill.max_rank:
		stylebox.bg_color = Color(0.2, 0.5, 0.2)  # Green - maxed
	elif skill.current_rank > 0:
		stylebox.bg_color = Color(0.3, 0.4, 0.5)  # Blue - learned
	elif can_learn():
		stylebox.bg_color = Color(0.5, 0.5, 0.2)  # Yellow - available
	else:
		stylebox.bg_color = Color(0.2, 0.2, 0.2)  # Gray - locked
	
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	stylebox.border_width_top = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.6, 0.6, 0.6)
	stylebox.corner_radius_top_left = 4
	stylebox.corner_radius_top_right = 4
	stylebox.corner_radius_bottom_left = 4
	stylebox.corner_radius_bottom_right = 4
	
	add_theme_stylebox_override("panel", stylebox)

func update_requirements():
	"""Update requirements display"""
	if not is_node_ready() or not skill:
		return
	
	if skill.current_rank > 0 or skill.requirements.size() == 0:
		requirements_label.hide()
		return
	
	var req_text = "Requires:\n"
	for req in skill.requirements:
		if player and player.active_class:
			var req_skill = player.active_class.find_skill_by_name(req.skill_name)
			var met = req_skill and req_skill.current_rank >= req.required_rank
			var color = "[color=green]" if met else "[color=red]"
			req_text += "%s%s (%d)[/color]\n" % [color, req.skill_name, req.required_rank]
	
	requirements_label.text = req_text
	requirements_label.show()

func can_learn() -> bool:
	"""Check if skill can be learned"""
	if not player or not player.active_class:
		return false
	return player.active_class.can_learn_skill(skill)

# ============================================================================
# INTERACTION
# ============================================================================

func _on_learn_pressed():
	"""Learn button pressed"""
	learn_clicked.emit()
