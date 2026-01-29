# menu_test.gd
# Test harness for menu - creates fake player data
extends Control

var player_menu: Control

func _ready():
	print("🧪 MENU TEST SCENE")
	
	# Get menu reference
	player_menu = $PlayerMenuMobile
	
	# Create fake player for testing
	var fake_player = create_test_player()
	
	# Show menu
	player_menu.show()
	player_menu.open_menu(fake_player)
	
	print("✅ Menu should now be visible")
	print("💡 Press ESC to close menu")

func create_test_player() -> Player:
	"""Create a fake player with test data"""
	var player = Player.new()
	player.name = "TestPlayer"
	
	# Set up a test class
	var warrior = PlayerClass.create_warrior()
	player.add_class("Warrior", warrior)
	player.switch_class("Warrior")
	
	# Add some test items
	var test_sword = {
		"name": "Test Sword",
		"slot": "Main Hand",
		"stats": {"strength": 10},
		"description": "A test weapon"
	}
	player.add_to_inventory(test_sword)
	
	var test_helmet = {
		"name": "Test Helmet",
		"slot": "Head",
		"stats": {"armor": 5},
		"description": "A test helmet"
	}
	player.add_to_inventory(test_helmet)
	
	var test_potion = {
		"name": "Health Potion",
		"type": "Consumable",
		"effect": "heal",
		"amount": 50,
		"description": "Restores 50 HP"
	}
	player.add_to_inventory(test_potion)
	
	print("✅ Created test player with %d items" % player.inventory.size())
	
	return player
