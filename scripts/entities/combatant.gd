# combatant.gd - Visual combatant (player or enemy)
extends Node2D

# ============================================================================
# EXPORTS
# ============================================================================
@export var max_health: int = 100
@export var combatant_name: String = "Combatant"

# ============================================================================
# STATE
# ============================================================================
var current_health: int = 100

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var sprite = $Sprite2D
@onready var health_label = $HealthLabel

# ============================================================================
# SIGNALS
# ============================================================================
signal health_changed(new_health: int, max_health: int)
signal died()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	current_health = max_health
	update_health_display()

# ============================================================================
# HEALTH MANAGEMENT
# ============================================================================

func take_damage(amount: int):
	"""Take damage"""
	current_health -= amount
	current_health = max(0, current_health)
	
	print("%s took %d damage! (%d/%d)" % [combatant_name, amount, current_health, max_health])
	
	update_health_display()
	flash_damage()
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		die()

func heal(amount: int):
	"""Heal"""
	current_health += amount
	current_health = min(max_health, current_health)
	
	print("%s healed %d HP! (%d/%d)" % [combatant_name, amount, current_health, max_health])
	
	update_health_display()
	flash_heal()
	health_changed.emit(current_health, max_health)

func update_health_display():
	"""Update health label"""
	if health_label:
		health_label.text = "HP: %d/%d" % [current_health, max_health]

# ============================================================================
# VISUAL EFFECTS
# ============================================================================

func flash_damage():
	"""Flash red on damage"""
	if sprite:
		sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func flash_heal():
	"""Flash green on heal"""
	if sprite:
		sprite.modulate = Color.GREEN
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func die():
	"""Handle death"""
	print("%s died!" % combatant_name)
	died.emit()
	
	# Fade out
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
