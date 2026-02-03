# res://scripts/ui/components/dice/die_object_base.gd
# Base class for die visual objects - handles textures, affixes, and animations
# Subclassed by CombatDieObject (rolled values) and PoolDieObject (max values)
extends Control
class_name DieObjectBase

# ============================================================================
# SIGNALS
# ============================================================================
## Emitted when user initiates drag - parent decides whether to allow it
signal drag_requested(die_object: DieObjectBase)
## Emitted on click (when not dragging)
signal clicked(die_object: DieObjectBase)
## Emitted when drag ends
signal drag_ended(die_object: DieObjectBase, was_placed: bool)

# ============================================================================
# EXPORTS
# ============================================================================
@export var base_size: Vector2 = Vector2(124, 124)

# ============================================================================
# NODE REFERENCES (set by scene, found in _ready if needed)
# ============================================================================
var fill_texture: TextureRect = null
var stroke_texture: TextureRect = null
var value_label: Label = null
var animation_player: AnimationPlayer = null

# ============================================================================
# STATE
# ============================================================================
var die_resource: DieResource = null
var draggable: bool = true
var _is_being_dragged: bool = false
var _was_placed: bool = false
var _original_position: Vector2 = Vector2.ZERO
var _original_scale: Vector2 = Vector2.ONE

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = base_size
	size = base_size
	pivot_offset = base_size / 2
	
	_discover_nodes()
	
	# If die_resource was set before _ready (e.g., via setup), apply it now
	if die_resource:
		_apply_all_visuals()

func _discover_nodes():
	"""Find child nodes - called automatically, can be overridden"""
	if not fill_texture:
		fill_texture = find_child("FillTexture", true, false) as TextureRect
	if not stroke_texture:
		stroke_texture = find_child("StrokeTexture", true, false) as TextureRect
	if not value_label:
		value_label = find_child("ValueLabel", true, false) as Label
	if not animation_player:
		animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer

# ============================================================================
# SETUP API
# ============================================================================

func setup(die: DieResource):
	"""Initialize the die object with a DieResource"""
	die_resource = die
	
	if not is_inside_tree():
		# Will apply in _ready
		return
	
	_discover_nodes()
	_apply_all_visuals()

func _apply_all_visuals():
	"""Apply all visual properties from die_resource"""
	_apply_textures()
	_apply_base_color()
	_apply_affixes()
	_update_value_display()

func _apply_textures():
	"""Apply fill and stroke textures from the DieResource"""
	if not die_resource:
		return
	
	if fill_texture and die_resource.fill_texture:
		fill_texture.texture = die_resource.fill_texture
	
	if stroke_texture and die_resource.stroke_texture:
		stroke_texture.texture = die_resource.stroke_texture

func _apply_base_color():
	"""Apply the die's base color tint"""
	if not die_resource or not fill_texture:
		return
	
	if die_resource.color != Color.WHITE:
		fill_texture.modulate = die_resource.color
	else:
		fill_texture.modulate = Color.WHITE

func _apply_affixes():
	"""Apply visual effects from all affixes on the die"""
	if not die_resource:
		return
	
	for affix in die_resource.get_all_affixes():
		_apply_single_affix(affix)

func _apply_single_affix(affix: DiceAffix):
	"""Apply a single affix's visual effects"""
	if not affix:
		return
	
	# Check for per-component effects first (newer system)
	if affix.has_method("has_per_component_effects") and affix.has_per_component_effects():
		_apply_per_component_effects(affix)
	else:
		# Fallback to unified visual effect (older system)
		_apply_unified_visual_effect(affix)

