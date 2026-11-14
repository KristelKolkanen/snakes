class_name Constants

const ARENA_RADIUS := 3500.0

# vision: how far bots see. think: seconds between decisions (lower = sharper).
# aggression: chance to go hunting. boost: how readily they boost.
const DIFFICULTY := {
	"easy":   {"vision": 600.0,  "think": 0.35, "aggression": 0.15, "boost": 0.2},
	"normal": {"vision": 900.0,  "think": 0.20, "aggression": 0.5,  "boost": 0.5},
	"hard":   {"vision": 1300.0, "think": 0.10, "aggression": 0.9,  "boost": 0.85},
}

static var difficulty := "normal"
