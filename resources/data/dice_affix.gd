# dice_affix.gd - Affix system specifically for dice
# Separate from item affixes, these affect dice behavior based on position and neighbors
extends Resource
class_name DiceAffix

# ============================================================================
# ENUMS
# ============================================================================

## When does this affix trigger?
enum Trigger {
	ON_ROLL,           # When the die is rolled at turn start
	ON_USE,            # When the die is placed in an action field
	PASSIVE,           # Always active while in collection
	ON_REORDER,        # When dice are reordered (drag-drop)
	ON_COMBAT_START,   # At the start of combat
	ON_COMBAT_END,     # At the end of combat
}

## What position does this affix require?
enum PositionRequirement {
	ANY,               # Works in any slot
	FIRST,             # Only works in first slot (index 0)
	LAST,              # Only works in last slot
	NOT_FIRST,         # Works anywhere except first
	NOT_LAST,          # Works anywhere except last
	SPECIFIC_SLOT,     # Works in a specific slot (use required_slot)
	EVEN_SLOTS,        # Works in even-indexed slots (0, 2, 4...)
	ODD_SLOTS,         # Works in odd-indexed slots (1, 3, 5...)
}

## What does this affix target?
enum NeighborTarget {
	SELF,              # Only affects this die
	LEFT,              # Affects die to the left
	RIGHT,             # Affects die to the right
	BOTH_NEIGHBORS,    # Affects dice on both sides
	ALL_LEFT,          # Affects all dice to the left
	ALL_RIGHT,         # Affects all dice to the right
	ALL_OTHERS,        # Affects all other dice
	ALL_DICE,          # Affects all dice including self
}

## What type of effect does this apply?
enum EffectType {
	# Value modifications
	MODIFY_VALUE_FLAT,       # Add flat value to roll
	MODIFY_VALUE_PERCENT,    # Multiply roll value
	SET_MINIMUM_VALUE,       # Set minimum roll value
	SET_MAXIMUM_VALUE,       # Set maximum roll value
	
	# Tag modifications
	ADD_TAG,                 # Add a tag to die/target
	REMOVE_TAG,              # Remove a tag from die/target
	COPY_TAGS,               # Copy tags from neighbor
	
	# Reroll effects
	GRANT_REROLL,            # Allow rerolling this die
	AUTO_REROLL_LOW,         # Automatically reroll if below threshold
	
	# Special effects
	DUPLICATE_ON_MAX,        # Create copy if max value rolled
	LOCK_DIE,                # Prevent die from being consumed
	CHANGE_DIE_TYPE,         # Transform die type (d6 -> d8)
	COPY_NEIGHBOR_VALUE,     # Copy percentage of neighbor's value
	
	# Combat effects
	ADD_DAMAGE_TYPE,         # Add elemental damage type
	GRANT_STATUS_EFFECT,     # Apply status on use
	
	# Meta effects
	CONDITIONAL,             # Effect only if condition met
}

# ============================================================================
# BASIC DATA
# ============================================================================
@export var affix_name: String = "New Dice Affix"
@export_multiline var description: String = "A dice affix effect"
@export var icon: Texture2D = null

# ============================================================================
# TRIGGER CONFIGURATION
# ============================================================================
@export_group("Trigger")
@export var trigger: Trigger = Trigger.ON_ROLL

# ============================================================================
# POSITION CONFIGURATION
# ============================================================================
@export_group("Position")
@export var position_requirement: PositionRequirement = PositionRequirement.ANY
@export var required_slot: int = 0  # Used with SPECIFIC_SLOT

# ============================================================================
# TARGET CONFIGURATION
# ============================================================================
@export_group("Target")
@export var neighbor_target: NeighborTarget = NeighborTarget.SELF

# ============================================================================
# EFFECT CONFIGURATION
# ============================================================================
@export_group("Effect")
@export var effect_type: EffectType = EffectType.MODIFY_VALUE_FLAT
@export var effect_value: float = 0.0

## Complex effect data for effects that need multiple values
## Examples:
## - ADD_TAG: {"tag": "fire"}
## - AUTO_REROLL_LOW: {"threshold": 2}
## - COPY_NEIGHBOR_VALUE: {"percent": 0.25}
## - CONDITIONAL: {"condition": "neighbor_has_tag", "tag": "fire", "then_effect": {...}}
## - ADD_DAMAGE_TYPE: {"type": "fire", "percent": 0.5}
@export var effect_data: Dictionary = {}

# ============================================================================
# SOURCE TRACKING
# ============================================================================
var source: String = ""       # e.g., "Flame Die", "Fire Blessing"
var source_type: String = ""  # e.g., "die", "blessing", "curse", "equipment"

# ============================================================================
# POSITION CHECKING
# ============================================================================

func check_position(slot_index: int, total_dice: int) -> bool:
	"""Check if this affix should activate at the given position"""
	match position_requirement:
		PositionRequirement.ANY:
			return true
		PositionRequirement.FIRST:
			return slot_index == 0
		PositionRequirement.LAST:
			return slot_index == total_dice - 1
		PositionRequirement.NOT_FIRST:
			return slot_index != 0
		PositionRequirement.NOT_LAST:
			return slot_index != total_dice - 1
		PositionRequirement.SPECIFIC_SLOT:
			return slot_index == required_slot
		PositionRequirement.EVEN_SLOTS:
			return slot_index % 2 == 0
		PositionRequirement.ODD_SLOTS:
			return slot_index % 2 == 1
	return false

