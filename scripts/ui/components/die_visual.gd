# res://scripts/ui/components/die_visual.gd
extends PanelContainer
class_name DieVisual

# ============================================================================
# DIE FACE SCENES - Lazy loaded
# ============================================================================
static var _die_face_cache: Dictionary = {}

static func _get_die_face_scene(die_type: DieResource.DieType) -> PackedScene:
	"""Lazy load die face scene for a die type"""
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
	
	# If die was set before ready, load it now
	if die_data and current_die_type == -1:
		_load_die_face(die_data.die_type)
		current_die_type = die_data.die_type
		update_display()

func _discover_nodes():
	"""Find the die face container"""
	die_face_container = find_child("DieFaceContainer", true, false) as Control
	
	if not die_face_container:
		die_face_container = Control.new()
		die_face_container.name = "DieFaceContainer"
		die_face_container.custom_minimum_size = Vector2(124, 124)
		die_face_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(die_face_container)

func _setup_transparent_style():
	"""Make the panel container transparent"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	add_theme_stylebox_override("panel", style)

func _setup_effect_containers():
	"""Create containers for visual effects"""
	# Overlay container (for textures layered on top)
	overlay_container = Control.new()
	overlay_container.name = "OverlayContainer"
	overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay_container)
	
	# Particle container
	particle_container = Control.new()
	particle_container.name = "ParticleContainer"
	particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	particle_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(particle_container)
	
	# Border glow panel (hidden by default)
	border_glow = Panel.new()
	border_glow.name = "BorderGlow"
	border_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	border_glow.visible = false
	add_child(border_glow)
	move_child(border_glow, 0)  # Behind everything

# ============================================================================
# DIE MANAGEMENT
# ============================================================================

func set_die(die: DieResource):
	"""Set the die and update display"""
	die_data = die
	
	if not is_node_ready():
		return
	
	# Load correct die face if type changed
	if die.die_type != current_die_type or not current_die_face:
		_load_die_face(die.die_type)
		current_die_type = die.die_type
	
	update_display()
	_apply_affix_visual_effects()

func _load_die_face(die_type: DieResource.DieType):
	"""Load and instantiate the correct die face scene"""
	# Clear existing die face
	if current_die_face and is_instance_valid(current_die_face):
		current_die_face.queue_free()
		current_die_face = null
		value_label = null
		texture_rect = null
	
	var scene = _get_die_face_scene(die_type)
	
	if scene:
		current_die_face = scene.instantiate()
		die_face_container.add_child(current_die_face)
		
		# Reset anchors so it positions correctly
		current_die_face.set_anchors_preset(Control.PRESET_TOP_LEFT)
		current_die_face.position = Vector2.ZERO
		
		# Find nodes
		value_label = current_die_face.find_child("ValueLabel", true, false) as Label
		texture_rect = current_die_face.find_child("TextureRect", true, false) as TextureRect
	else:
		_create_fallback_display(die_type)

func _create_fallback_display(die_type: DieResource.DieType):
	"""Create a simple fallback when no die face scene exists"""
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
	"""Update visual to match die data"""
	if not die_data:
		return
	
	if value_label:
		value_label.text = str(die_data.get_total_value())
	
	if texture_rect:
		if die_data.color != Color.WHITE:
			texture_rect.modulate = die_data.color
		else:
			texture_rect.modulate = Color.WHITE

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
	"""Apply visual effects from all affixes on this die"""
	_clear_visual_effects()
	
	if not die_data:
		return
	
	# Collect all affixes and sort by priority
	var all_affixes = die_data.get_all_affixes()
	all_affixes.sort_custom(func(a, b): return a.visual_priority < b.visual_priority)
	
	# Apply each affix's visual effect
	for affix in all_affixes:
		_apply_single_affix_effect(affix)

func _clear_visual_effects():
	"""Remove all active visual effects"""
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
	
	# Reset texture_rect shader
	if texture_rect:
		texture_rect.material = null

func _apply_single_affix_effect(affix: DiceAffix):
	"""Apply visual effect from a single affix"""
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
	"""Apply color tint to the die texture"""
	if texture_rect and affix.effect_color != Color.WHITE:
		# Blend with existing color
		texture_rect.modulate = texture_rect.modulate * affix.effect_color

func _apply_overlay_texture(affix: DiceAffix):
	"""Add an overlay texture on top of the die"""
	if not affix.overlay_texture or not overlay_container:
		return
	
	var overlay = TextureRect.new()
	overlay.texture = affix.overlay_texture
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set opacity
	overlay.modulate.a = affix.overlay_opacity
	
	# Set blend mode via self_modulate trick or CanvasItem blend
	match affix.overlay_blend_mode:
		0:  # Mix (normal)
			pass
		1:  # Add
			overlay.blend_mode = CanvasItem.BLEND_MODE_ADD if CanvasItem.has_method("blend_mode") else 0
		2:  # Multiply
			overlay.blend_mode = CanvasItem.BLEND_MODE_MUL if CanvasItem.has_method("blend_mode") else 0
	
	overlay_container.add_child(overlay)
	active_overlays.append(overlay)

func _apply_particle_effect(affix: DiceAffix):
	"""Add a particle effect to the die"""
	if not affix.particle_scene or not particle_container:
		return
	
	var particles = affix.particle_scene.instantiate()
	if particles is GPUParticles2D:
		particles.position = particle_container.size / 2
		particles.emitting = true
		particle_container.add_child(particles)
		active_particles.append(particles)

func _apply_shader_effect(affix: DiceAffix):
	"""Apply a shader to the die texture"""
	if not affix.shader_material or not texture_rect:
		return
	
	# Clone the material so each die has its own instance
	texture_rect.material = affix.shader_material.duplicate()

func _apply_border_glow(affix: DiceAffix):
	"""Apply a glowing border effect"""
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
	"""Public method to refresh visual effects (call after affix changes)"""
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
	"""Start dragging this die"""
	if not can_drag or not die_data:
		return null
	
	var preview = _create_drag_preview()
	set_drag_preview(preview)
	
	_is_being_dragged = true
	
	# Dim immediately to show it's being dragged
	modulate = Color(1.0, 1.0, 1.0, 0.5)
	
	# Start delayed hide - hide completely after delay
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
	"""Called after drag delay - hide the visual"""
	if _is_being_dragged:
		visible = false

func _notification(what: int):
	"""Handle drag end to restore visibility"""
	if what == NOTIFICATION_DRAG_END:
		_is_being_dragged = false
		
		# Cancel any pending hide
		if _drag_hide_tween and _drag_hide_tween.is_running():
			_drag_hide_tween.kill()
		_drag_hide_tween = null
		
		# Restore visibility and modulate
		visible = true
		modulate = Color.WHITE

func _create_drag_preview() -> Control:
	"""Create a preview for dragging"""
	var face_size = Vector2(124, 124)
	var scene = _get_die_face_scene(die_data.die_type) if die_data else null
	
	# Create wrapper - Godot positions this at cursor
	var wrapper = Control.new()
	
	if scene:
		var face = scene.instantiate()
		wrapper.add_child(face)
		
		# Disable anchors completely
		face.anchor_left = 0
		face.anchor_top = 0
		face.anchor_right = 0
		face.anchor_bottom = 0
		
		# Position so center is at cursor (wrapper's origin)
		face.position = -face_size / 2
		face.size = face_size
		
		# Update value
		var label = face.find_child("ValueLabel", true, false) as Label
		if label:
			label.text = str(die_data.get_total_value())
		
		# Apply color
		var tex = face.find_child("TextureRect", true, false) as TextureRect
		if tex and die_data.color != Color.WHITE:
			tex.modulate = die_data.color
		
		# Apply affix visual effects to preview
		_apply_preview_affix_effects(wrapper, face, tex)
	else:
		# Fallback
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
	"""Apply simplified affix visual effects to drag preview"""
	if not die_data:
		return
	
	for affix in die_data.get_all_affixes():
		match affix.visual_effect_type:
			DiceAffix.VisualEffectType.COLOR_TINT:
				if tex:
					tex.modulate = tex.modulate * affix.effect_color
			
			DiceAffix.VisualEffectType.SHADER:
				if tex and affix.shader_material:
					tex.material = affix.shader_material.duplicate()
			
			DiceAffix.VisualEffectType.BORDER_GLOW:
				# Add glow panel to preview
				var glow = Panel.new()
				glow.set_anchors_preset(Control.PRESET_FULL_RECT)
				glow.position = face.position
				glow.size = face.size
				
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
