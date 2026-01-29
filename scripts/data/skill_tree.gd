# skill_tree.gd - A skill tree within a class
extends Resource
class_name SkillTree

var tree_name: String = ""
var description: String = ""
var skills: Array[Skill] = []

func _init(p_name: String = "", p_description: String = ""):
	tree_name = p_name
	description = p_description
	skills = []

func add_skill(skill: Skill) -> SkillTree:
	"""Fluent interface for adding skills"""
	skills.append(skill)
	return self

func find_skill_by_name(skill_name: String) -> Skill:
	"""Find a skill in this tree by name"""
	for skill in skills:
		if skill.skill_name == skill_name:
			return skill
	return null

func get_total_points_spent() -> int:
	"""Calculate total skill points spent in this tree"""
	var total = 0
	for skill in skills:
		total += skill.current_rank * skill.skill_point_cost
	return total

func reset_all_skills():
	"""Reset all skills in this tree"""
	for skill in skills:
		skill.reset()
