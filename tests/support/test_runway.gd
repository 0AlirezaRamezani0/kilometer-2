extends RefCounted

## Synthetic high-speed runway for the two suites that need to reach 100 km/h.
##
## Why this exists: v0.2-b1 moved the game from a proving ground with a 400 m straight onto the
## desert circuit, whose longest genuinely straight, flat run is ~100 m (measured on the plan:
## 100 m at s=939 before the Start/Finish kink). The camera-lag and RPM suites have always
## measured *the camera* and *the gearbox*, not the map, and their gates (90 km/h, 95 km/h) are
## unchanged — so they now stage the run themselves instead of borrowing track geometry.
##
## The slab is placed 120 m above the circuit on its own StaticBody3D. Nothing in the map can
## reach that altitude, so the run cannot be disturbed by a kerb, a barrier or the overpass.

const ALTITUDE := 120.0
const DECK_Y := 0.36


## Adds the runway to `host` and returns the spawn transform at its near end.
static func build(host: Node3D, length := 900.0, width := 60.0) -> Transform3D:
	var body := StaticBody3D.new()
	body.name = "SyntheticRunway"
	body.set_meta("surface_grip", 1.0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 1.0, length)
	cs.shape = box
	# top face exactly at ALTITUDE + DECK_Y, so the car sits at the same ride height as on track
	cs.position = Vector3(0.0, ALTITUDE + DECK_Y - 0.5, 0.0)
	body.add_child(cs)
	host.add_child(body)
	# heading +Z (yaw 0), near end of the slab
	return Transform3D(Basis.IDENTITY, Vector3(0.0, ALTITUDE + DECK_Y + 0.06, -(length * 0.5 - 60.0)))
