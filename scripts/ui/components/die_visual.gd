# res://scripts/ui/components/die_visual.gd
extends PanelContainer
class_name DieVisual

# ============================================================================
# DIE FACE SCENES - Lazy loaded
# ============================================================================
static var _die_face_cache: Dictionary = {}

static func _get_die_face_scene(die_type: DieResource.DieType) -> PackedScene:
	if _die_face_cache.has(die_type):
		return _die_face_cache[die_type]
	
	var path = "res://scenes/ui/components/dice/die_face_d%d.tscn" % die_type
	if ResourceLoader.exists(path):
		_die_face_cache[die_type] = load(path)
		return _die_face_cache[die_type]
	
	return null

# ============================================================================
# NODE REFERENCES
# ============================================================================
var die_face_container: Control = null
var current_die_face: Control = null
var value_label: Label = null
var texture_rect: TextureRect = null
var stroke_texture_rect: TextureRect = null

# Visual effect nodes
var overlay_container: Control = null
var particle_container: Control = null
var border_glow: Panel = null
var active_particles: Array[GPUParticles2D] = []
var active_overlays: Array[TextureRect] = []

# ============================================================================
# STATE
# ============================================================================
var die_data: DieResource = null
var can_drag: bool = true
var current_die_type: int = -1

# Drag state
var _drag_hide_tween: Tween = null
var _is_being_dragged: bool = false
var _was_placed: bool = false

# ============================================================================
# SIGNALS
# ============================================================================
signal die_clicked(die: DieResource)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_nodes()
	_setup_transparent_style()
	_setup_effect_containers()
	
	if die_data and current_die_type == -1:
		_load_die_face(die_data.die_type)
		current_die_type = die_data.die_type
		update_display()
		_apply_affix_visual_effects()  # <-- Add this line

func _discover_nodes():
	die_face_container = find_child("DieFaceContainer", true, false) as Control
	
	if not die_face_container:
		die_face_container = Control.new()
		die_face_container.name = "DieFaceContainer"
		die_face_container.custom_minimum_size = Vector2(124, 124)
		die_face_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(die_face_container)

func _setup_transparent_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	add_theme_stylebox_override("panel", style)

func _setup_effect_containers():
	var effect_size = Vector2(124, 124)
	
	# Border glow panel (BEHIND die face)
	border_glow = Panel.new()
	border_glow.name = "BorderGlow"
	border_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border_glow.custom_minimum_size = effect_size
	border_glow.size = effect_size
	border_glow.visible = false
	die_face_container.add_child(border_glow)
	die_face_container.move_child(border_glow, 0)
	
	# Overlay container (ON TOP of die face)
	overlay_container = Control.new()
	overlay_container.name = "OverlayContainer"
	overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_container.custom_minimum_size = effect_size
	overlay_container.size = effect_size
	add_child(overlay_container)
	
	# Particle container (ON TOP of everything)
	particle_container = Control.new()
	particle_container.name = "ParticleContainer"
	particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	particle_container.custom_minimum_size = effect_size
	particle_container.size = effect_size
	add_child(particle_container)


# Add new function
func mark_as_placed():
	"""Called by action field when die is successfully placed"""
	_was_placed = true

# ============================================================================
# DIE MANAGEMENT
# ============================================================================

func set_die(die: DieResource):
	die_data = die
	
	if not is_node_ready():
		return
	
	# Always reload if die type matches but texture_rect might be stale
	if die.die_type != current_die_type or not current_die_face or not texture_rect:
		_load_die_face(die.die_type)
		current_die_type = die.die_type
	
	update_display()
	_apply_affix_visual_effects()