# ============================================================================
# TARGET RESOLUTION
# ============================================================================

func get_target_indices(slot_index: int, total_dice: int) -> Array[int]:
	"""Get indices of dice that this affix affects"""
	var targets: Array[int] = []
	
	match neighbor_target:
		NeighborTarget.SELF:
			targets.append(slot_index)
		
		NeighborTarget.LEFT:
			if slot_index > 0:
				targets.append(slot_index - 1)
		
		NeighborTarget.RIGHT:
			if slot_index < total_dice - 1:
				targets.append(slot_index + 1)
		
		NeighborTarget.BOTH_NEIGHBORS:
			if slot_index > 0:
				targets.append(slot_index - 1)
			if slot_index < total_dice - 1:
				targets.append(slot_index + 1)
		
		NeighborTarget.ALL_LEFT:
			for i in range(slot_index):
				targets.append(i)
		
		NeighborTarget.ALL_RIGHT:
			for i in range(slot_index + 1, total_dice):
				targets.append(i)
		
		NeighborTarget.ALL_OTHERS:
			for i in range(total_dice):
				if i != slot_index:
					targets.append(i)
		
		NeighborTarget.ALL_DICE:
			for i in range(total_dice):
				targets.append(i)
	
	return targets

# ============================================================================
# EFFECT APPLICATION
# ============================================================================

func get_value_modifier() -> float:
	"""Get the numeric modifier for value-based effects"""
	return effect_value

func get_effect_tag() -> String:
	"""Get the tag for tag-based effects"""
	return effect_data.get("tag", "")

func get_threshold() -> int:
	"""Get threshold for threshold-based effects"""
	return int(effect_data.get("threshold", 0))

func get_percent() -> float:
	"""Get percentage for percent-based effects"""
	return effect_data.get("percent", 0.0)

func get_new_die_type() -> int:
	"""Get new die type for CHANGE_DIE_TYPE effect"""
	return int(effect_data.get("new_type", 6))

func get_damage_type() -> String:
	"""Get damage type for ADD_DAMAGE_TYPE effect"""
	return effect_data.get("type", "physical")

func get_status_effect() -> Dictionary:
	"""Get status effect data for GRANT_STATUS_EFFECT"""
	return effect_data.get("status", {})

# ============================================================================
# DESCRIPTION GENERATION
# ============================================================================

func get_formatted_description() -> String:
	"""Generate a formatted description with actual values"""
	var text = description
	
	# Replace placeholders
	text = text.replace("{value}", str(effect_value))
	text = text.replace("{percent}", str(int(get_percent() * 100)) + "%")
	text = text.replace("{threshold}", str(get_threshold()))
	text = text.replace("{tag}", get_effect_tag())
	text = text.replace("{slot}", str(required_slot + 1))  # 1-indexed for display
	
	# Add position info if not ANY
	if position_requirement != PositionRequirement.ANY:
		text += " [" + _get_position_text() + "]"
	
	return text

func _get_position_text() -> String:
	"""Get human-readable position requirement text"""
	match position_requirement:
		PositionRequirement.FIRST: return "First slot"
		PositionRequirement.LAST: return "Last slot"
		PositionRequirement.NOT_FIRST: return "Not first"
		PositionRequirement.NOT_LAST: return "Not last"
		PositionRequirement.SPECIFIC_SLOT: return "Slot %d" % (required_slot + 1)
		PositionRequirement.EVEN_SLOTS: return "Even slots"
		PositionRequirement.ODD_SLOTS: return "Odd slots"
	return ""

# ============================================================================
# UTILITY
# ============================================================================

func duplicate_with_source(p_source: String, p_source_type: String) -> DiceAffix:
	"""Create a copy with source tracking"""
	var copy = duplicate(true)
	copy.source = p_source
	copy.source_type = p_source_type
	return copy

func matches_source(p_source: String) -> bool:
	"""Check if from specific source"""
	return source == p_source

func get_display_text() -> String:
	"""Get display text for UI"""
	var text = affix_name
	if source:
		text += " (from %s)" % source
	return text

# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dict() -> Dictionary:
	"""Serialize to dictionary"""
	return {
		"affix_name": affix_name,
		"description": description,
		"trigger": trigger,
		"position_requirement": position_requirement,
		"required_slot": required_slot,
		"neighbor_target": neighbor_target,
		"effect_type": effect_type,
		"effect_value": effect_value,
		"effect_data": effect_data,
		"source": source,
		"source_type": source_type,
	}

static func from_dict(data: Dictionary) -> DiceAffix:
	"""Deserialize from dictionary"""
	var affix = DiceAffix.new()
	affix.affix_name = data.get("affix_name", "Unknown")
	affix.description = data.get("description", "")
	affix.trigger = data.get("trigger", Trigger.ON_ROLL)
	affix.position_requirement = data.get("position_requirement", PositionRequirement.ANY)
	affix.required_slot = data.get("required_slot", 0)
	affix.neighbor_target = data.get("neighbor_target", NeighborTarget.SELF)
	affix.effect_type = data.get("effect_type", EffectType.MODIFY_VALUE_FLAT)
	affix.effect_value = data.get("effect_value", 0.0)
	affix.effect_data = data.get("effect_data", {})
	affix.source = data.get("source", "")
	affix.source_type = data.get("source_type", "")
	return affix