func _apply_per_component_effects(affix: DiceAffix):
	"""Apply per-component (fill/stroke/value) effects"""
	# Fill effects
	if fill_texture:
		match affix.fill_effect_type:
			DiceAffix.VisualEffectType.SHADER:
				if affix.fill_shader_material:
					fill_texture.material = affix.fill_shader_material.duplicate(true)
			DiceAffix.VisualEffectType.COLOR_TINT:
				fill_texture.modulate = fill_texture.modulate * affix.fill_effect_color
			DiceAffix.VisualEffectType.OVERLAY_TEXTURE:
				if affix.fill_overlay_texture:
					_add_overlay(fill_texture, affix.fill_overlay_texture, 
						affix.fill_overlay_blend_mode, affix.fill_overlay_opacity)
	
	# Stroke effects
	if stroke_texture:
		match affix.stroke_effect_type:
			DiceAffix.VisualEffectType.SHADER:
				if affix.stroke_shader_material:
					stroke_texture.material = affix.stroke_shader_material.duplicate(true)
			DiceAffix.VisualEffectType.COLOR_TINT:
				stroke_texture.modulate = stroke_texture.modulate * affix.stroke_effect_color
			DiceAffix.VisualEffectType.OVERLAY_TEXTURE:
				if affix.stroke_overlay_texture:
					_add_overlay(stroke_texture, affix.stroke_overlay_texture,
						affix.stroke_overlay_blend_mode, affix.stroke_overlay_opacity)
	
	# Value label effects
	if value_label:
		match affix.value_effect_type:
			DiceAffix.ValueEffectType.COLOR:
				value_label.add_theme_color_override("font_color", affix.value_text_color)
			DiceAffix.ValueEffectType.OUTLINE_COLOR:
				value_label.add_theme_color_override("font_outline_color", affix.value_outline_color)
			DiceAffix.ValueEffectType.COLOR_AND_OUTLINE:
				value_label.add_theme_color_override("font_color", affix.value_text_color)
				value_label.add_theme_color_override("font_outline_color", affix.value_outline_color)
			DiceAffix.ValueEffectType.SHADER:
				if affix.value_shader_material:
					value_label.material = affix.value_shader_material.duplicate(true)

func _apply_unified_visual_effect(affix: DiceAffix):
	"""Apply unified visual effect (legacy - affects entire die)"""
	match affix.visual_effect_type:
		DiceAffix.VisualEffectType.COLOR_TINT:
			if fill_texture:
				fill_texture.modulate = fill_texture.modulate * affix.effect_color
		DiceAffix.VisualEffectType.SHADER:
			if affix.shader_material:
				if fill_texture:
					fill_texture.material = affix.shader_material.duplicate(true)
				if stroke_texture:
					stroke_texture.material = affix.shader_material.duplicate(true)
		DiceAffix.VisualEffectType.OVERLAY_TEXTURE:
			if affix.overlay_texture and fill_texture:
				_add_overlay(fill_texture, affix.overlay_texture, 
					affix.overlay_blend_mode, affix.overlay_opacity)
		DiceAffix.VisualEffectType.BORDER_GLOW:
			_add_border_glow(affix.effect_color)

func _add_overlay(target: TextureRect, texture: Texture2D, blend_mode: int, opacity: float):
	"""Add an overlay texture on top of a target"""
	var overlay = TextureRect.new()
	overlay.name = "AffixOverlay"
	overlay.texture = texture
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	overlay.modulate.a = opacity
	
	match blend_mode:
		1:  # Add
			var mat = CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			overlay.material = mat
		2:  # Multiply
			var mat = CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
			overlay.material = mat
	
	target.add_child(overlay)

func _add_border_glow(color: Color):
	"""Add a glowing border effect"""
	var glow = Panel.new()
	glow.name = "BorderGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var glow_style = StyleBoxFlat.new()
	glow_style.bg_color = Color.TRANSPARENT
	glow_style.border_color = color
	glow_style.set_border_width_all(3)
	glow_style.set_corner_radius_all(8)
	glow_style.shadow_color = color
	glow_style.shadow_size = 6
	glow.add_theme_stylebox_override("panel", glow_style)
	
	add_child(glow)
	move_child(glow, 0)  # Behind everything

# ============================================================================
# VALUE DISPLAY - Override in subclasses
# ============================================================================

func _update_value_display():
	"""Override in subclass to show rolled vs max value"""
	pass

# ============================================================================
# REFRESH API
# ============================================================================

func refresh_display():
	"""Refresh all visual elements (call after die_resource changes)"""
	_clear_affix_effects()
	_apply_all_visuals()

func _clear_affix_effects():
	"""Remove all dynamically applied affix effects"""
	# Clear materials
	if fill_texture:
		fill_texture.material = null
		fill_texture.modulate = Color.WHITE
	if stroke_texture:
		stroke_texture.material = null
		stroke_texture.modulate = Color.WHITE
	if value_label:
		value_label.material = null
		value_label.remove_theme_color_override("font_color")
		value_label.remove_theme_color_override("font_outline_color")
	
	# Remove dynamically added children
	for child in get_children():
		if child.name == "BorderGlow" or child.name == "AffixOverlay":
			child.queue_free()
	
	# Remove overlays from fill/stroke
	if fill_texture:
		for child in fill_texture.get_children():
			if child.name == "AffixOverlay":
				child.queue_free()
	if stroke_texture:
		for child in stroke_texture.get_children():
			if child.name == "AffixOverlay":
				child.queue_free()