func _load_die_face(die_type: DieResource.DieType):
	if current_die_face and is_instance_valid(current_die_face):
		current_die_face.queue_free()
		current_die_face = null
		value_label = null
		texture_rect = null
		stroke_texture_rect = null
	
	var scene = _get_die_face_scene(die_type)
	
	if scene:
		current_die_face = scene.instantiate()
		die_face_container.add_child(current_die_face)
		
		current_die_face.set_anchors_preset(Control.PRESET_TOP_LEFT)
		current_die_face.position = Vector2.ZERO
		
		value_label = current_die_face.find_child("ValueLabel", true, false) as Label
		texture_rect = current_die_face.find_child("TextureRect", true, false) as TextureRect
		
		# Create stroke texture rect on top of fill
		if texture_rect:
			stroke_texture_rect = TextureRect.new()
			stroke_texture_rect.name = "StrokeTextureRect"
			stroke_texture_rect.custom_minimum_size = texture_rect.custom_minimum_size
			stroke_texture_rect.size = texture_rect.size
			stroke_texture_rect.expand_mode = texture_rect.expand_mode
			stroke_texture_rect.stretch_mode = texture_rect.stretch_mode
			stroke_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			# Add as sibling, after the fill texture
			texture_rect.get_parent().add_child(stroke_texture_rect)
			# Move stroke after fill but before value label
			var fill_index = texture_rect.get_index()
			texture_rect.get_parent().move_child(stroke_texture_rect, fill_index + 1)
	else:
		_create_fallback_display(die_type)




func _create_fallback_display(die_type: DieResource.DieType):
	current_die_face = VBoxContainer.new()
	current_die_face.alignment = BoxContainer.ALIGNMENT_CENTER
	current_die_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	die_face_container.add_child(current_die_face)
	
	var type_label = Label.new()
	type_label.text = "D%d" % die_type
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	current_die_face.add_child(type_label)
	
	value_label = Label.new()
	value_label.name = "ValueLabel"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 24)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	current_die_face.add_child(value_label)

func update_display():
	if not die_data:
		return
	
	if value_label:
		value_label.text = str(die_data.get_total_value())
	
	# Fill texture
	if texture_rect:
		if die_data.fill_texture:
			texture_rect.texture = die_data.fill_texture
			texture_rect.visible = true
		else:
			texture_rect.visible = false
		
		if die_data.color != Color.WHITE:
			texture_rect.modulate = die_data.color
		else:
			texture_rect.modulate = Color.WHITE
	
	# Stroke texture (always on top, no color tint by default)
	if stroke_texture_rect:
		if die_data.stroke_texture:
			stroke_texture_rect.texture = die_data.stroke_texture
			stroke_texture_rect.visible = true
		else:
			stroke_texture_rect.visible = false


func get_die() -> DieResource:
	return die_data

func roll_and_update():
	if die_data:
		die_data.roll()
		update_display()
		_apply_affix_visual_effects()

# ============================================================================
# AFFIX VISUAL EFFECTS
# ============================================================================

func _apply_affix_visual_effects():
	_clear_visual_effects()
	
	if not die_data:
		return
	
	var all_affixes = die_data.get_all_affixes()
	print("_apply_affix_visual_effects: ", die_data.display_name, " found ", all_affixes.size(), " affixes")
	
	all_affixes.sort_custom(func(a, b): return a.visual_priority < b.visual_priority)
	
	for affix in all_affixes:
		print("  Processing affix: ", affix.affix_name, ", visual_type: ", affix.visual_effect_type)
		_apply_single_affix_effect(affix)

func _clear_visual_effects():
	# Clear overlays
	for overlay in active_overlays:
		if is_instance_valid(overlay):
			overlay.queue_free()
	active_overlays.clear()
	
	# Clear particles
	for particles in active_particles:
		if is_instance_valid(particles):
			particles.queue_free()
	active_particles.clear()
	
	# Hide border glow
	if border_glow:
		border_glow.visible = false
	
	# Clear shader material from fill texture
	if texture_rect and is_instance_valid(texture_rect):
		texture_rect.material = null
		if die_data and die_data.color != Color.WHITE:
			texture_rect.modulate = die_data.color
		else:
			texture_rect.modulate = Color.WHITE
	
	# Clear shader material from stroke texture
	if stroke_texture_rect and is_instance_valid(stroke_texture_rect):
		stroke_texture_rect.material = null
		stroke_texture_rect.modulate = Color.WHITE




