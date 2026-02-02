# damage_packet.gd - Holds damage broken out by type
extends RefCounted
class_name DamagePacket

# ============================================================================
# DAMAGE TYPE ENUM (mirrors ActionEffect.DamageType)
# ============================================================================
enum DamageType {
	SLASHING,
	BLUNT,
	PIERCING,
	FIRE,
	ICE,
	SHOCK,
	POISON,
	SHADOW
}

# Physical types (reduced by armor)
const PHYSICAL_TYPES = [DamageType.SLASHING, DamageType.BLUNT, DamageType.PIERCING]

# ============================================================================
# DAMAGE VALUES BY TYPE
# ============================================================================
var damages: Dictionary = {}  # DamageType -> float

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	# Initialize all damage types to 0
	for type in DamageType.values():
		damages[type] = 0.0

# ============================================================================
# ADD DAMAGE
# ============================================================================

func add_damage(type: DamageType, amount: float):
	"""Add damage of a specific type"""
	damages[type] += amount

func add_damage_from_effect(effect: ActionEffect, dice_total: int):
	"""Add damage from an ActionEffect calculation"""
	var base = effect.base_damage
	var mult = effect.damage_multiplier
	var final_damage = (dice_total + base) * mult
	add_damage(effect.damage_type, final_damage)

func merge(other: DamagePacket):
	"""Merge another packet into this one"""
	for type in DamageType.values():
		damages[type] += other.damages[type]

# ============================================================================
# APPLY MULTIPLIER
# ============================================================================

func apply_multiplier(multiplier: float):
	"""Apply a global damage multiplier to all types"""
	for type in damages:
		damages[type] *= multiplier

func apply_type_multiplier(type: DamageType, multiplier: float):
	"""Apply multiplier to a specific damage type"""
	damages[type] *= multiplier

# ============================================================================
# CALCULATE FINAL DAMAGE
# ============================================================================

func calculate_final_damage(defender_stats: Dictionary, defense_mult: float = 1.0) -> int:
	"""
	Calculate total damage after defenses.
	
	defender_stats should contain:
	- armor: int (reduces physical)
	- fire_resist: int
	- ice_resist: int
	- shock_resist: int
	- poison_resist: int
	- shadow_resist: int
	"""
	var total: float = 0.0
	
	for type in DamageType.values():
		var damage = damages[type]
		if damage <= 0:
			continue
		
		var reduction = _get_reduction_for_type(type, defender_stats) * defense_mult
		var final = max(0.0, damage - reduction)
		total += final
	
	return int(total)

func _get_reduction_for_type(type: DamageType, stats: Dictionary) -> float:
	"""Get the appropriate resistance for a damage type"""
	match type:
		DamageType.SLASHING, DamageType.BLUNT, DamageType.PIERCING:
			return stats.get("armor", 0)
		DamageType.FIRE:
			return stats.get("fire_resist", 0)
		DamageType.ICE:
			return stats.get("ice_resist", 0)
		DamageType.SHOCK:
			return stats.get("shock_resist", 0)
		DamageType.POISON:
			return stats.get("poison_resist", 0)
		DamageType.SHADOW:
			return stats.get("shadow_resist", 0)
		_:
			return 0.0

# ============================================================================
# DEBUG / DISPLAY
# ============================================================================

func get_breakdown() -> Dictionary:
	"""Get non-zero damage types for display"""
	var breakdown = {}
	for type in damages:
		if damages[type] > 0:
			breakdown[DamageType.keys()[type]] = damages[type]
	return breakdown

func get_total_raw() -> float:
	"""Get total damage before defenses"""
	var total = 0.0
	for type in damages:
		total += damages[type]
	return total

func _to_string() -> String:
	var parts = []
	for type in damages:
		if damages[type] > 0:
			parts.append("%s: %.1f" % [DamageType.keys()[type], damages[type]])
	return "DamagePacket[%s]" % ", ".join(parts)
