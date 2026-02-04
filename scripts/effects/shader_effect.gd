# res://scripts/effects/shader_effect.gd
extends CombatEffectBase
class_name ShaderEffect

@export var shader: Shader
@export var shader_params: Dictionary = {}
@export var fade_in: float = 0.1
@export var fade_out: float = 0.2

var target_node: CanvasItem
var original_material: Material

func setup(target: CanvasItem):
	target_node = target
	original_material = target.material

func play():
	if not target_node:
		_on_finished()
		return
	
	effect_started.emit()
	
	# Apply shader
	var mat = ShaderMaterial.new()
	mat.shader = shader
	for param in shader_params:
		mat.set_shader_parameter(param, shader_params[param])
	
	target_node.material = mat
	
	# Wait for duration
	await get_tree().create_timer(duration).timeout
	
	# Restore original
	target_node.material = original_material
	_on_finished()
