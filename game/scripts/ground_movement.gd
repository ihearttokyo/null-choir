extends RefCounted
# Independent numeric model; no Doom implementation or lookup tables copied.
# Units inside this object: horizontal map units per 1/35-second interval.
const RATE = 35.0
const TICK = 1.0 / RATE
const SCALE = 0.02
const FRICTION = 29.0 / 32.0
const STOP = 1.0 / 16.0
const LIMIT = 30.0
const EPSILON = 1.0e-12

var momentum := Vector2.ZERO
var _interval := Vector2.ZERO
var _remaining := 0.0
var _commanded := false

func reset() -> void:
	momentum = Vector2.ZERO
	_interval = Vector2.ZERO
	_remaining = 0.0
	_commanded = false

func travel(delta: float, axes: Vector2, right: Vector2, forward: Vector2, running: bool, grounded: bool) -> Vector2:
	if not is_finite(delta) or delta <= 0.0: return Vector2.ZERO
	var remaining := delta
	var distance := Vector2.ZERO
	while remaining > EPSILON:
		if _remaining <= EPSILON:
			var command := Vector2(clampf(axes.x,-1.0,1.0),clampf(axes.y,-1.0,1.0))
			_commanded = command != Vector2.ZERO
			_interval = momentum
			if grounded:
				var side := 40.0 if running else 24.0
				var ahead := 50.0 if running else 25.0
				_interval += (right*command.x*side + forward*command.y*ahead)/32.0
			_interval = Vector2(clampf(_interval.x,-LIMIT,LIMIT),clampf(_interval.y,-LIMIT,LIMIT))
			_remaining = TICK
		var span := minf(remaining,_remaining)
		distance += _interval*(span*RATE*SCALE)
		_remaining -= span
		remaining -= span
		if _remaining <= EPSILON:
			# Use the most recent floor sample, not a latched pre-ledge ground flag.
			momentum = _interval
			if grounded:
				if not _commanded and absf(momentum.x) < STOP and absf(momentum.y) < STOP:
					momentum = Vector2.ZERO
				else:
					momentum *= FRICTION
			_remaining = 0.0
	return distance

func block(normal: Vector2) -> void:
	if normal.length_squared() <= EPSILON: return
	var outward := normal.normalized()
	# Clear both current interval and retained momentum; never bank wall thrust.
	_interval -= outward*minf(_interval.dot(outward),0.0)
	momentum -= outward*minf(momentum.dot(outward),0.0)
