# res://scripts/ui/menus/skills_tab.gd
# Skills tab with sub-tabs for each skill tree
extends Control
class_name SkillsTab

# ============================================================================
# SIGNALS
# ============================================================================
signal skill_learned(skill: SkillResource, new_rank: int)

# ============================================================================
# NODE REFERENCES
# ============================================================================
@export_group("Header")
@export var skill_points_label: Label
@export var class_name_label: Label

@export_group("Tree Tabs")
@export var tree_tab_container: HBoxContainer
@export var tree_tab_1: Button
@export var tree_tab_2: Button
@export var tree_tab_3: Button

@export_group("Content Areas")
@export var tree_content_1: Control
@export var tree_content_2: Control
@export var tree_content_3: Control

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var current_tree_index: int = 0
var skill_ranks: Dictionary = {}  # skill_id -> current_rank

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_connect_tab_buttons()
	_connect_skill_slots()
	_show_tree(0)
	print("🌳 SkillsTab: Ready")

func _connect_tab_buttons():
	"""Connect tree tab buttons"""
	if tree_tab_1:
		tree_tab_1.pressed.connect(_on_tree_tab_pressed.bind(0))
	if tree_tab_2:
		tree_tab_2.pressed.connect(_on_tree_tab_pressed.bind(1))
	if tree_tab_3:
		tree_tab_3.pressed.connect(_on_tree_tab_pressed.bind(2))

func _connect_skill_slots():
	"""Find and connect all SkillSlot nodes in content areas"""
	for content in [tree_content_1, tree_content_2, tree_content_3]:
		if not content:
			continue
		
		for slot in _find_skill_slots(content):
			if not slot.skill_clicked.is_connected(_on_skill_clicked):
				slot.skill_clicked.connect(_on_skill_clicked)

func _find_skill_slots(node: Node) -> Array[SkillSlot]:
	"""Recursively find all SkillSlot children"""
	var slots: Array[SkillSlot] = []
	
	for child in node.get_children():
		if child is SkillSlot:
			slots.append(child)
		slots.append_array(_find_skill_slots(child))
	
	return slots

# ============================================================================
# PUBLIC API
# ============================================================================

func set_player(p_player: Player):
	"""Set player reference and refresh display"""
	player = p_player
	refresh()

func refresh():
	"""Refresh entire tab display"""
	_update_header()
	_update_tree_tabs()
	_update_skill_slots()

func on_external_data_change():
	"""Called when other tabs modify player data"""
	refresh()

# ============================================================================
# HEADER
# ============================================================================

func _update_header():
	if not player:
		if skill_points_label:
			skill_points_label.text = "No player"
		return
	
	if not player.active_class:
		if skill_points_label:
			skill_points_label.text = "No class selected"
		if class_name_label:
			class_name_label.text = ""
		return
	
	var active_class = player.active_class
	
	if class_name_label:
		class_name_label.text = active_class.player_class_name
	
	if skill_points_label:
		var available = active_class.get_available_skill_points()
		var total = active_class.total_skill_points
		skill_points_label.text = "Skill Points: %d / %d" % [available, total]

# ============================================================================
# TREE TABS
# ============================================================================

func _update_tree_tabs():
	"""Update tree tab names and visibility"""
	if not player or not player.active_class:
		_hide_all_tabs()
		return
	
	var trees = player.active_class.get_skill_trees()
	
	# Update tab 1
	if tree_tab_1:
		if trees.size() > 0 and trees[0]:
			tree_tab_1.text = trees[0].tree_name
			tree_tab_1.show()
		else:
			tree_tab_1.hide()
	
	# Update tab 2
	if tree_tab_2:
		if trees.size() > 1 and trees[1]:
			tree_tab_2.text = trees[1].tree_name
			tree_tab_2.show()
		else:
			tree_tab_2.hide()
	
	# Update tab 3
	if tree_tab_3:
		if trees.size() > 2 and trees[2]:
			tree_tab_3.text = trees[2].tree_name
			tree_tab_3.show()
		else:
			tree_tab_3.hide()
	
	_update_tab_highlight()

func _hide_all_tabs():
	"""Hide all tree tabs when no class is active"""
	if tree_tab_1:
		tree_tab_1.hide()
	if tree_tab_2:
		tree_tab_2.hide()
	if tree_tab_3:
		tree_tab_3.hide()

