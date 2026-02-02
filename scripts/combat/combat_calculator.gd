# combat_calculator.gd - Handles all damage calculation
extends RefCounted
class_name CombatCalculator

# ============================================================================
# MAIN DAMAGE CALCULATION
# ============================================================================

static func calculate_attack_damage(
	attacker_affixes: AffixPoolManager,
	action_effects: Array[ActionEffect],
	dice_values: Array[int],
	defender_stats: Dictionary
) -> Dictionary:
	"""
	Calculate damage from an attack.
	
	Returns:
	{
		"total_damage": int,
		"damage_packet": DamagePacket,
		"damage_mult": float,
		"defense_mult": float,
		"breakdown": Dictionary
	}
	"""
	# Step 1: Build damage packet from all effects
	var packet = DamagePacket.new()
	var dice_index = 0
	
	for effect in action_effects:
		if effect.effect_type != ActionEffect.EffectType.DAMAGE:
			continue
		
		# Calculate dice total for this effect
		var effect_dice_total = 0
		for i in range(effect.dice_count):
			if dice_index < dice_values.size():
				effect_dice_total += dice_values[dice_index]
				dice_index += 1
		
		# Add to packet
		packet.add_damage_from_effect(effect, effect_dice_total)
	
	# Step 2: Add type-specific damage bonuses from affixes
	_apply_damage_bonuses(packet, attacker_affixes)
	
	# Step 3: Calculate and apply global damage multiplier
	var damage_mult = _calculate_damage_multiplier(attacker_affixes)
	packet.apply_multiplier(damage_mult)
	
	# Step 4: Calculate defense multiplier
	var defense_mult = _calculate_defense_multiplier(defender_stats)
	
	# Step 5: Calculate final damage after defenses
	var total_damage = packet.calculate_final_damage(defender_stats, defense_mult)
	
	return {
		"total_damage": total_damage,
		"damage_packet": packet,
		"damage_mult": damage_mult,
		"defense_mult": defense_mult,
		"breakdown": packet.get_breakdown()
	}

# ============================================================================
# AFFIX APPLICATION
# ============================================================================

static func _apply_damage_bonuses(packet: DamagePacket, affixes: AffixPoolManager):
	"""Apply flat damage bonuses by type"""
	# Global damage bonus (adds to all types proportionally, or pick one)
	var global_bonus = 0.0
	for affix in affixes.get_pool(Affix.Category.DAMAGE_BONUS):
		global_bonus += affix.apply_effect()
	
	# For global bonus, add equally to all active damage types
	if global_bonus > 0:
		var active_types = 0
		for type in DamagePacket.DamageType.values():
			if packet.damages[type] > 0:
				active_types += 1
		
		if active_types > 0:
			var bonus_per_type = global_bonus / active_types
			for type in DamagePacket.DamageType.values():
				if packet.damages[type] > 0:
					packet.add_damage(type, bonus_per_type)
	
	# Type-specific bonuses
	var type_categories = {
		DamagePacket.DamageType.SLASHING: Affix.Category.SLASHING_DAMAGE_BONUS,
		DamagePacket.DamageType.BLUNT: Affix.Category.BLUNT_DAMAGE_BONUS,
		DamagePacket.DamageType.PIERCING: Affix.Category.PIERCING_DAMAGE_BONUS,
		DamagePacket.DamageType.FIRE: Affix.Category.FIRE_DAMAGE_BONUS,
		DamagePacket.DamageType.ICE: Affix.Category.ICE_DAMAGE_BONUS,
		DamagePacket.DamageType.SHOCK: Affix.Category.SHOCK_DAMAGE_BONUS,
		DamagePacket.DamageType.POISON: Affix.Category.POISON_DAMAGE_BONUS,
		DamagePacket.DamageType.SHADOW: Affix.Category.SHADOW_DAMAGE_BONUS,
	}
	
	for damage_type in type_categories:
		var category = type_categories[damage_type]
		for affix in affixes.get_pool(category):
			packet.add_damage(damage_type, affix.apply_effect())

static func _calculate_damage_multiplier(affixes: AffixPoolManager) -> float:
	"""Calculate total damage multiplier from affixes"""
	var mult = 1.0
	for affix in affixes.get_pool(Affix.Category.DAMAGE_MULTIPLIER):
		mult *= affix.apply_effect()
	return mult

static func _calculate_defense_multiplier(defender_stats: Dictionary) -> float:
	"""Calculate defender's defense multiplier"""
	# This could come from defender's affixes - for now, default 1.0
	return defender_stats.get("defense_mult", 1.0)
