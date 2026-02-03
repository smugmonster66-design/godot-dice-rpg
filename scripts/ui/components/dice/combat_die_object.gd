# res://scripts/ui/components/dice/combat_die_object.gd
# Combat die object - displays ROLLED value for use in combat hand
# Inherits visual and animation logic from DieObjectBase
extends DieObjectBase
class_name CombatDieObject

# ============================================================================
# COMBAT-SPECIFIC SIGNALS
# ============================================================================
## Emitted after roll animation completes
signal roll_animation_finished(die_object: CombatDieObject)

# ============================================================================
# COMBAT STATE
# ============================================================================
var slot_index: int = -1  # Position in the combat hand

# ============================================================================
# VALUE DISPLAY - Shows rolled value
# ============================================================================

func _update_value_display():
	"""Show the rolled value (current + modifiers)"""
	if not die_resource or not value_label:
		return
	
	value_label.text = str(die_resource.get_total_value())

func update_after_roll():
	"""Called after the die has been rolled - refresh display and animate"""
	_update_value_display()
	play_roll_animation()

# ============================================================================
# COMBAT-SPECIFIC ANIMATIONS
# ============================================================================

func play_roll_animation():
	"""Play the roll complete animation with value reveal"""
	if animation_player and animation_player.has_animation("roll_complete"):
		animation_player.play("roll_complete")
		# Connect to animation finished if not already
		if not animation_player.animation_finished.is_connected(_on_roll_animation_finished):
			animation_player.animation_finished.connect(_on_roll_animation_finished.bind(), CONNECT_ONE_SHOT)
	else:
		# Fallback - quick pulse animation
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_callback(_emit_roll_finished)

func _on_roll_animation_finished(_anim_name: String):
	_emit_roll_finished()

func _emit_roll_finished():
	roll_animation_finished.emit(self)

func play_consume_animation() -> Tween:
	"""Play animation when die is consumed by an action"""
	if animation_player and animation_player.has_animation("consume"):
		animation_player.play("consume")
		return null  # Can't return tween for AnimationPlayer
	else:
		# Fallback - shrink and fade
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.2)
		tween.tween_property(self, "modulate:a", 0.0, 0.2)
		return tween

func play_restore_animation() -> Tween:
	"""Play animation when die is restored to hand (action cancelled)"""
	if animation_player and animation_player.has_animation("restore"):
		animation_player.play("restore")
		return null
	else:
		# Fallback - pop back in
		scale = Vector2(0.5, 0.5)
		modulate.a = 0.0
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(self, "modulate:a", 1.0, 0.15)
		return tween

# ============================================================================
# LOCKED STATE
# ============================================================================

func set_locked(locked: bool):
	"""Visual feedback for locked dice"""
	if not die_resource:
		return
	
	die_resource.is_locked = locked
	draggable = not locked
	
	if locked:
		play_locked_animation()
	else:
		# Restore normal appearance
		modulate = Color.WHITE
		if animation_player and animation_player.has_animation("idle"):
			animation_player.play("idle")

# ============================================================================
# MODIFIER DISPLAY (optional)
# ============================================================================

func show_modifier_change(amount: int):
	"""Briefly show a modifier change (+2, -1, etc.)"""
	# Create floating text
	var mod_label = Label.new()
	mod_label.text = "%+d" % amount if amount >= 0 else str(amount)
	mod_label.add_theme_font_size_override("font_size", 24)
	mod_label.add_theme_color_override("font_color", Color.YELLOW if amount > 0 else Color.RED)
	mod_label.position = Vector2(base_size.x / 2, -10)
	mod_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(mod_label)
	
	# Animate up and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(mod_label, "position:y", mod_label.position.y - 30, 0.5)
	tween.tween_property(mod_label, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tween.chain().tween_callback(mod_label.queue_free)
