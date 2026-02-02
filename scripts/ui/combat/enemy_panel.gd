# res://scripts/ui/combat/enemy_panel.gd
# Container for enemy slots with dice hand display - uses scene nodes
extends VBoxContainer
class_name EnemyPanel

# ============================================================================
# SIGNALS
# ============================================================================
signal enemy_selected(enemy: Combatant, slot_index: int)
signal selection_changed(slot_index: int)
signal die_animation_completed()

# ============================================================================
# EXPORTS
# ============================================================================
@export var die_visual_scene: PackedScene = null
@export var die_move_duration: float = 0.4
@export var die_scale_duration: float = 0.15

# ============================================================================
# NODE REFERENCES - Found from scene
# ============================================================================
@onready var slots_container: HBoxContainer = $SlotsContainer
@onready var dice_hand_container: PanelContainer = $EnemyDiceHand
@onready var dice_hand_grid: HBoxContainer = $EnemyDiceHand/MarginContainer/VBox/HandContainer/DiceHandGrid
@onready var action_label: Label = $EnemyDiceHand/MarginContainer/VBox/ActionLabel
@onready var arrow_label: Label = $EnemyDiceHand/MarginContainer/VBox/HandContainer/Arrow
@onready var current_action_panel: PanelContainer = $EnemyDiceHand/MarginContainer/VBox/HandContainer/CurrentActionPanel
@onready var action_name_label: Label = $EnemyDiceHand/MarginContainer/VBox/HandContainer/CurrentActionPanel/ActionName

# ============================================================================
# STATE
# ============================================================================
var enemy_slots: Array[EnemySlot] = []
var selected_slot_index: int = 0
var selection_enabled: bool = false

# Dice hand state
var current_enemy: Combatant = null
var hand_dice_visuals: Array[Control] = []
var is_animating: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_slots()
	_connect_slot_signals()
	
	# Load die visual scene if not set
	if not die_visual_scene:
		die_visual_scene = load("res://scenes/ui/components/die_visual.tscn")
	
	# Hide dice hand initially
	if dice_hand_container:
		dice_hand_container.hide()

func _discover_slots():
	"""Find EnemySlot children in slots container"""
	enemy_slots.clear()
	
	if not slots_container:
		push_error("SlotsContainer not found!")
		return
	
	# Look for slots by name pattern
	for i in range(1, 5):
		var slot = slots_container.find_child("EnemySlot%d" % i, true, false) as EnemySlot
		if slot:
			slot.slot_index = i - 1
			enemy_slots.append(slot)
	
	# Fallback: find any EnemySlot children
	if enemy_slots.size() == 0:
		for child in slots_container.get_children():
			if child is EnemySlot:
				child.slot_index = enemy_slots.size()
				enemy_slots.append(child)
	
	print("🎯 EnemyPanel: Found %d enemy slots" % enemy_slots.size())

func _connect_slot_signals():
	"""Connect signals from all slots"""
	for slot in enemy_slots:
		if not slot.slot_clicked.is_connected(_on_slot_clicked):
			slot.slot_clicked.connect(_on_slot_clicked)
		if not slot.slot_hovered.is_connected(_on_slot_hovered):
			slot.slot_hovered.connect(_on_slot_hovered)
		if not slot.slot_unhovered.is_connected(_on_slot_unhovered):
			slot.slot_unhovered.connect(_on_slot_unhovered)

# ============================================================================
# PUBLIC METHODS - INITIALIZATION
# ============================================================================

func initialize_enemies(enemies: Array):
	"""Initialize slots with enemy combatants"""
	print("🎯 EnemyPanel: Initializing with %d enemies" % enemies.size())
	
	for i in range(enemy_slots.size()):
		var slot = enemy_slots[i]
		
		if i < enemies.size() and enemies[i]:
			var enemy_combatant = enemies[i] as Combatant
			var data = enemy_combatant.enemy_data if enemy_combatant else null
			slot.set_enemy(enemy_combatant, data)
			print("  Slot %d: %s" % [i, enemy_combatant.combatant_name])
		else:
			slot.set_empty()
			print("  Slot %d: Empty" % i)
	
	hide_dice_hand()
	select_first_living_enemy()

# ============================================================================
# PUBLIC METHODS - SELECTION
# ============================================================================

func set_selection_enabled(enabled: bool):
	"""Enable or disable enemy selection"""
	selection_enabled = enabled
	
	if not enabled:
		for slot in enemy_slots:
			slot.set_selected(false)
	else:
		if selected_slot_index >= 0 and selected_slot_index < enemy_slots.size():
			enemy_slots[selected_slot_index].set_selected(true)

func select_enemy(slot_index: int):
	"""Select an enemy by slot index"""
	if slot_index < 0 or slot_index >= enemy_slots.size():
		return
	
	var slot = enemy_slots[slot_index]
	if slot.is_empty or not slot.is_alive():
		return
	
	# Deselect previous
	if selected_slot_index >= 0 and selected_slot_index < enemy_slots.size():
		enemy_slots[selected_slot_index].set_selected(false)
	
	# Select new
	selected_slot_index = slot_index
	if selection_enabled:
		slot.set_selected(true)
	
	selection_changed.emit(slot_index)
	enemy_selected.emit(slot.get_enemy(), slot_index)

func select_first_living_enemy():
	"""Select the first living enemy"""
	for i in range(enemy_slots.size()):
		var slot = enemy_slots[i]
		if not slot.is_empty and slot.is_alive():
			select_enemy(i)
			return
	
	selected_slot_index = -1

