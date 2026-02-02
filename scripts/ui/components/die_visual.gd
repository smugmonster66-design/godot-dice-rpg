# res://scripts/ui/components/die_visual.gd
extends PanelContainer
class_name DieVisual

# ============================================================================
# DIE FACE SCENES - Lazy loaded (class-level cache)
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

# ============================================================================
# STATE
# ============================================================================
var die_data: DieResource = null
var can_drag: bool = true
var current_die_type: int = -1

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
		die_face_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# No minimum size - let the die face scene define it
		add_child(die_face_container)

func _setup_transparent_style():
	"""Make the panel container transparent"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	add_theme_stylebox_override("panel", style)

# ============================================================================
# DIE MANAGEMENT
# ============================================================================

func set_die(die: DieResource):
	"""Set the die and update display"""
	die_data = die
	
	if not is_node_ready():
		# Will be handled in _ready()
		return
	
	# Load correct die face if type changed
	if die.die_type != current_die_type or not current_die_face:
		_load_die_face(die.die_type)
		current_die_type = die.die_type
	
	update_display()

func _load_die_face(die_type: DieResource.DieType):
	"""Load and instantiate the correct die face scene (synchronous)"""
	# Clear existing die face
	if current_die_face and is_instance_valid(current_die_face):
		current_die_face.queue_free()
		current_die_face = null
		value_label = null
		texture_rect = null
	
	# Try to load scene
	var scene = _get_die_face_scene(die_type)
	
	if scene:
		# Instantiate new die face
		current_die_face = scene.instantiate()
		die_face_container.add_child(current_die_face)
		
		# Find nodes in the new die face
		value_label = current_die_face.find_child("ValueLabel", true, false) as Label
		texture_rect = current_die_face.find_child("TextureRect", true, false) as TextureRect
	else:
		# Fallback: create simple display
		_create_fallback_display(die_type)

func _create_fallback_display(die_type: DieResource.DieType):
	"""Create a simple fallback when no die face scene exists"""
	current_die_face = VBoxContainer.new()
	current_die_face.alignment = BoxContainer.ALIGNMENT_CENTER
	current_die_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	die_face_container.add_child(current_die_face)
	
	# Type label
	var type_label = Label.new()
	type_label.text = "D%d" % die_type
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	current_die_face.add_child(type_label)
	
	# Value label
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
	
	# Update value label
	if value_label:
		value_label.text = str(die_data.get_total_value())
	
	# Apply color tint if specified
	if texture_rect:
		if die_data.color != Color.WHITE:
			texture_rect.modulate = die_data.color
		else:
			texture_rect.modulate = Color.WHITE

func get_die() -> DieResource:
	"""Return the die resource"""
	return die_data

func roll_and_update():
	"""Roll the die and update display"""
	if die_data:
		die_data.roll()
		update_display()

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
	
	return {
		"die": die_data,
		"visual": self,
		"source": "dice_pool",
		"source_position": global_position,
		"slot_index": get_index()
	}

func _create_drag_preview() -> Control:
	"""Create a preview for dragging"""
	var preview = PanelContainer.new()
	preview.modulate = Color(1.0, 1.0, 1.0, 0.8)
	
	# Make transparent
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	preview.add_theme_stylebox_override("panel", style)
	
	# Load die face scene - it defines its own size
	var scene = _get_die_face_scene(die_data.die_type) if die_data else null
	
	if scene:
		var face = scene.instantiate()
		preview.add_child(face)
		
		# Update value
		var label = face.find_child("ValueLabel", true, false) as Label
		if label:
			label.text = str(die_data.get_total_value())
		
		# Apply color
		var tex = face.find_child("TextureRect", true, false) as TextureRect
		if tex and die_data.color != Color.WHITE:
			tex.modulate = die_data.color
	else:
		# Fallback needs a size since there's no scene
		preview.custom_minimum_size = Vector2(64, 64)
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		preview.add_child(vbox)
		
		var label = Label.new()
		label.text = str(die_data.get_total_value()) if die_data else "?"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		vbox.add_child(label)
	
	return preview

# ============================================================================
# VISUAL EFFECTS
# ============================================================================

func flash(color: Color = Color.YELLOW, duration: float = 0.2):
	"""Flash the die with a color"""
	var tween = create_tween()
	tween.tween_property(self, "modulate", color, duration * 0.5)
	tween.tween_property(self, "modulate", Color.WHITE, duration * 0.5)

func set_highlighted(highlighted: bool):
	"""Set highlight state"""
	if highlighted:
		modulate = Color(1.2, 1.2, 1.0)
	else:
		modulate = Color.WHITE

func set_dimmed(dimmed: bool):
	"""Set dimmed state (e.g., when locked)"""
	if dimmed:
		modulate = Color(0.5, 0.5, 0.5, 0.7)
	else:
		modulate = Color.WHITE