func _update_tab_highlight():
	"""Highlight the active tab"""
	var tabs = [tree_tab_1, tree_tab_2, tree_tab_3]
	
	for i in range(tabs.size()):
		var tab = tabs[i]
		if tab:
			tab.button_pressed = (i == current_tree_index)

func _on_tree_tab_pressed(index: int):
	"""Switch to a different skill tree"""
	_show_tree(index)

func _show_tree(index: int):
	"""Show the specified tree content, hide others"""
	current_tree_index = index
	
	if tree_content_1:
		tree_content_1.visible = (index == 0)
	if tree_content_2:
		tree_content_2.visible = (index == 1)
	if tree_content_3:
		tree_content_3.visible = (index == 2)
	
	_update_tab_highlight()

# ============================================================================
# SKILL SLOTS
# ============================================================================

func _update_skill_slots():
	"""Update all skill slot states based on player data"""
	if not player or not player.active_class:
		return
	
	for content in [tree_content_1, tree_content_2, tree_content_3]:
		if not content:
			continue
		
		for slot in _find_skill_slots(content):
			_update_single_skill_slot(slot)

func _update_single_skill_slot(slot: SkillSlot):
	"""Update a single skill slot's state"""
	var skill = slot.get_skill()
	if not skill:
		return
	
	var skill_id = skill.skill_id
	var current_rank = skill_ranks.get(skill_id, 0)
	
	slot.set_rank(current_rank)
	
	# Check if prerequisites are met
	if _are_prerequisites_met(skill):
		if current_rank >= skill.get_max_rank():
			slot.set_state(SkillButton.State.MAXED)
		else:
			slot.set_state(SkillButton.State.AVAILABLE)
	else:
		slot.set_state(SkillButton.State.LOCKED)

func _are_prerequisites_met(skill: SkillResource) -> bool:
	"""Check if all prerequisites for a skill are met"""
	if skill.required_skills.is_empty():
		return true
	
	for required_skill in skill.required_skills:
		if not required_skill:
			continue
		
		var required_id = required_skill.skill_id
		var current_rank = skill_ranks.get(required_id, 0)
		
		# Require at least 1 rank in prerequisite
		if current_rank < 1:
			return false
	
	return true

# ============================================================================
# SKILL LEARNING
# ============================================================================

func _on_skill_clicked(skill: SkillResource):
	"""Handle skill slot click"""
	if not player or not player.active_class:
		print("🌳 No player or class")
		return
	
	if not skill:
		print("🌳 No skill on clicked slot")
		return
	
	var skill_id = skill.skill_id
	var current_rank = skill_ranks.get(skill_id, 0)
	var max_rank = skill.get_max_rank()
	
	# Check if already maxed
	if current_rank >= max_rank:
		print("🌳 %s is already maxed (%d/%d)" % [skill.skill_name, current_rank, max_rank])
		return
	
	# Check prerequisites
	if not _are_prerequisites_met(skill):
		print("🌳 Prerequisites not met for %s" % skill.skill_name)
		_show_missing_prerequisites(skill)
		return
	
	# Check skill points
	var available_points = player.active_class.get_available_skill_points()
	if available_points < skill.skill_point_cost:
		print("🌳 Not enough skill points for %s (need %d, have %d)" % [
			skill.skill_name, skill.skill_point_cost, available_points
		])
		return
	
	# Learn the skill!
	_learn_skill(skill)

func _show_missing_prerequisites(skill: SkillResource):
	"""Log which prerequisites are missing"""
	for required_skill in skill.required_skills:
		if not required_skill:
			continue
		
		var required_id = required_skill.skill_id
		var current_rank = skill_ranks.get(required_id, 0)
		
		if current_rank < 1:
			print("  ❌ Missing: %s" % required_skill.skill_name)

func _learn_skill(skill: SkillResource):
	"""Actually learn/rank up a skill"""
	var skill_id = skill.skill_id
	var current_rank = skill_ranks.get(skill_id, 0)
	var new_rank = current_rank + 1
	
	# Spend skill point(s)
	for i in range(skill.skill_point_cost):
		if not player.active_class.spend_skill_point():
			print("🌳 Failed to spend skill point!")
			return
	
	# Update rank tracking
	skill_ranks[skill_id] = new_rank
	
	# Apply affixes from the new rank
	var new_affixes = skill.get_affixes_for_rank(new_rank)
	for affix in new_affixes:
		if affix:
			var affix_copy = affix.duplicate_with_source(skill.skill_name, "skill")
			player.affix_manager.add_affix(affix_copy)
			print("  ✨ Applied affix: %s" % affix.affix_name)
	
	print("🌳 Learned %s rank %d!" % [skill.skill_name, new_rank])
	
	# Emit signal
	skill_learned.emit(skill, new_rank)
	
	# Refresh display
	refresh()

