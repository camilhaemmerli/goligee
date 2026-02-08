class_name Enums

## Damage types dealt by towers and projectiles.
enum DamageType {
	PHYSICAL,
	FIRE,
	ICE,
	LIGHTNING,
	POISON,
	MAGIC,
	HOLY,
	DARK,
}

## Armor categories that determine base damage multipliers.
enum ArmorType {
	UNARMORED,
	LIGHT,
	MEDIUM,
	HEAVY,
	FORTIFIED,
	BOSS,
}

## How a projectile travels from tower to target.
enum ProjectileType {
	BULLET,     ## Fast straight line
	ARROW,      ## Arced trajectory with slight homing
	BEAM,       ## Instant continuous ray
	LOBBED,     ## Parabolic arc, hits ground with AoE
	HITSCAN,    ## Instant, no travel time
	CHAIN,      ## Jumps between enemies
	NOVA,       ## Expands outward in a ring
}

## How a tower selects which enemy to attack.
enum TargetingPriority {
	FIRST,      ## Furthest along the path
	LAST,       ## Least progress on path
	STRONGEST,  ## Highest current HP
	WEAKEST,    ## Lowest current HP
	CLOSEST,    ## Nearest to tower
}

## Status effects that can be applied to enemies.
enum StatusEffectType {
	SLOW,
	FREEZE,
	POISON,
	BURN,
	ARMOR_SHRED,
	STUN,
	MARK,       ## Takes increased damage from all sources
	WEAKEN,     ## Deals reduced damage (for future enemy attacks on base)
}

## How enemies move across the map.
enum MovementType {
	GROUND,
	FLYING,
	BURROWING,
	AQUATIC,
}

## How a stat modifier is applied.
enum ModifierOp {
	ADD,        ## base + value
	MULTIPLY,   ## base * value
	SET,        ## base = value
}

## Game speed states.
enum GameSpeed {
	PAUSED,
	NORMAL,
	FAST,
	ULTRA,
}

## Wave categories.
enum WaveType {
	NORMAL,
	ELITE,
	BOSS,
	HORDE,
	EVENT,
}
