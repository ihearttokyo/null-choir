extends RefCounted
# Integer-keyed local variation, independent of global RNG and frame clock.
const PERIOD: int = 2147483647
const SPREAD_CAP: float = 0.07
const SCATTER_JITTER: float = 0.003
const SCATTER_ROTATION: float = 0.0523598775598299 # Three degrees.
const MARROW_SPEED: float = 24.0 # Real travel; no fabricated hitscan velocity.
const MUZZLE_SIZES = [Vector2.ZERO,Vector2(58,86),Vector2(112,64),Vector2(44,70),Vector2(80,96),Vector2(104,104)]
const TINTS = [Color(.91,.85,.72),Color(1,.76,.40),Color(.95,.82,.62),Color(1,.50,.34),Color(.80,.57,.48),Color(.62,.82,.92)]

static func unit(sequence: int, weapon: int, stream: int) -> float:
	var value: int = (sequence%PERIOD+1+weapon*7919+stream*104729)%PERIOD
	if value <= 0: value = 1
	value = ((value ^ (value >> 16))*48271)%PERIOD
	value = (value*48271)%PERIOD # Bounded signed64 mix; consecutive shots visibly differ.
	return float(value-1)/float(PERIOD-1)

static func disk(sequence: int, weapon: int, stream: int) -> Vector2:
	return Vector2.from_angle(unit(sequence,weapon,stream)*TAU)*sqrt(unit(sequence,weapon,stream+1))

static func scatter(sequence: int, pellet: int, authored: Vector2) -> Vector2:
	if pellet == 0: return Vector2.ZERO # Keep the actual centered contact exact.
	var angle: float = (unit(sequence,2,0)*2.0-1.0)*SCATTER_ROTATION
	return (authored.rotated(angle)+disk(sequence,2,10+pellet*2)*SCATTER_JITTER).limit_length(SPREAD_CAP)

static func muzzle(weapon: int, sequence: int) -> Dictionary:
	return {"size":MUZZLE_SIZES[weapon]*(.94+.12*unit(sequence,weapon,40)),
		"tint":TINTS[weapon],"phase":int(unit(sequence,weapon,41)*2)}
