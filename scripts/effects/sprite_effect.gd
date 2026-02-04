# res://scripts/effects/sprite_effect.gd
extends CombatEffectBase
class_name SpriteEffect

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var animation_name: String = "default"
@export var flip_h: bool = false

func play():
	effect_started.emit()
	sprite.flip_h = flip_h
	sprite.play(animation_name)
	await sprite.animation_finished
	_on_finished()
