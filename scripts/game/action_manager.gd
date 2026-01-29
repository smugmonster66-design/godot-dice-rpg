# action_manager.gd - Manages player's available combat actions
extends Node
class_name ActionManager

var player: Player = null

# Tracked actions
var item_actions: Array[Dictionary] = []  # {name, icon, description, die_slots, etc.}
var skill_actions: Array[Dictionary] = []

signal actions_changed()

func initialize(p_player: Player):
	"""Initialize with player"""
	player = p_player
	
	# Connect to equipment changes
	if player:
		player.equipment_changed.connect(_on_equipment_changed)
	
	# Build initial action list
	rebuild_actions()

func rebuild_actions():
	"""Rebuild action lists from player state"""
	item_actions.clear()
	skill_actions.clear()
	
	# Add actions from equipped items
	add_item_actions()
	
	# Add actions from learned skills
	add_skill_actions()
	
	actions_changed.emit()
	print("📋 Actions rebuilt: %d items, %d skills" % [item_actions.size(), skill_actions.size()])

func add_item_actions():
	"""Add actions from equipped items"""
	if not player:
		return
	
	for slot in player.equipment:
		var item = player.equipment[slot]
		if item and item.has("actions"):
			for action_data in item.actions:
				var action = action_data.duplicate()
				action["source"] = item.get("name", "Unknown Item")
				action["category"] = ActionField.ActionCategory.ITEM
				item_actions.append(action)

func add_skill_actions():
	"""Add actions from learned skills"""
	if not player or not player.active_class:
		return
	
	# Get actions from class
	if player.active_class.combat_actions:
		for action_name in player.active_class.combat_actions:
			var action = create_skill_action(action_name)
			if action:
				skill_actions.append(action)

func create_skill_action(action_name: String) -> Dictionary:
	"""Create action data for a skill"""
	# This would look up skill data - for now, placeholder
	return {
		"name": action_name,
		"description": "A powerful skill.",
		"icon": null,
		"die_slots": 1,
		"action_type": ActionField.ActionType.SPECIAL,
		"category": ActionField.ActionCategory.SKILL,
		"source": "Class Skill",
		"base_damage": 0,
		"damage_multiplier": 1.0,
		"required_tags": [],
		"restricted_tags": []
	}

func _on_equipment_changed(_slot: String, _item):
	"""Rebuild when equipment changes"""
	rebuild_actions()

func get_item_actions() -> Array[Dictionary]:
	"""Get all item actions"""
	return item_actions

func get_skill_actions() -> Array[Dictionary]:
	"""Get all skill actions"""
	return skill_actions