func _apply_single_affix_effect(affix: DiceAffix):
	match affix.visual_effect_type:
		DiceAffix.VisualEffectType.NONE:
			pass
		DiceAffix.VisualEffectType.COLOR_TINT:
			_apply_color_tint(affix)
		DiceAffix.VisualEffectType.OVERLAY_TEXTURE:
			_apply_overlay_texture(affix)
		DiceAffix.VisualEffectType.PARTICLE:
			_apply_particle_effect(affix)
		DiceAffix.VisualEffectType.SHADER:
			_apply_shader_effect(affix)
		DiceAffix.VisualEffectType.BORDER_GLOW:
			_apply_border_glow(affix)

func _apply_color_tint(affix: DiceAffix):
	if affix.effect_color == Color.WHITE:
		return
	
	# Apply tint to fill
	if texture_rect:
		texture_rect.modulate = texture_rect.modulate * affix.effect_color


func _apply_overlay_texture(affix: DiceAffix):
	if not affix.overlay_texture or not overlay_container:
		return
	
	var overlay = TextureRect.new()
	overlay.texture = affix.overlay_texture
	overlay.custom_minimum_size = Vector2(124, 124)
	overlay.size = Vector2(124, 124)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.modulate.a = affix.overlay_opacity
	
	# Set blend mode via CanvasItemMaterial
	if affix.overlay_blend_mode > 0:
		var mat = CanvasItemMaterial.new()
		match affix.overlay_blend_mode:
			1:  # Add
				mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			2:  # Multiply
				mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		overlay.material = mat
	
	overlay_container.add_child(overlay)
	active_overlays.append(overlay)


func _apply_particle_effect(affix: DiceAffix):
	if not affix.particle_scene or not particle_container:
		return
	
	var particles = affix.particle_scene.instantiate()
	if particles is GPUParticles2D:
		particles.position = Vector2(62, 62)  # Center of 124x124
		particles.emitting = true
		particle_container.add_child(particles)
		active_particles.append(particles)

func _apply_shader_effect(affix: DiceAffix):
	print("_apply_shader_effect called")
	print("  affix.shader_material: ", affix.shader_material)
	print("  texture_rect: ", texture_rect)
	print("  stroke_texture_rect: ", stroke_texture_rect)
	
	if not affix.shader_material:
		print("  SKIPPED - missing shader material")
		return
	
	# Apply to fill texture
	if texture_rect:
		texture_rect.material = affix.shader_material.duplicate()
		print("  Applied shader to fill texture_rect")
	
	# Apply to stroke texture
	if stroke_texture_rect:
		stroke_texture_rect.material = affix.shader_material.duplicate()
		print("  Applied shader to stroke_texture_rect")


func _apply_border_glow(affix: DiceAffix):
	if not border_glow:
		return
	
	var glow_style = StyleBoxFlat.new()
	glow_style.bg_color = Color.TRANSPARENT
	glow_style.border_color = affix.effect_color
	glow_style.set_border_width_all(3)
	glow_style.set_corner_radius_all(8)
	glow_style.shadow_color = affix.effect_color
	glow_style.shadow_size = 6
	
	border_glow.add_theme_stylebox_override("panel", glow_style)
	border_glow.visible = true

func refresh_visual_effects():
	_apply_affix_visual_effects()

# ============================================================================
# INPUT
# ============================================================================

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			die_clicked.emit(die_data)

# ============================================================================
# DRAG AND DROP
# ============================================================================

func _get_drag_data(_at_position: Vector2):
	if not can_drag or not die_data:
		return null
	
	var preview = _create_drag_preview()
	set_drag_preview(preview)
	
	_is_being_dragged = true
	modulate = Color(1.0, 1.0, 1.0, 0.5)
	
	if _drag_hide_tween and _drag_hide_tween.is_running():
		_drag_hide_tween.kill()
	
	_drag_hide_tween = create_tween()
	_drag_hide_tween.tween_interval(0.8)
	_drag_hide_tween.tween_callback(_on_drag_hide_complete)
	
	return {
		"die": die_data,
		"visual": self,
		"source": "dice_pool",
		"source_position": global_position,
		"slot_index": get_index()
	}

func _on_drag_hide_complete():
	if _is_being_dragged:
		visible = false

