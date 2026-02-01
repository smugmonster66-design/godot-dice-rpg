# res://scripts/resources/skill_resource.gd
# Skill that grants affixes to the player when learned
extends Resource
class_name SkillResource

# ============================================================================
# BASIC INFO
# ============================================================================
@export var skill_id: String = ""
@export var skill_name: String = "New Skill"
@export var icon: Texture2D = null
@export_multiline var description: String = ""  ## Supports BBCode

# ============================================================================
# SKILL TREE PLACEMENT
# ============================================================================
@export_group("Skill Tree")
@export var tier: int = 1  ## Which tier in the skill tree (1-5)
@export var skill_point_cost: int = 1
@export var required_skills: Array[SkillResource] = []  ## Prerequisites

# ============================================================================
# AFFIXES PER RANK - Drag and drop Affix resources here
# ============================================================================
@export_group("Rank 1")
@export var rank_1_affixes: Array[Affix] = []

@export_group("Rank 2")
@export var rank_2_affixes: Array[Affix] = []

@export_group("Rank 3")
@export var rank_3_affixes: Array[Affix] = []

@export_group("Rank 4")
@export var rank_4_affixes: Array[Affix] = []

@export_group("Rank 5")
@export var rank_5_affixes: Array[Affix] = []

# ============================================================================
# RANK METHODS
# ============================================================================

func get_max_rank() -> int:
	"""Determine max rank based on which arrays have affixes"""
	if rank_5_affixes.size() > 0: return 5
	if rank_4_affixes.size() > 0: return 4
	if rank_3_affixes.size() > 0: return 3
	if rank_2_affixes.size() > 0: return 2
	if rank_1_affixes.size() > 0: return 1
	return 1

# ============================================================================
# AFFIX METHODS
# ============================================================================

func get_affixes_for_rank(rank: int) -> Array[Affix]:
	"""Get affixes granted at a specific rank"""
	match rank:
		1: return rank_1_affixes
		2: return rank_2_affixes
		3: return rank_3_affixes
		4: return rank_4_affixes
		5: return rank_5_affixes
		_: return []

func get_all_affixes_up_to_rank(rank: int) -> Array[Affix]:
	"""Get all affixes from rank 1 up to specified rank"""
	var affixes: Array[Affix] = []
	for r in range(1, rank + 1):
		affixes.append_array(get_affixes_for_rank(r))
	return affixes

func get_affixes_with_source(rank: int, source_prefix: String = "") -> Array[Affix]:
	"""Get affixes up to rank with source tracking applied"""
	var affixes: Array[Affix] = []
	var source_name = source_prefix + skill_name if source_prefix else skill_name
	
	for r in range(1, rank + 1):
		for affix in get_affixes_for_rank(r):
			if affix:
				var copy = affix.duplicate_with_source(
					"%s Rank %d" % [source_name, r],
					"skill"
				)
				affixes.append(copy)
	
	return affixes

# ============================================================================
# PREREQUISITE METHODS
# ============================================================================

func can_learn(learned_skill_ids: Array) -> bool:
	"""Check if prerequisites are met"""
	for required in required_skills:
		if required and not learned_skill_ids.has(required.skill_id):
			return false
	return true

# ============================================================================
# DISPLAY METHODS
# ============================================================================

func get_rank_description(rank: int) -> String:
	"""Get description of what a specific rank grants"""
	var affixes = get_affixes_for_rank(rank)
	if affixes.is_empty():
		return "No bonuses"
	
	var parts: Array[String] = []
	for affix in affixes:
		if affix:
			parts.append(affix.description)
	
	return ", ".join(parts)

func get_total_affix_count() -> int:
	"""Count total affixes across all ranks"""
	var count = 0
	for rank in range(1, 6):
		count += get_affixes_for_rank(rank).size()
	return count

# ============================================================================
# VALIDATION
# ============================================================================

func validate() -> Array[String]:
	"""Validate skill configuration"""
	var warnings: Array[String] = []
	
	if skill_id.is_empty():
		warnings.append("Skill has no ID")
	
	if skill_name.is_empty():
		warnings.append("Skill has no name")
	
	if rank_1_affixes.is_empty():
		warnings.append("Skill has no rank 1 affixes")
	
	return warnings

func _to_string() -> String:
	return "SkillResource<%s: max rank %d, %d affixes>" % [skill_name, get_max_rank(), get_total_affix_count()]
