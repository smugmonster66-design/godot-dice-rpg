# skill.gd - Skill resource that grants affixes when learned
extends Resource
class_name Skill

# ============================================================================
# BASIC DATA
# ============================================================================
@export var skill_name: String = "New Skill"
@export_multiline var description: String = "A skill"
@export var icon: Texture2D = null

# ============================================================================
# SKILL PROPERTIES
# ============================================================================
@export var max_ranks: int = 1
@export var current_rank: int = 0
@export var skill_point_cost: int = 1

# ============================================================================
# CLASSIFICATION
# ============================================================================
@export var tier: int = 1  # Tier/row in skill tree
@export var player_class: String = ""  # e.g., "Warrior"
@export var subclass: String = ""  # Optional specialization

# ============================================================================
# PREREQUISITES
# ============================================================================
# Simple prerequisite system - just store skill names and required ranks
@export var prerequisite_skills: Array[String] = []  # Skill names required
@export var prerequisite_ranks: Array[int] = []  # Minimum rank for each skill

# Example:
# prerequisite_skills = ["Power Strike", "Weapon Mastery"]
# prerequisite_ranks = [3, 1]
# Means: Requires Power Strike rank 3+ AND Weapon Mastery rank 1+

# ============================================================================
# EFFECTS (Affixes Granted)
# ============================================================================
# Affixes granted per rank
# Each rank can grant multiple affixes
# Rank 1 affixes in rank_1_affixes, Rank 2 in rank_2_affixes, etc.

@export var rank_1_affixes: Array[Affix] = []
@export var rank_2_affixes: Array[Affix] = []
@export var rank_3_affixes: Array[Affix] = []
@export var rank_4_affixes: Array[Affix] = []
@export var rank_5_affixes: Array[Affix] = []

# ============================================================================
# SKILL MANAGEMENT
# ============================================================================

func can_rank_up() -> bool:
	"""Check if can increase rank"""
	return current_rank < max_ranks

func rank_up():
	"""Increase skill rank"""
	if can_rank_up():
		current_rank += 1

func rank_down():
	"""Decrease skill rank"""
	if current_rank > 0:
		current_rank -= 1

func reset():
	"""Reset skill to rank 0"""
	current_rank = 0

# ============================================================================
# GET AFFIXES
# ============================================================================

func get_current_affixes() -> Array[Affix]:
	"""Get all affixes granted at current rank
	
	Returns affixes from ranks 1 through current_rank
	"""
	var affixes: Array[Affix] = []
	
	for rank in range(1, current_rank + 1):
		var rank_affixes = _get_affixes_for_rank_internal(rank)
		for affix in rank_affixes:
			# Create copy with source tracking
			var affix_copy = affix.duplicate_with_source(
				"%s - %s Rank %d" % [player_class, skill_name, rank],
				"skill"
			)
			affixes.append(affix_copy)
	
	return affixes

func get_affixes_for_rank(rank: int) -> Array[Affix]:
	"""Get affixes granted at a specific rank (1-indexed)"""
	return _get_affixes_for_rank_internal(rank)

func _get_affixes_for_rank_internal(rank: int) -> Array[Affix]:
	"""Internal helper to get affixes for a specific rank"""
	match rank:
		1: return rank_1_affixes
		2: return rank_2_affixes
		3: return rank_3_affixes
		4: return rank_4_affixes
		5: return rank_5_affixes
		_: return []

# ============================================================================
# UTILITY
# ============================================================================

func get_rank_description(rank: int) -> String:
	"""Get description of what rank N grants"""
	var affixes = get_affixes_for_rank(rank)
	
	if affixes.size() == 0:
		return "No bonuses"
	
	var desc_parts = []
	for affix in affixes:
		desc_parts.append(affix.description)
	
	return ", ".join(desc_parts)

func is_learned() -> bool:
	"""Check if skill has any ranks"""
	return current_rank > 0

func is_maxed() -> bool:
	"""Check if skill is at max rank"""
	return current_rank >= max_ranks

func get_prerequisites_text() -> String:
	"""Get human-readable prerequisite text"""
	if prerequisite_skills.size() == 0:
		return "None"
	
	var parts = []
	for i in range(prerequisite_skills.size()):
		if i < prerequisite_ranks.size():
			parts.append("%s (Rank %d)" % [prerequisite_skills[i], prerequisite_ranks[i]])
		else:
			parts.append(prerequisite_skills[i])
	
	return ", ".join(parts)