func get_selected_enemy() -> Combatant:
	"""Get the currently selected enemy"""
	if selected_slot_index >= 0 and selected_slot_index < enemy_slots.size():
		return enemy_slots[selected_slot_index].get_enemy()
	return null

func get_selected_slot_index() -> int:
	"""Get the selected slot index"""
	return selected_slot_index

# ============================================================================
# PUBLIC METHODS - HEALTH
# ============================================================================

func update_enemy_health(slot_index: int, current: int, maximum: int):
	"""Update health for a specific slot"""
	if slot_index >= 0 and slot_index < enemy_slots.size():
		enemy_slots[slot_index].update_health(current, maximum)

func on_enemy_died(slot_index: int):
	"""Handle enemy death"""
	if slot_index == selected_slot_index:
		select_first_living_enemy()
	
	if slot_index >= 0 and slot_index < enemy_slots.size():
		enemy_slots[slot_index].refresh_dice_display()

func get_living_enemy_count() -> int:
	"""Count living enemies"""
	var count = 0
	for slot in enemy_slots:
		if not slot.is_empty and slot.is_alive():
			count += 1
	return count

# ============================================================================
# DICE HAND DISPLAY
# ============================================================================

func show_dice_hand(enemy_combatant: Combatant):
	"""Show enemy's rolled dice hand"""
	current_enemy = enemy_combatant
	
	if not dice_hand_container:
		return
	
	dice_hand_container.show()
	
	# Set label
	if action_label:
		action_label.text = "%s's Turn" % enemy_combatant.combatant_name
	
	# Hide action panel initially
	if arrow_label:
		arrow_label.hide()
	if current_action_panel:
		current_action_panel.hide()
	
	# Clear previous dice
	_clear_hand_dice()
	
	# Add dice visuals for rolled hand
	var hand_dice = enemy_combatant.get_available_dice()
	
	for die in hand_dice:
		var visual = _create_die_visual(die)
		if visual:
			dice_hand_grid.add_child(visual)
			hand_dice_visuals.append(visual)

func hide_dice_hand():
	"""Hide the dice hand display"""
	current_enemy = null
	
	if dice_hand_container:
		dice_hand_container.hide()
	
	_clear_hand_dice()

func refresh_dice_hand():
	"""Refresh dice hand after a die is used"""
	if current_enemy:
		show_dice_hand(current_enemy)

func show_current_action(action_name: String):
	"""Show what action the enemy is using"""
	if arrow_label:
		arrow_label.show()
	
	if current_action_panel:
		current_action_panel.show()
	
	if action_name_label:
		action_name_label.text = action_name

# ============================================================================
# DICE ANIMATION
# ============================================================================

func animate_die_to_action(die_index: int) -> void:
	"""Animate a die moving to the action panel"""
	if die_index >= hand_dice_visuals.size():
		await get_tree().create_timer(0.1).timeout
		return
	
	is_animating = true
	
	var visual = hand_dice_visuals[die_index]
	if not is_instance_valid(visual):
		is_animating = false
		return
	
	# Get positions
	var start_pos = visual.global_position
	var target_pos = current_action_panel.global_position if current_action_panel else start_pos + Vector2(100, 0)
	
	# Flash effect
	var flash_tween = create_tween()
	flash_tween.tween_property(visual, "modulate", Color(1.5, 1.5, 0.5), die_scale_duration)
	flash_tween.tween_property(visual, "modulate", Color.WHITE, die_scale_duration)
	await flash_tween.finished
	
	# Move to action
	var move_tween = create_tween()
	move_tween.set_parallel(true)
	move_tween.tween_property(visual, "global_position", target_pos, die_move_duration).set_ease(Tween.EASE_IN_OUT)
	move_tween.tween_property(visual, "scale", Vector2(0.8, 0.8), die_move_duration)
	await move_tween.finished
	
	# Fade out
	var fade_tween = create_tween()
	fade_tween.tween_property(visual, "modulate:a", 0.0, die_scale_duration)
	await fade_tween.finished
	
	# Remove visual
	visual.queue_free()
	hand_dice_visuals[die_index] = null
	
	is_animating = false
	die_animation_completed.emit()

func animate_action_confirm() -> void:
	"""Animate action confirmation"""
	if not current_action_panel:
		return
	
	var tween = create_tween()
	tween.tween_property(current_action_panel, "modulate", Color(1.5, 1.5, 0.5), 0.1)
	tween.tween_property(current_action_panel, "modulate", Color.WHITE, 0.1)
	await tween.finished

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _create_die_visual(die: DieResource) -> Control:
	"""Create a visual for a die"""
	if not die_visual_scene:
		# Fallback: create simple label
		var label = Label.new()
		label.text = str(die.current_value)
		label.add_theme_font_size_override("font_size", 24)
		return label
	
	var visual = die_visual_scene.instantiate()
	if visual.has_method("set_die"):
		visual.set_die(die)
	elif visual.has_method("initialize"):
		visual.initialize(die)
	
	return visual

func _clear_hand_dice():
	"""Clear all dice visuals from hand"""
	for visual in hand_dice_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	hand_dice_visuals.clear()

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_slot_clicked(slot: EnemySlot):
	"""Handle slot click"""
	if selection_enabled:
		select_enemy(slot.slot_index)

func _on_slot_hovered(_slot: EnemySlot):
	"""Handle slot hover"""
	pass

func _on_slot_unhovered(_slot: EnemySlot):
	"""Handle slot unhover"""
	pass
