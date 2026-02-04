# res://scripts/effects/projectile_effect.gd
extends CombatEffectBase
class_name ProjectileEffect

signal reached_target()

@export var rotate_to_target: bool = true
@export var trail_particles: bool = true

@onready var sprite = $Sprite2D
@onready var trail = $GPUParticles2D

var target_position: Vector2
var travel_curve: Curve
var travel_duration: float = 0.4

func setup(from: Vector2, to: Vector2, p_duration: float = 0.4, p_curve: Curve = null):
	global_position = from
	target_position = to
	travel_duration = p_duration
	travel_curve = p_curve
	
	if rotate_to_target:
		rotation = from.angle_to_point(to)

func play():
	effect_started.emit()
	
	if trail_particles and trail:
		trail.emitting = true
	
	var tween = create_tween()
	
	if travel_curve:
		# Curved path (arc)
		tween.tween_method(_follow_curve, 0.0, 1.0, travel_duration)
	else:
		# Straight line
		tween.tween_property(self, "global_position", target_position, travel_duration)
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	await tween.finished
	reached_target.emit()
	
	if trail and trail_particles:
		trail.emitting = false
		await get_tree().create_timer(trail.lifetime).timeout
	
	_on_finished()

func _follow_curve(t: float):
	var start = global_position if t == 0 else global_position
	var linear_pos = global_position.lerp(target_position, t)
	
	# Apply curve for arc height
	var height_offset = travel_curve.sample(t) * 100  # Adjust multiplier
	global_position = linear_pos + Vector2(0, -height_offset)
