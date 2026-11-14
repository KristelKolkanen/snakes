class_name Constants

const ARENA_RADIUS := 3500.0

# vision: how far bots see. think: seconds between decisions (lower = sharper).
# aggression: chance to go hunting. boost: how readily they boost.
const DIFFICULTY := {
	"easy":   {"vision": 600.0,  "think": 0.35, "aggression": 0.15, "boost": 0.2,  "speed": 0.85},
	"normal": {"vision": 900.0,  "think": 0.20, "aggression": 0.5,  "boost": 0.5,  "speed": 1.0},
	"hard":   {"vision": 1300.0, "think": 0.10, "aggression": 0.9,  "boost": 0.85, "speed": 1.2},
}

const PLAYER_SPEED_SCALES := true    # false = only bots get faster, you stay at base speed

static var difficulty := "normal"
