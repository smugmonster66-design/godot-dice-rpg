# res://scripts/ui/components/die_visual.gd
extends PanelContainer
class_name DieVisual

# ============================================================================
# SCENE PATHS - One per die type
# ============================================================================
const DIE_SCENES := {
	DieResource.DieType.D4: "res://scenes/ui/components/dice/die_visual_d4.tscn",
	DieResource.DieType.D6: "res://scenes/ui/components/dice/die_visual_d6.tscn",
	DieResource.DieType.D8: "res://scenes/ui/components/dice/die_visual_d8.tscn",
	DieResource.DieType.D10: "res://scenes/ui/components/dice/die_visual_d10.tscn",
	DieResource.DieType.D12: "res://scenes/ui/components/dice/die_visual_d12.tscn",
	DieResource.DieType.D20: "res://scenes/ui/components/dice/die_visual_d20.tscn",
}

# ============================================================================
# NODE REFERENCES
# ============================================================================
var texture_rect: TextureRect = null
var value_label: Label = null
var die_face_container: Control = null

# ============================================================================
# STATE
# ============================================================================
var die_data: DieResource = null
var can_drag: bool = true

# ============================================================================
# SIGNALS
# ============================================================================
signal die_clicked(die: DieResource)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_nodes()

func _discover_nodes():
	"""Find nodes - may be overridden by typed scenes"""
	texture_rect = find_child("TextureRect", true, false) as TextureRect
	value_label = find_child("ValueLabel", true, false) as Label
	die_face_container = find_child("DieFace", true, false) as Control

func set_die(die: DieResource):
	"""Set the die and update display"""
	die_data = die
	
	if not is_node_ready():
		await ready
	
	# Load the correct die face scene if needed
	_load_die_face_for_type(die.die_type)
	
	update_display()

func _load_die_face_for_type(die_type: DieResource.DieType):
	"""Load and instantiate the correct die face scene"""
	if not DIE_SCENES.has(die_type):
		return
	
	# Find or create container for die face
	if not die_face_container:
		die_face_container = find_child("DieFaceContainer", true, false)
	
	if not die_face_container:
		# Create container if it doesn't exist
		die_face_container = Control.new()
		die_face_container.name = "DieFaceContainer"
		add_child(die_face_container)
		move_child(die_face_container, 0)
	
	# Clear existing die face
	for child in die_face_container.get_children():
		child.queue_free()
	
	# Load and instantiate new die face
	var scene_path = DIE_SCENES[die_type]
	var scene = load(scene_path)
	if scene:
		var die_face = scene.instantiate()
		die_face_container.add_child(die_face)
		
		# Re-discover nodes from new scene
		texture_rect = die_face.find_child("TextureRect", true, false) as TextureRect
		value_label = die_face.find_child("ValueLabel", true, false) as Label

func update_display():
	"""Update visual to match die data"""
	if not die_data:
		return
	
	# Update value label
	if value_label:
		value_label.text = str(die_data.get_total_value())
	
	# Apply color tint if specified
	if die_data.color != Color.WHITE and texture_rect:
		texture_rect.modulate = die_data.color

func get_die() -> DieResource:
	return die_data

# ============================================================================
# DRAG AND DROP
# ============================================================================

func _get_drag_data(_at_position: Vector2):
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
	preview.custom_minimum_size = Vector2(50, 60)
	preview.modulate = Color(1.0, 1.0, 1.0, 0.8)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	style.set_corner_radius_all(4)
	preview.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = str(die_data.get_total_value())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.add_child(label)
	
	return preview
