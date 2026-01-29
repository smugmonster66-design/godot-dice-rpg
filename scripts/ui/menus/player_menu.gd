# player_menu.gd - Main player menu
extends Control

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var panel = $PanelContainer
@onready var tab_container = $PanelContainer/VBoxContainer/TabContainer
@onready var close_button = $PanelContainer/VBoxContainer/CloseButton

# Tab references
@onready var character_tab = $PanelContainer/VBoxContainer/TabContainer/Character
@onready var skills_tab = $PanelContainer/VBoxContainer/TabContainer/Skills
@onready var equipment_tab = $PanelContainer/VBoxContainer/TabContainer/Equipment
@onready var inventory_tab = $PanelContainer/VBoxContainer/TabContainer/Inventory

# ============================================================================
# STATE
# ============================================================================
var player: Player = null

# ============================================================================
# SIGNALS
# ============================================================================
signal menu_closed()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	hide()
	
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	else:
		print("⚠️ PlayerMenu: Close button not found")

# ============================================================================
# PUBLIC API
# ============================================================================

func open_menu(p_player: Player):
	"""Open menu with player"""
	player = p_player
	refresh_all_tabs()
	show()

func refresh_all_tabs():
	"""Refresh all tab displays"""
	if character_tab and character_tab.has_method("set_player"):
		character_tab.set_player(player)
	
	if skills_tab and skills_tab.has_method("set_player"):
		skills_tab.set_player(player)
	
	if equipment_tab and equipment_tab.has_method("set_player"):
		equipment_tab.set_player(player)
	
	if inventory_tab and inventory_tab.has_method("set_player"):
		inventory_tab.set_player(player)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_close_pressed():
	"""Close button pressed"""
	hide()
	menu_closed.emit()

# ============================================================================
# INPUT
# ============================================================================

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