# ============================================================================
# SKILL REFUND (optional feature)
# ============================================================================

func refund_skill(skill: SkillResource) -> bool:
	"""Remove a rank from a skill and refund the point"""
	if not player or not player.active_class:
		return false
	
	if not skill:
		return false
	
	var skill_id = skill.skill_id
	var current_rank = skill_ranks.get(skill_id, 0)
	
	if current_rank <= 0:
		print("🌳 %s has no ranks to refund" % skill.skill_name)
		return false
	
	# Check if other skills depend on this one
	if _is_skill_required_by_others(skill):
		print("🌳 Cannot refund %s - other skills require it" % skill.skill_name)
		return false
	
	# Remove affixes from current rank
	var rank_affixes = skill.get_affixes_for_rank(current_rank)
	for affix in rank_affixes:
		if affix:
			player.affix_manager.remove_affixes_by_source(skill.skill_name)
	
	# Reduce rank
	var new_rank = current_rank - 1
	if new_rank <= 0:
		skill_ranks.erase(skill_id)
	else:
		skill_ranks[skill_id] = new_rank
	
	# Refund skill point(s)
	for i in range(skill.skill_point_cost):
		player.active_class.refund_skill_point()
	
	print("🌳 Refunded %s to rank %d" % [skill.skill_name, new_rank])
	
	refresh()
	return true

func _is_skill_required_by_others(skill: SkillResource) -> bool:
	"""Check if any learned skills require this one"""
	for content in [tree_content_1, tree_content_2, tree_content_3]:
		if not content:
			continue
		
		for slot in _find_skill_slots(content):
			var other_skill = slot.get_skill()
			if not other_skill or other_skill == skill:
				continue
			
			var other_id = other_skill.skill_id
			var other_rank = skill_ranks.get(other_id, 0)
			
			# Skip unlearned skills
			if other_rank <= 0:
				continue
			
			# Check if other skill requires this one
			for required in other_skill.required_skills:
				if required and required.skill_id == skill.skill_id:
					return true
	
	return false

# ============================================================================
# RESET ALL SKILLS
# ============================================================================

func reset_all_skills():
	"""Reset all skills and refund all points"""
	if not player or not player.active_class:
		return
	
	# Remove all skill affixes
	for content in [tree_content_1, tree_content_2, tree_content_3]:
		if not content:
			continue
		
		for slot in _find_skill_slots(content):
			var skill = slot.get_skill()
			if skill:
				player.affix_manager.remove_affixes_by_source(skill.skill_name)
	
	# Refund all spent points
	var spent = player.active_class.get_spent_skill_points()
	for i in range(spent):
		player.active_class.refund_skill_point()
	
	# Clear rank tracking
	skill_ranks.clear()
	
	print("🌳 All skills reset!")
	refresh()

# ============================================================================
# SERIALIZATION (for save/load)
# ============================================================================

func get_skill_ranks() -> Dictionary:
	"""Get all learned skill ranks for saving"""
	return skill_ranks.duplicate()

func set_skill_ranks(ranks: Dictionary):
	"""Restore skill ranks from save data and reapply affixes"""
	skill_ranks = ranks.duplicate()
	
	# Reapply all affixes
	if player:
		for content in [tree_content_1, tree_content_2, tree_content_3]:
			if not content:
				continue
			
			for slot in _find_skill_slots(content):
				var skill = slot.get_skill()
				if not skill:
					continue
				
				var skill_id = skill.skill_id
				var rank = skill_ranks.get(skill_id, 0)
				
				# Apply affixes for all learned ranks
				for r in range(1, rank + 1):
					var affixes = skill.get_affixes_for_rank(r)
					for affix in affixes:
						if affix:
							var affix_copy = affix.duplicate_with_source(skill.skill_name, "skill")
							player.affix_manager.add_affix(affix_copy)
	
	_update_skill_slots()

# ============================================================================
# DEBUG
# ============================================================================

func print_learned_skills():
	"""Debug: Print all learned skills"""
	print("=== Learned Skills ===")
	for skill_id in skill_ranks:
		print("  %s: Rank %d" % [skill_id, skill_ranks[skill_id]])