# ============================================================================
# DRAG VISUAL PRIMITIVES - Called by parent, not directly by drag system
# ============================================================================

func start_drag_visual():
	"""Visual feedback when drag starts"""
	_is_being_dragged = true
	_original_position = position
	_original_scale = scale
	
	if animation_player and animation_player.has_animation("pickup"):
		animation_player.play("pickup")
	else:
		# Fallback tween animation
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.2), 0.1)

func end_drag_visual(was_placed: bool):
	"""Visual feedback when drag ends"""
	_is_being_dragged = false
	_was_placed = was_placed
	
	if was_placed:
		if animation_player and animation_player.has_animation("place"):
			animation_player.play("place")
		else:
			# Fallback - just reset
			modulate = Color.WHITE
			scale = Vector2.ONE
	else:
		if animation_player and animation_player.has_animation("snap_back"):
			animation_player.play("snap_back")
		else:
			# Fallback tween snap back
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(self, "scale", _original_scale, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	
	drag_ended.emit(self, was_placed)

func show_reject_feedback():
	"""Visual feedback when action is rejected"""
	if animation_player and animation_player.has_animation("reject"):
		animation_player.play("reject")
	else:
		# Fallback shake animation
		var tween = create_tween()
		var orig_pos = position
		tween.tween_property(self, "position", orig_pos + Vector2(-5, 0), 0.05)
		tween.tween_property(self, "position", orig_pos + Vector2(5, 0), 0.05)
		tween.tween_property(self, "position", orig_pos + Vector2(-3, 0), 0.05)
		tween.tween_property(self, "position", orig_pos, 0.05)

func show_hover():
	"""Visual feedback on mouse hover"""
	if not draggable:
		return
	
	if animation_player and animation_player.has_animation("hover"):
		animation_player.play("hover")
	else:
		# Subtle scale up
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)

func hide_hover():
	"""Remove hover feedback"""
	if _is_being_dragged:
		return  # Don't interrupt drag
	
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")
	else:
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2.ONE, 0.1)

func play_roll_animation():
	"""Play roll complete animation (combat dice)"""
	if animation_player and animation_player.has_animation("roll_complete"):
		animation_player.play("roll_complete")

func play_locked_animation():
	"""Play locked state animation"""
	if animation_player and animation_player.has_animation("locked"):
		animation_player.play("locked")
	else:
		# Fallback - desaturate
		modulate = Color(0.7, 0.7, 0.7)

# ============================================================================
# SCALING FOR DIFFERENT CONTEXTS
# ============================================================================

func set_display_scale(target_scale: float):
	"""Instantly set scale (e.g., 0.5 for action field slots)"""
	scale = Vector2(target_scale, target_scale)

func animate_to_scale(target_scale: float, duration: float = 0.2) -> Tween:
	"""Animate to target scale, returns tween for chaining"""
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(target_scale, target_scale), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tween

func animate_to_position(target_pos: Vector2, duration: float = 0.2) -> Tween:
	"""Animate to target position, returns tween for chaining"""
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tween

# ============================================================================
# DRAG PREVIEW CREATION
# ============================================================================

func create_drag_preview() -> Control:
	"""Create a visual copy for Godot's drag preview system"""
	var preview = duplicate() as DieObjectBase
	preview.draggable = false
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1.0, 1.0, 1.0, 0.8)
	# Center on cursor
	preview.position = -base_size / 2
	return preview

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if draggable:
				drag_requested.emit(self)
			clicked.emit(self)

func _notification(what: int):
	match what:
		NOTIFICATION_MOUSE_ENTER:
			if draggable and not _is_being_dragged:
				show_hover()
		NOTIFICATION_MOUSE_EXIT:
			if not _is_being_dragged:
				hide_hover()

# ============================================================================
# UTILITY
# ============================================================================

func mark_as_placed():
	"""Called when die is successfully placed (e.g., in action field)"""
	_was_placed = true

func get_die() -> DieResource:
	"""Get the associated DieResource"""
	return die_resource

func is_being_dragged() -> bool:
	return _is_being_dragged
