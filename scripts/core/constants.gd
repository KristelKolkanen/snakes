class_name Constants

const ARENA_RADIUS := 12000.0
const COIL_LENGTH := 1500.0              # snakes longer than this start coiled in an arc

const DIFFICULTY := {
	"easy":   {"vision": 600.0,  "think": 0.35, "aggression": 0.15, "boost": 0.2,  "speed": 0.85},
	"normal": {"vision": 900.0,  "think": 0.20, "aggression": 0.5,  "boost": 0.5,  "speed": 1.2},
	"hard":   {"vision": 1300.0, "think": 0.10, "aggression": 0.9,  "boost": 0.85, "speed": 1.8},
}

const PLAYER_SPEED_SCALES := true

static var difficulty := "normal"


# Continuous version of the growth curve (5 points per segment early on, flattening for huge snakes)
static func segments_f(points: float) -> float:
	return 12.0 + 5.06 * (sqrt(points + 100.0) - sqrt(160.0))


static func segments_for(points: float) -> int:
	return int(segments_f(points))


# Inverse of segments_f: the score at which a snake has this many segments
static func points_for_segments(seg: float) -> float:
	var r := (seg - 12.0) / 5.06 + sqrt(160.0)
	return maxf(r * r - 100.0, 0.0)
