# res://scripts/ui/bottom_ui_panel.gd
# Persistent bottom UI panel - always visible over map and combat
# Contains portrait section with back/front panels, dice panel, menu and placeholder buttons
extends Panel
class_name BottomUIPanel

# ============================================================================
# SIGNALS
# ============================================================================
signal menu_button_pressed
signal placeholder_button_pressed

# ============================================================================
# CONSTANTS
# ============================================================================
const PANEL_HEIGHT: int = 342
const PORTRAIT_SIZE: int = 400

# ============================================================================
# NODE REFERENCES - Must match scene structure
# ============================================================================
# Main sections
@onready var left_section: Control = $MainHBox/LeftSection
@onready var portrait_section: Control = $MainHBox/PortraitSection
@onready var right_section: Control = $MainHBox/RightSection

# Portrait layers (stacked in PortraitContainer)
@onready var portrait_back_panel: Panel = $MainHBox/PortraitSection/PortraitVBox/PortraitContainer/BackPanel
@onready var portrait_texture: TextureRect = $MainHBox/PortraitSection/PortraitVBox/PortraitContainer/PortraitTexture
@onready var portrait_front_panel: Panel = $MainHBox/PortraitSection/PortraitVBox/PortraitContainer/FrontPanel

# Dice panel (below portrait)
@onready var dice_panel: Control = $MainHBox/PortraitSection/PortraitVBox/MapDicePanel

# Buttons
@onready var menu_button: Button = $MainHBox/RightSection/MenuButton
@onready var placeholder_button: Button = $MainHBox/LeftSection/PlaceholderButton

# ============================================================================
# STATE
# ============================================================================
var player: Resource = null
var player_menu: Control = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("📱 BottomUIPanel ready")
	
	# Force anchors to bottom-wide (Panel respects these, PanelContainer doesn't)
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_right = 0
	offset_top = -PANEL_HEIGHT
	offset_bottom = 0
	
	# Clip children that overflow
	clip_contents = true
	
	# Connect button signals
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)
		print("  ✅ Menu button connected")
	else:
		print("  ❌ Menu button not found")
	
	if placeholder_button:
		placeholder_button.pressed.connect(_on_placeholder_button_pressed)
		print("  ✅ Placeholder button connected")
	else:
		print("  ❌ Placeholder button not found")
	
	# Setup placeholder portrait
	_setup_placeholder_portrait()
	
	# Check dice panel exists
	if dice_panel:
		print("  ✅ Dice panel found: %s" % dice_panel)
	else:
		print("  ❌ Dice panel NOT found at path")
	
	# NOTE: Don't initialize with player here - GameRoot calls initialize() 
	# after GameManager.player_created fires

func initialize(p_player: Resource):
	"""Initialize with player reference"""
	player = p_player
	print("📱 BottomUIPanel: Initialized with player")
	print("  player: %s" % player)
	print("  player.dice_pool: %s" % player.get("dice_pool"))
	
	# Initialize dice panel
	if dice_panel:
		print("  dice_panel: %s" % dice_panel)
		if dice_panel.has_method("initialize"):
			dice_panel.initialize(player)
			print("  ✅ Dice panel initialized")
		else:
			print("  ⚠️ Dice panel has no initialize method")
	else:
		print("  ❌ No dice_panel found at expected path")

func set_player_menu(menu: Control):
	"""Set reference to player menu for toggle"""
	player_menu = menu

# ============================================================================
# PORTRAIT SETUP
# ============================================================================

func _setup_placeholder_portrait():
	"""Create a placeholder portrait texture"""
	if not portrait_texture:
		return
	
	# Create placeholder image (gray with simple face indication)
	var img = Image.create(PORTRAIT_SIZE, PORTRAIT_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.25, 0.25, 0.3, 1.0))
	
	# Draw border
	var border_color = Color(0.4, 0.4, 0.45)
	for i in range(PORTRAIT_SIZE):
		for b in range(4):
			img.set_pixel(i, b, border_color)
			img.set_pixel(i, PORTRAIT_SIZE - 1 - b, border_color)
			img.set_pixel(b, i, border_color)
			img.set_pixel(PORTRAIT_SIZE - 1 - b, i, border_color)
	
	# Simple "BONES" text placeholder indicator (just a circle for now)
	var center = PORTRAIT_SIZE / 2
	for y in range(PORTRAIT_SIZE):
		for x in range(PORTRAIT_SIZE):
			var dist = sqrt(pow(x - center, 2) + pow(y - center, 2))
			if dist > 120 and dist < 140:
				img.set_pixel(x, y, Color(0.5, 0.5, 0.55))
	
	var tex = ImageTexture.create_from_image(img)
	portrait_texture.texture = tex
	portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func set_portrait(texture: Texture2D):
	"""Set the actual portrait texture"""
	if portrait_texture:
		portrait_texture.texture = texture

func set_back_panel_style(style: StyleBox):
	"""Set the back panel style (behind portrait)"""
	if portrait_back_panel:
		portrait_back_panel.add_theme_stylebox_override("panel", style)

func set_front_panel_style(style: StyleBox):
	"""Set the front panel style (frame in front of portrait)"""
	if portrait_front_panel:
		portrait_front_panel.add_theme_stylebox_override("panel", style)

# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_menu_button_pressed():
	print("📱 Menu button pressed")
	menu_button_pressed.emit()
	
	# Toggle player menu if reference exists
	if player_menu:
		if player_menu.visible:
			# Close menu
			if player_menu.has_method("close_menu"):
				player_menu.close_menu()
			else:
				player_menu.hide()
			print("  📋 Menu closed")
		else:
			# Open menu
			if player_menu.has_method("open_menu") and player:
				player_menu.open_menu(player)
			else:
				player_menu.show()
			print("  📋 Menu opened")
	else:
		print("  ⚠️ No player_menu reference set!")

func _on_placeholder_button_pressed():
	print("📱 Placeholder button pressed")
	placeholder_button_pressed.emit()

# ============================================================================
# COMBAT STATE CALLBACKS
# ============================================================================

func on_combat_started():
	"""Called when combat begins"""
	# Could hide/show certain elements during combat
	pass

func on_combat_ended(_player_won: bool):
	"""Called when combat ends"""
	# Refresh dice display after combat
	if dice_panel and dice_panel.has_method("refresh"):
		dice_panel.refresh()

# ============================================================================
# PUBLIC API
# ============================================================================

func get_dice_panel() -> Control:
	return dice_panel

func refresh_dice():
	"""Refresh the dice panel display"""
	if dice_panel and dice_panel.has_method("refresh"):
		dice_panel.refresh()
