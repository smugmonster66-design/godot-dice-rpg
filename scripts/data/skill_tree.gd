# res://scripts/resources/skill_tree.gd
# Skill tree containing skills organized by tier - supports drag-drop in Inspector
extends Resource
class_name SkillTree

# ============================================================================
# BASIC INFO
# ============================================================================
@export var tree_id: String = ""
@export var tree_name: String = "New Skill Tree"
@export_multiline var description: String = ""
@export var icon: Texture2D = null

# ============================================================================
# SKILLS BY TIER - Drag and drop SkillResource items here
# ============================================================================
@export_group("Tier 1 - Basic")
@export var tier_1_skills: Array[SkillResource] = []

@export_group("Tier 2 - Intermediate")
@export var tier_2_skills: Array[SkillResource] = []

@export_group("Tier 3 - Advanced")
@export var tier_3_skills: Array[SkillResource] = []

@export_group("Tier 4 - Expert")
@export var tier_4_skills: Array[SkillResource] = []

@export_group("Tier 5 - Mastery")
@export var tier_5_skills: Array[SkillResource] = []

# ============================================================================
# TIER UNLOCK REQUIREMENTS
# ============================================================================
@export_group("Tier Unlock Requirements")
@export var tier_2_points_required: int = 3
@export var tier_3_points_required: int = 6
@export var tier_4_points_required: int = 10
@export var tier_5_points_required: int = 15

# ============================================================================
# SKILL RETRIEVAL METHODS
# ============================================================================

func get_all_skills() -> Array[SkillResource]:
	"""Get all skills from all tiers"""
	var all_skills: Array[SkillResource] = []
	all_skills.append_array(tier_1_skills)
	all_skills.append_array(tier_2_skills)
	all_skills.append_array(tier_3_skills)
	all_skills.append_array(tier_4_skills)
	all_skills.append_array(tier_5_skills)
	return all_skills

func get_skills_for_tier(tier: int) -> Array[SkillResource]:
	"""Get all skills for a specific tier"""
	match tier:
		1: return tier_1_skills
		2: return tier_2_skills
		3: return tier_3_skills
		4: return tier_4_skills
		5: return tier_5_skills
		_: return []

func get_skill_by_id(id: String) -> SkillResource:
	"""Find a skill by its ID"""
	for skill in get_all_skills():
		if skill and skill.skill_id == id:
			return skill
	return null

func get_skill_by_name(p_skill_name: String) -> SkillResource:
	"""Find a skill by name"""
	for skill in get_all_skills():
		if skill and skill.skill_name == p_skill_name:
			return skill
	return null

# ============================================================================
# TIER METHODS
# ============================================================================

func is_tier_unlocked(tier: int, total_points_spent: int) -> bool:
	"""Check if a tier is unlocked based on points spent in this tree"""
	match tier:
		1: return true
		2: return total_points_spent >= tier_2_points_required
		3: return total_points_spent >= tier_3_points_required
		4: return total_points_spent >= tier_4_points_required
		5: return total_points_spent >= tier_5_points_required
		_: return false

func get_points_required_for_tier(tier: int) -> int:
	"""Get points required to unlock a tier"""
	match tier:
		2: return tier_2_points_required
		3: return tier_3_points_required
		4: return tier_4_points_required
		5: return tier_5_points_required
		_: return 0

func get_tier_count() -> int:
	"""Get the highest tier that has skills"""
	if tier_5_skills.size() > 0: return 5
	if tier_4_skills.size() > 0: return 4
	if tier_3_skills.size() > 0: return 3
	if tier_2_skills.size() > 0: return 2
	if tier_1_skills.size() > 0: return 1
	return 0

func get_skill_count() -> int:
	"""Get total number of skills in this tree"""
	return get_all_skills().size()

# ============================================================================
# VALIDATION
# ============================================================================

func validate() -> Array[String]:
	"""Validate the skill tree configuration"""
	var warnings: Array[String] = []
	
	if tree_id.is_empty():
		warnings.append("Skill tree has no ID")
	
	if tree_name.is_empty():
		warnings.append("Skill tree has no name")
	
	# Check for duplicate skill IDs
	var seen_ids: Dictionary = {}
	for skill in get_all_skills():
		if skill:
			if skill.skill_id.is_empty():
				warnings.append("Skill '%s' has no ID" % skill.skill_name)
			elif seen_ids.has(skill.skill_id):
				warnings.append("Duplicate skill ID: %s" % skill.skill_id)
			seen_ids[skill.skill_id] = true
	
	# Check skill tiers match their placement
	for i in range(1, 6):
		for skill in get_skills_for_tier(i):
			if skill and skill.tier != i:
				warnings.append("Skill '%s' has tier %d but is in tier_%d_skills" % [skill.skill_name, skill.tier, i])
	
	return warnings

func _to_string() -> String:
	return "SkillTree<%s: %d skills across %d tiers>" % [tree_name, get_skill_count(), get_tier_count()]
