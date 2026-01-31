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
@export var prerequisites: Array[SkillPrerequisite] = []

# ============================================================================
# EFFECTS (Affixes Granted)
# ============================================================================
# Affixes granted per rank
# Structure: Array of Arrays, where each inner array is affixes for that rank
# Example: [[rank1_affixes], [rank2_affixes], [rank3_affixes]]
@export var affixes_per_rank: Array = []

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
	
	for rank in range(current_rank):
		if rank < affixes_per_rank.size():
			var rank_affixes = affixes_per_rank[rank]
			if rank_affixes is Array:
				for affix in rank_affixes:
					if affix is Affix:
						# Create copy with source tracking
						var affix_copy = affix.duplicate_with_source(
							"%s - %s Rank %d" % [player_class, skill_name, rank + 1],
							"skill"
						)
						affixes.append(affix_copy)
	
	return affixes

func get_affixes_for_rank(rank: int) -> Array[Affix]:
	"""Get affixes granted at a specific rank (1-indexed)"""
	var affixes: Array[Affix] = []
	var rank_index = rank - 1
	
	if rank_index >= 0 and rank_index < affixes_per_rank.size():
		var rank_affixes = affixes_per_rank[rank_index]
		if rank_affixes is Array:
			for affix in rank_affixes:
				if affix is Affix:
					affixes.append(affix)
	
	return affixes

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

# ============================================================================
# PREREQUISITE HELPER
# ============================================================================

class SkillPrerequisite extends Resource:
	@export var skill_name: String = ""
	@export var required_rank: int = 1