# Update _notification
func _notification(what: int):
	if what == NOTIFICATION_DRAG_END:
		_is_being_dragged = false
		
		if _drag_hide_tween and _drag_hide_tween.is_running():
			_drag_hide_tween.kill()
		_drag_hide_tween = null
		
		# Only restore if NOT placed in an action field
		if not _was_placed:
			visible = true
			modulate = Color.WHITE
		# If placed, stay hidden - pool refresh will handle cleanup


func _create_drag_preview() -> Control:
	var face_size = Vector2(124, 124)
	var scene = _get_die_face_scene(die_data.die_type) if die_data else null
	
	var wrapper = Control.new()
	
	if scene:
		var face = scene.instantiate()
		wrapper.add_child(face)
		
		face.anchor_left = 0
		face.anchor_top = 0
		face.anchor_right = 0
		face.anchor_bottom = 0
		face.position = -face_size / 2
		face.size = face_size
		
		var label = face.find_child("ValueLabel", true, false) as Label
		if label:
			label.text = str(die_data.get_total_value())
		
		var tex = face.find_child("TextureRect", true, false) as TextureRect
		print("Drag preview - tex found: ", tex)
		
		if tex and die_data.color != Color.WHITE:
			tex.modulate = die_data.color
		
		print("Drag preview - calling _apply_preview_affix_effects")
		_apply_preview_affix_effects(wrapper, face, tex)
	else:
		var label = Label.new()
		label.text = str(die_data.get_total_value()) if die_data else "?"
		label.custom_minimum_size = face_size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		label.position = -face_size / 2
		wrapper.add_child(label)
	
	wrapper.modulate = Color(1.0, 1.0, 1.0, 0.8)
	return wrapper



func _apply_preview_affix_effects(wrapper: Control, face: Control, tex: TextureRect):
	if not die_data:
		return
	
	var face_size = Vector2(124, 124)
	
	for affix in die_data.get_all_affixes():
		match affix.visual_effect_type:
			DiceAffix.VisualEffectType.COLOR_TINT:
				if tex:
					tex.modulate = tex.modulate * affix.effect_color
			
			DiceAffix.VisualEffectType.SHADER:
				if tex and affix.shader_material:
					tex.material = affix.shader_material.duplicate(true)
			
			DiceAffix.VisualEffectType.OVERLAY_TEXTURE:
				if affix.overlay_texture:
					var overlay = TextureRect.new()
					overlay.texture = affix.overlay_texture
					overlay.custom_minimum_size = face_size
					overlay.size = face_size
					overlay.position = face.position
					overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					overlay.modulate.a = affix.overlay_opacity
					
					match affix.overlay_blend_mode:
						1:
							var mat = CanvasItemMaterial.new()
							mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
							overlay.material = mat
						2:
							var mat = CanvasItemMaterial.new()
							mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
							overlay.material = mat
					
					wrapper.add_child(overlay)
			
			DiceAffix.VisualEffectType.BORDER_GLOW:
				var glow = Panel.new()
				glow.custom_minimum_size = face_size
				glow.size = face_size
				glow.position = face.position
				
				var glow_style = StyleBoxFlat.new()
				glow_style.bg_color = Color.TRANSPARENT
				glow_style.border_color = affix.effect_color
				glow_style.set_border_width_all(3)
				glow_style.set_corner_radius_all(8)
				glow_style.shadow_color = affix.effect_color
				glow_style.shadow_size = 6
				glow.add_theme_stylebox_override("panel", glow_style)
				
				wrapper.add_child(glow)
				wrapper.move_child(glow, 0)
			
			DiceAffix.VisualEffectType.PARTICLE:
				pass



# ============================================================================
# VISUAL EFFECTS
# ============================================================================

func flash(color: Color = Color.YELLOW, duration: float = 0.2):
	var tween = create_tween()
	tween.tween_property(self, "modulate", color, duration * 0.5)
	tween.tween_property(self, "modulate", Color.WHITE, duration * 0.5)

func set_highlighted(highlighted: bool):
	modulate = Color(1.2, 1.2, 1.0) if highlighted else Color.WHITE

func set_dimmed(dimmed: bool):
	modulate = Color(0.5, 0.5, 0.5, 0.7) if dimmed else Color.WHITE
