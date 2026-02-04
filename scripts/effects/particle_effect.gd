# res://scripts/effects/particle_effect.gd
extends CombatEffectBase
class_name ParticleEffect

@onready var particles: GPUParticles2D = $GPUParticles2D

@export var one_shot: bool = true

func play():
	effect_started.emit()
	particles.emitting = true
	
	if one_shot:
		await get_tree().create_timer(particles.lifetime).timeout
	else:
		await get_tree().create_timer(duration).timeout
	
	particles.emitting = false
	_on_finished()
