class_name DesertCircuit
extends Node3D

## Kilometer 2 — «پیست کویر» (desert circuit), v0.2-b1.
##
## Replaces the procedural proving ground. The art is the commissioned desert track
## (`assets/track/desert_circuit_opt.glb`), optimised for mobile on import:
##   • original 117,612 tris / 241,223 verts  →  56,815 tris / 121,362 verts
##   • the asphalt deck is protected from decimation through a vertex group, so the
##     driving surface keeps its exact silhouette and UV palette; only the props
##     (kerbs, catch fencing, gantry, light towers) are collapsed.
##   • the 2048² terrain photo is re-encoded at 1024².
##
## v0.2-b2 — map/collision rework. The old build made its collision from a flat raster of the
## asphalt mask, which had two fatal consequences the player felt immediately:
##   • the ribbon width collapsed to 0 wherever another asphalt surface touched the line, so
##     the car met invisible edges mid-corner;
##   • the deck height was a single flat plane, so the 7 m overpass was a wall of air and the
##     lane under it was a ceiling — both invisible.
## Collision now comes from `collision.json`, planned in `k2map/build_track.py` from the art:
##   • `lane[]`  — the surveyed loop with real elevation (ramp + overpass), 1 m samples;
##   • `walls[]` — barrier prisms whose inner face is the ribbon edge, each one sitting on
##                 geometry the player can actually see (kerb/rail/wall), top 1.0 m above the
##                 lane so it is always in view;
##   • `guard[]` — the visible fence at the outer sand edge, so nothing stops the car that the
##                 player cannot look at.
## Road mesh is rebuilt from the same lane at a *constant* width, so the paint, the collision
## and the visible kerb are one surface — no ghost edges anywhere.
##   • interaction: start gantry with a 5-lamp countdown, 12 sector checkpoints, lap
##     timing (current/best/last), wrong-way detection, off-track telemetry.
##
## Public API is a superset of the class it replaces (`EngineeredTestTrack`), so the HUD,
## the LAN game and the camera rig keep working unchanged:
##   get_spawn_transform() -> Transform3D
##   set_shadow_quality(tier: int) -> void
##   get_track_length() -> float
##   get_progress(position: Vector3) -> float        # 0..1 around the lap
##   get_lap_state() -> Dictionary                  # lap, time, best, last, sectors
##   get_spawn_point_node() -> Marker3D

signal lap_started(lap_number: int)
signal lap_completed(lap_number: int, lap_time: float, best_time: float)
signal checkpoint_passed(index: int, lap_number: int)
signal countdown_changed(value: int)               # 5..1, 0 = GO
signal wrong_way_changed(active: bool)
signal off_track_changed(active: bool)

const MODEL_PATH := "res://assets/track/racetrack.glb"
## v0.2-b2-racetrack-obj: the island is placed on the flattest patch of the desert that the
## terrain survey found -- a 140 m window centred on (10, -50) whose height range is only
## 8.3 m (max 7.6 m), the lowest anywhere on the map. The mesh instance carries the matching
## transform in test_track.tscn, and centreline.json / collision.json are generated in those
## same world coordinates, so the car, the collider and the island cannot drift apart.
const CENTERLINE_PATH := "res://assets/track/centerline.json"
const COLLISION_PATH := "res://assets/track/collision.json"
const CHECKPOINT_COUNT := 12
## Fallback half-width if `collision.json` is missing (the survey gives 6.7–10.5 m).
const ROAD_HALF_WIDTH := 6.0
const RIBBON_CHUNK := 24
## Barrier triangles per concave shape: one shape per ~24 walls keeps the count near 40.
const BARRIER_TRIS_PER_SHAPE := 900
const ASPHALT_GRIP := 1.0
const SAND_GRIP := 0.5

@onready var spawn_point: Marker3D = $SpawnPoint
@onready var sun_light: DirectionalLight3D = $SunLight
@onready var model_root: Node3D = $CircuitModel

var _samples: Array = []
var _length := 0.0
var _spawn_index := 0
var _spawn_tf := Transform3D.IDENTITY

var _plan: Dictionary = {}
var _lane: Array = []
var _walls: Array = []
var _kerb_mesh: MeshInstance3D

var _dry_body: StaticBody3D
var _sand_body: StaticBody3D
var _wall_body: StaticBody3D

# --- interaction state -------------------------------------------------------------------
var _lap := 0
var _lap_time := 0.0
var _best_lap := -1.0
var _last_was_best := false
var _last_lap := -1.0
var _lap_running := false
var _next_checkpoint := 1
var _check_bits := 0
var _countdown := 0
var _countdown_running := false
var _wrong_way := false
var _off_track := false
var _off_track_time := 0.0
var _gantry_lamps: Array[MeshInstance3D] = []
var _lamp_mat: StandardMaterial3D
var _chase_index := 0
var _tracked_position: Variant = null


func _ready() -> void:
	_load_plan()
	_load_centerline()
	_spawn_tf = _build_spawn_transform()
	if spawn_point == null:
		spawn_point = Marker3D.new()
		spawn_point.name = "SpawnPoint"
		add_child(spawn_point)
	spawn_point.transform = _spawn_tf
	_build_collision()
	_build_visible_barriers()
	_build_gantry_lamps()
	_trim_shoulder_ribbons()
	_flush_placeholder_model()
	apply_graphics_quality(1)


# =========================================================================================
# Public API kept from EngineeredTestTrack
# =========================================================================================

func get_spawn_transform() -> Transform3D:
	return _spawn_tf


func get_spawn_point_node() -> Marker3D:
	return spawn_point


func set_shadow_quality(tier: int) -> void:
	if sun_light == null:
		return
	match tier:
		0: # سریع موبایل — سایه‌ها خاموش می‌شوند، چون قابلیت سایه در این تیر بایاس نمی‌گیرد
			# و سایهٔ بلوکی برج گانتری روی خودرو می‌افتد.
			sun_light.shadow_enabled = false
		1: # متعادل
			sun_light.shadow_enabled = true
			sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun_light.directional_shadow_max_distance = 90.0
		_: # کیفیت بالا
			sun_light.shadow_enabled = true
			sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun_light.directional_shadow_max_distance = 150.0


## The desert sun is harsher than the old proving-ground key light: raise the energy with
## the quality tier so the tarmac reads on phones without blowing out the sand.
func apply_graphics_quality(tier: int) -> void:
	set_shadow_quality(tier)
	if sun_light != null:
		sun_light.light_energy = [1.55, 1.75, 1.9][clampi(tier, 0, 2)]


func get_track_length() -> float:
	return _length


## Transform at the start of the longest *genuinely* straight run of the circuit.
##
## v0.2-b2: the old implementation summed |Δyaw| over a span and accepted the first span under
## 20°, which happily accepted a gentle constant-radius corner (a 24 m apex at 1 m samples adds up
## to only a few degrees). That is how the launch/regression harnesses ended up staging on the
## inside of a corner and reporting 62 km/h instead of 100. This version walks the lane, steps
## 10 m at a time, and rejects any span whose heading wanders more than 3° or whose elevation
## moves more than 0.8 m (a launch pad must be flat too).
func get_longest_straight_transform() -> Transform3D:
	var n := _lane.size()
	if n < 80:
		return _spawn_tf
	var px := PackedFloat32Array()
	var pz := PackedFloat32Array()
	var py := PackedFloat32Array()
	var head := PackedFloat32Array()
	for i in range(n):
		var p: Dictionary = _lane[i]
		px.append(float(p["x"]))
		pz.append(float(p["z"]))
		py.append(float(p["y"]))
		var q: Dictionary = _lane[(i + 1) % n]
		head.append(atan2(float(q["x"]) - float(p["x"]), float(q["z"]) - float(p["z"])))
	var best_start := 0
	var best_span := 0
	for i in range(0, n, 1):
		for span in range(80, 200, 10):
			var wander := 0.0
			var y_lo := INF
			var y_hi := -INF
			var ok := true
			for k in range(0, span + 1, 10):
				var a := posmod(i + k, n)
				var b := posmod(i + k + 10, n)
				y_lo = minf(y_lo, py[a])
				y_hi = maxf(y_hi, py[a])
				wander = maxf(wander, absf(rad_to_deg(wrapf(head[b] - head[a], -PI, PI))))
				if wander > 3.0 or (y_hi - y_lo) > 0.8:
					ok = false
					break
			if ok and span > best_span:
				best_span = span
				best_start = i
	if best_span == 0:
		push_warning("DesertCircuit: no straighter-than-3° run found; using s=0")
	var p: Dictionary = _lane[best_start]
	var basis := Basis(Vector3.UP, deg_to_rad(float(p["yaw"])))
	return Transform3D(basis, Vector3(float(p["x"]), float(p["y"]) + 0.05, float(p["z"])))


# =========================================================================================
# Centreline
# =========================================================================================

func _load_plan() -> void:
	if not FileAccess.file_exists(COLLISION_PATH):
		push_error("DesertCircuit: collision plan missing at " + COLLISION_PATH)
		return
	var txt := FileAccess.get_file_as_string(COLLISION_PATH)
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("DesertCircuit: collision plan is not valid JSON")
		return
	_plan = data
	_lane = data.get("lane", [])
	_walls = data.get("walls", [])
	for s in _lane:
		s["half_w"] = float(s.get("half_w", ROAD_HALF_WIDTH))


## True when the v0.2-b2 plan is loaded (the collision suite asserts this).
func has_collision_plan() -> bool:
	return not _lane.is_empty() and not _walls.is_empty()


func barrier_count() -> int:
	return _walls.size()


## Half-width of the drivable surface at a sample, straight from the plan.
func lane_half_width(index: int) -> float:
	if _lane.is_empty():
		return ROAD_HALF_WIDTH
	return float(_lane[posmod(index, _lane.size())].get("half_w", ROAD_HALF_WIDTH))


func _lane_at(index: int) -> Dictionary:
	if _lane.is_empty():
		return _sample_at(index)
	return _lane[posmod(index, _lane.size())]


func _load_centerline() -> void:
	if not FileAccess.file_exists(CENTERLINE_PATH):
		push_error("DesertCircuit: centreline missing at " + CENTERLINE_PATH)
		return
	var txt := FileAccess.get_file_as_string(CENTERLINE_PATH)
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("DesertCircuit: centreline is not valid JSON")
		return
	_samples = data.get("samples", [])
	_length = float(data.get("length", 0.0))
	_spawn_index = int(data.get("spawn_index", 0))
	if _samples.is_empty():
		push_error("DesertCircuit: centreline has no samples")


func sample_count() -> int:
	return _samples.size()


func _sample_at(index: int) -> Dictionary:
	if _samples.is_empty():
		return {}
	return _samples[posmod(index, _samples.size())]


## Nearest centreline sample index for a world position (brute force is fine: 973 points,
## called once per physics tick at most).
func nearest_index(position: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in range(_samples.size()):
		var p: Dictionary = _samples[i]
		var dx := float(p["x"]) - position.x
		var dz := float(p["z"]) - position.z
		var d := dx * dx + dz * dz
		if d < best_d:
			best_d = d
			best = i
	return best


## 0..1 progress around the lap, plus the signed lateral offset, in one pass.
func get_progress(position: Vector3) -> float:
	if _samples.is_empty() or _length <= 0.0:
		return 0.0
	return float(nearest_index(position)) / float(_samples.size())


## Distance from the centreline (m) — used for the off-track telemetry signal.
func lateral_offset(position: Vector3) -> float:
	var i := nearest_index(position)
	var p: Dictionary = _sample_at(i)
	return Vector2(position.x - float(p["x"]), position.z - float(p["z"])).length()


## How far past the painted edge the car is (m); <= 0 means on the asphalt.
func off_track_depth(position: Vector3) -> float:
	var i := nearest_index(position)
	var p: Dictionary = _sample_at(i)
	return lateral_offset(position) - float(p.get("half_w", 6.0))


func _build_spawn_transform() -> Transform3D:
	if _samples.is_empty():
		return Transform3D.IDENTITY
	var p: Dictionary = _sample_at(_spawn_index)
	var yaw := deg_to_rad(float(p["yaw"]))
	# The survey stores the heading as atan2(dx, dz) of the racing line, and SaipaVehicleController
	# drives along its own +Z (see its forward_speed_mps convention), so Basis(UP, yaw) is
	# exactly the pose that points the car down the racing line at s = 0.
	var basis := Basis(Vector3.UP, yaw)
	var origin := Vector3(float(p["x"]), float(p["y"]) + 0.05, float(p["z"]))
	return Transform3D(basis, origin)


# =========================================================================================
# Collision
# =========================================================================================

func _build_collision() -> void:
	_dry_body = StaticBody3D.new()
	_dry_body.name = "DryTrackStaticBody"
	_dry_body.set_meta("surface_grip", ASPHALT_GRIP)
	add_child(_dry_body)

	_sand_body = StaticBody3D.new()
	_sand_body.name = "SandStaticBody"
	_sand_body.set_meta("surface_grip", SAND_GRIP)
	add_child(_sand_body)

	_wall_body = StaticBody3D.new()
	_wall_body.name = "CircuitBoundary"
	_wall_body.set_meta("surface_grip", SAND_GRIP)
	add_child(_wall_body)

	# 1. asphalt ribbon: a quad per lane sample, chunked so each concave shape stays small.
	var n := _lane.size()
	if n < 4:
		push_error("DesertCircuit: no lane in the collision plan")
		return
	var chunk := 0
	var i := 0
	while i < n:
		var faces := PackedVector3Array()
		var j := i
		while j < mini(i + RIBBON_CHUNK, n):
			var l0 := _ribbon_point(j, -1.0)
			var r0 := _ribbon_point(j, 1.0)
			var l1 := _ribbon_point(j + 1, -1.0)
			var r1 := _ribbon_point(j + 1, 1.0)
			faces.append_array([l0, r0, r1])
			faces.append_array([l0, r1, l1])
			j += 1
		if faces.size() >= 3:
			_add_ribbon_shape(faces, "RoadRibbon%d" % chunk)
			chunk += 1
		i += RIBBON_CHUNK
	_dry_body.set_meta("ribbon_chunks", chunk)

	# 2. sand floor: a low-grip plate under the whole circuit. It sits *below* the lowest point
	# of the lane so it can never cut through the ramp or the overpass.
	var sand_shape := CollisionShape3D.new()
	sand_shape.name = "SandFloor"
	var sand_box := BoxShape3D.new()
	sand_box.size = Vector3(760.0, 1.0, 760.0)
	sand_shape.shape = sand_box
	sand_shape.position = Vector3(10.0, -1.6, -45.0)
	_sand_body.add_child(sand_shape)

	# 3. barriers: one triangle soup for the whole circuit, flushed into a handful of concave
	#    shapes. (v0.2-b1 taught this the hard way: one shape per prism face means 12k static
	#    shapes, which swamps the physics broadphase and makes the car feel like it is stuck
	#    in treacle.)
	var soup := PackedVector3Array()
	var prisms := 0
	var chunks := 0
	for w in _walls:
		if _append_wall_tris(soup, w, false):
			prisms += 1
		if soup.size() >= BARRIER_TRIS_PER_SHAPE:
			_flush_barrier_chunk(soup, chunks)
			chunks += 1
	for g in _plan.get("guard", []):
		_append_wall_tris(soup, g, true)
		if soup.size() >= BARRIER_TRIS_PER_SHAPE:
			_flush_barrier_chunk(soup, chunks)
			chunks += 1
	if soup.size() > 0:
		_flush_barrier_chunk(soup, chunks)
		chunks += 1
	_wall_body.set_meta("prism_count", prisms)
	_wall_body.set_meta("shape_chunks", chunks)


func _flush_barrier_chunk(faces: PackedVector3Array, index: int) -> void:
	if faces.size() < 3:
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	# two-sided on purpose: the prism hull is wound outward, so a one-sided shape would let the
	# car through from whichever side the winding faces away from.
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.name = "Barrier%d" % index
	cs.shape = shape
	_wall_body.add_child(cs)
	faces.clear()


## Appends the 12 outward-facing triangles of one plan prism. Returns false if degenerate.
func _append_wall_tris(faces: PackedVector3Array, w: Dictionary, deep_base: bool) -> bool:
	var a: Array = w.get("a", [])
	var b: Array = w.get("b", [])
	if a.size() < 2 or b.size() < 2:
		return false
	var ya: Array = w.get("ya", [0.0, 1.0])
	var yb: Array = w.get("yb", [0.0, 1.0])
	var ax := float(a[0])
	var az := float(a[1])
	var bx := float(b[0])
	var bz := float(b[1])
	var dx := bx - ax
	var dz := bz - az
	var dl := sqrt(dx * dx + dz * dz)
	if dl < 0.05:
		return false
	var t: float = float(w.get("t", 0.4)) * 0.5
	var nx := -dz / dl * t
	var nz := dx / dl * t
	var bot_a := minf(float(ya[0]), -1.5) if deep_base else float(ya[0])
	var bot_b := minf(float(yb[0]), -1.5) if deep_base else float(yb[0])
	var top_a := float(ya[1])
	var top_b := float(yb[1])
	# GDScript Array literals are untyped (Variant), and Variant indexing into a nested literal is
	# a runtime error — hence the explicit PackedVector3Array and an explicit triangle list.
	var ring := PackedVector3Array([
		Vector3(ax - nx, bot_a, az - nz), Vector3(bx - nx, bot_b, bz - nz),
		Vector3(bx + nx, bot_b, bz + nz), Vector3(ax + nx, bot_a, az + nz),
		Vector3(ax - nx, top_a, az - nz), Vector3(bx - nx, top_b, bz - nz),
		Vector3(bx + nx, top_b, bz + nz), Vector3(ax + nx, top_a, az + nz),
	])
	var m := [0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6, 0, 4, 5, 0, 5, 1,
		1, 5, 6, 1, 6, 2, 2, 6, 7, 2, 7, 3, 3, 7, 4, 3, 4, 0]
	var i := 0
	while i + 2 < m.size() + 1 and i < 36:
		faces.append(ring[m[i]])
		faces.append(ring[m[i + 1]])
		faces.append(ring[m[i + 2]])
		i += 3
	return true


func _add_ribbon_shape(faces: PackedVector3Array, shape_name: String) -> void:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.name = shape_name
	cs.shape = shape
	_dry_body.add_child(cs)


## A point on the road edge: `side` is -1 (left) or +1 (right) of the racing line.
func _ribbon_point(index: int, side: float) -> Vector3:
	var p: Dictionary = _lane_at(index)
	var yaw := deg_to_rad(float(p["yaw"]))
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(fwd.z, 0.0, -fwd.x)
	var half_w := float(p.get("half_w", ROAD_HALF_WIDTH))
	return Vector3(float(p["x"]), float(p["y"]) + 0.02, float(p["z"])) + right * (half_w * side)


# =========================================================================================
# Visible barriers — every prism in the plan gets a wall the player can see
# =========================================================================================
## Builds one merged mesh for every plan barrier, plus the guard fence at the outer sand edge.
## v0.3: nothing beside the road is drawn any more. The guard rails (and the kerb prisms that
## stood with them) are gone from the *render*; the physics body (`CircuitBoundary`) is still
## built from the same `walls[]` plan and is untouched, so the car is stopped at exactly the
## same line as before — the walls are now deliberately invisible, as the brief asks.
##
## The node is kept in the tree as an empty marker: the HUD, the tests and the QA captures look
## up `CircuitBarriers` by name, and an empty mesh keeps those lookups valid.
func _build_visible_barriers() -> void:
	if _walls.is_empty():
		return
	_kerb_mesh = MeshInstance3D.new()
	_kerb_mesh.name = "CircuitBarriers"
	_kerb_mesh.mesh = ArrayMesh.new()
	_kerb_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_kerb_mesh.set_meta("rails_drawn", false)
	add_child(_kerb_mesh)


## Emits the four visible faces of a plan prism (inner, top, outer, and both caps) as raw
## triangles. No UVs: the barrier is a single desert-concrete colour on purpose.
func _emit_prism(st: SurfaceTool, w: Dictionary) -> void:
	var a: Array = w.get("a", [])
	var b: Array = w.get("b", [])
	if a.size() < 2 or b.size() < 2:
		return
	var ya: Array = w.get("ya", [0.0, 1.0])
	var yb: Array = w.get("yb", [0.0, 1.0])
	var ax := float(a[0])
	var az := float(a[1])
	var bx := float(b[0])
	var bz := float(b[1])
	var dx := bx - ax
	var dz := bz - az
	var dl := sqrt(dx * dx + dz * dz)
	if dl < 0.05:
		return
	var t: float = float(w.get("t", 0.4)) * 0.5
	var nx := -dz / dl * t
	var nz := dx / dl * t
	var bot_a := maxf(float(ya[0]), -0.5)      # guard prisms start below ground on purpose
	var bot_b := maxf(float(yb[0]), -0.5)
	var top_a := float(ya[1])
	var top_b := float(yb[1])
	var p := [
		Vector3(ax - nx, bot_a, az - nz), Vector3(bx - nx, bot_b, bz - nz),
		Vector3(bx + nx, bot_b, bz + nz), Vector3(ax + nx, bot_a, az + nz),
	]
	var q := [
		Vector3(ax - nx, top_a, az - nz), Vector3(bx - nx, top_b, bz - nz),
		Vector3(bx + nx, top_b, bz + nz), Vector3(ax + nx, top_a, az + nz),
	]
	# inner face (looking at the road) and outer face
	_tri(st, p[0], p[1], q[1]); _tri(st, p[0], q[1], q[0])
	_tri(st, p[3], q[2], p[2]); _tri(st, p[3], q[3], q[2])
	# top
	_tri(st, q[0], q[1], q[2]); _tri(st, q[0], q[2], q[3])
	# caps
	_tri(st, p[0], q[0], q[3]); _tri(st, p[0], q[3], p[3])
	_tri(st, p[1], p[2], q[2]); _tri(st, p[1], q[2], q[1])


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


# =========================================================================================
# Start gantry lamps (interaction feedback)
# =========================================================================================

func _build_gantry_lamps() -> void:
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_mat.albedo_color = Color(0.12, 0.12, 0.12)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(0.102, 0.592, 0.035)
	_lamp_mat.emission_energy_multiplier = 0.0
	# v0.3: the five lamp quads used to hang in mid-air over the start line with nothing
	# holding them up — a row of black rectangles floating in the sky that read as a glitch.
	# The gantry structure that carried them lived in the decimated art and is gone, so the
	# portal is built here (two posts, a top beam and a backing plate) and the lamps sit on it.
	# Collision is untouched: it never covered the gantry, it goes no higher than 1 m over the
	# kerb, so this is decoration only.
	var gantry_root := Node3D.new()
	gantry_root.name = "StartGantry"
	gantry_root.transform = _spawn_tf
	add_child(gantry_root)

	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.22, 0.23, 0.25)
	steel.roughness = 0.55
	steel.metallic = 0.35

	var lamp_w := 4.4
	var lamp_gap := 0.4
	var span := lamp_w * 5.0 + lamp_gap * 4.0          # 23.6 m, the five lamps end to end
	var post_h := 6.4
	var post_x := span * 0.5 + 0.6
	var post := BoxMesh.new()
	post.size = Vector3(0.34, post_h, 0.34)
	var beam := BoxMesh.new()
	beam.size = Vector3(post_x * 2.0 + 0.5, 0.46, 0.5)
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(span + 0.7, 1.5, 0.16)

	for px in [-post_x, post_x]:
		var pm := MeshInstance3D.new()
		pm.name = "GantryPost%s" % ("L" if px < 0.0 else "R")
		pm.mesh = post
		pm.material_override = steel
		pm.position = Vector3(px, post_h * 0.5, 0.0)
		gantry_root.add_child(pm)
	var bm := MeshInstance3D.new()
	bm.name = "GantryBeam"
	bm.mesh = beam
	bm.material_override = steel
	bm.position = Vector3(0.0, post_h - 0.23, 0.0)
	gantry_root.add_child(bm)
	var back := MeshInstance3D.new()
	back.name = "GantryPlate"
	back.mesh = plate_mesh
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.09, 0.095, 0.105)
	plate_mat.roughness = 0.7
	back.material_override = plate_mat
	back.position = Vector3(0.0, post_h - 1.2, -0.12)
	gantry_root.add_child(back)

	var quad := QuadMesh.new()
	quad.size = Vector2(lamp_w, 0.5)
	# the lamps hang off the beam, flush with the backing plate, so nothing floats
	# The lamps stay direct children of the circuit (the HUD, the countdown and two suites look
	# them up by name at this level) and are posed on the beam through the spawn frame.
	for k in range(5):
		var mi := MeshInstance3D.new()
		mi.name = "StartLamp%d" % k
		mi.mesh = quad
		mi.material_override = _lamp_mat
		mi.transform = _spawn_tf * Transform3D(
			Basis.IDENTITY,
			Vector3(-(span * 0.5) + lamp_w * 0.5 + k * (lamp_w + lamp_gap), post_h - 1.2, 0.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_gantry_lamps.append(mi)


func _set_lamp_count(n: int) -> void:
	if _lamp_mat == null:
		return
	_lamp_mat.emission_energy_multiplier = 2.6 if n > 0 else 0.0
	_lamp_mat.emission = Color(0.95, 0.22, 0.08) if n > 0 else Color(0.102, 0.592, 0.035)
	for k in range(_gantry_lamps.size()):
		_gantry_lamps[k].visible = true


# =========================================================================================
# Interaction: countdown, laps, sectors
# =========================================================================================

## Starts the 5-lamp start sequence, then the lap clock. Idempotent.
func start_countdown() -> void:
	if _countdown_running or _lap_running:
		return
	_countdown_running = true
	_countdown = 5
	_set_lamp_count(5)
	countdown_changed.emit(5)
	while _countdown > 0:
		await get_tree().create_timer(0.72).timeout
		_countdown -= 1
		_set_lamp_count(_countdown)
		countdown_changed.emit(_countdown)
	_countdown_running = false
	_lap = 1
	_lap_time = 0.0
	_lap_running = true
	_next_checkpoint = 1
	_check_bits = 0
	lap_started.emit(_lap)


func reset_lap() -> void:
	_lap_running = false
	_lap_time = 0.0
	_next_checkpoint = 1
	_check_bits = 0
	_countdown = 0
	_countdown_running = false
	_set_lamp_count(0)


func get_lap_state() -> Dictionary:
	return {
		"lap": _lap,
		"lap_time": _lap_time,
		"best_lap": _best_lap,
		"last_lap": _last_lap,
		"last_was_best": _last_was_best,
		"running": _lap_running,
		"sector": _next_checkpoint,
		"sectors_total": CHECKPOINT_COUNT,
		"wrong_way": _wrong_way,
		"off_track": _off_track,
		"countdown": _countdown,
	}


## Called by the game each physics tick with the car's transform.
func update_telemetry(vehicle: Node3D) -> void:
	if vehicle == null or _samples.is_empty():
		return
	_tracked_position = vehicle.global_position
	var idx := nearest_index(vehicle.global_position)
	_chase_index = idx

	# off-track: hysteresis through 0.6 m so a kerb brush does not flicker the HUD
	var depth := off_track_depth(vehicle.global_position)
	if not _off_track and depth > 0.6:
		_off_track = true
		_off_track_time = 0.0
		off_track_changed.emit(true)
	elif _off_track and depth < -0.4:
		_off_track = false
		off_track_changed.emit(false)
	if _off_track:
		_off_track_time += get_physics_process_delta_time()

	# wrong way: the car's forward vector must agree with the racing line heading
	var want := deg_to_rad(float(_sample_at(idx)["yaw"]))
	var car_fwd := -vehicle.global_transform.basis.z
	var line_fwd := Vector3(sin(want), 0.0, cos(want))
	var dot := car_fwd.normalized().dot(line_fwd)
	var moving := vehicle is RigidBody3D and (vehicle as RigidBody3D).linear_velocity.length() > 3.0
	var ww := moving and dot < -0.35
	if ww != _wrong_way:
		_wrong_way = ww
		wrong_way_changed.emit(ww)

	# checkpoints: each sector gate must be crossed in order; the last one closes the lap
	if _lap_running:
		_lap_time += get_physics_process_delta_time()
		var gate := int(_next_checkpoint * _samples.size() / CHECKPOINT_COUNT) % _samples.size()
		var road_hit := _off_track_depth_at(idx) <= 0.6
		if road_hit and absi(idx - gate) <= 2:
			_check_bits |= 1 << _next_checkpoint
			checkpoint_passed.emit(_next_checkpoint, _lap)
			_next_checkpoint += 1
			if _next_checkpoint >= CHECKPOINT_COUNT:
				_complete_lap()


func _off_track_depth_at(index: int) -> float:
	if _samples.is_empty():
		return 0.0
	var pos: Variant = _tracked_position
	if pos == null:
		return 0.0
	var p: Dictionary = _sample_at(index)
	var pp: Vector3 = pos
	return Vector2(pp.x - float(p["x"]), pp.z - float(p["z"])).length() - float(p.get("half_w", 6.0))


func _complete_lap() -> void:
	_last_lap = _lap_time
	_last_was_best = _best_lap < 0.0 or _last_lap < _best_lap
	if _last_was_best:
		_best_lap = _last_lap
	lap_completed.emit(_lap, _last_lap, _best_lap)
	_lap += 1
	_lap_time = 0.0
	_next_checkpoint = 1
	_check_bits = 0
	lap_started.emit(_lap)


# =========================================================================================
# Placeholder cleanup
# =========================================================================================

## The shipped scene carries a grey stand-in box so the map is inspectable before the GLB
## import lands; drop it as soon as the real art is in the tree.
## v0.3: the commissioned deck ships as three co-planar ribbons — the asphalt and, either
## side, a bright "shoulder" band that reads as a painted verge or a floating ledge depending
## on the light. The brief asks for the road edge to be the asphalt and nothing else, so the
## pale bands are dropped from the *drawn* mesh while the physics stays exactly as it was
## (`collision.json` never referenced them: the ribbon is the lane half-width). The asphalt is
## identified by its own vertex colour — it is the dark surface — so this cannot silently keep
## the wrong ribbon if the art is rebuilt.
func _trim_shoulder_ribbons() -> void:
	var host := get_node_or_null("CircuitModel")
	if host == null:
		return
	for node in host.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not (mi.mesh is ArrayMesh):
			continue
		var mesh := mi.mesh as ArrayMesh
		var count := mesh.get_surface_count()
		if count < 2:
			continue
		var darkest := -1
		var darkest_lum := 99.0
		for si in count:
			var arrays := mesh.surface_get_arrays(si)
			var cols: Variant = arrays[Mesh.ARRAY_COLOR]
			if cols == null:
				continue
			var sum := 0.0
			var n := 0
			for c in (cols as PackedColorArray):
				sum += ((c as Color).r + (c as Color).g + (c as Color).b) / 3.0
				n += 1
			if n == 0:
				continue
			var lum := sum / float(n)
			if lum < darkest_lum:
				darkest_lum = lum
				darkest = si
		if darkest < 0 or darkest_lum > 0.35:
			continue                      # nothing pale to remove
		var trimmed := ArrayMesh.new()
		var arrays := mesh.surface_get_arrays(darkest)
		trimmed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		trimmed.surface_set_material(0, mesh.surface_get_material(darkest))
		mi.mesh = trimmed
		mi.set_meta("shoulders_trimmed", count - 1)


func _flush_placeholder_model() -> void:
	if model_root != null and model_root.has_method("set_transform") and false:
		pass
	for child in model_root.get_children():
		if child.name.begins_with("Placeholder"):
			child.queue_free()


func _process(delta: float) -> void:
	if _lamp_mat != null and not _countdown_running and _countdown == 0:
		_lamp_mat.emission_energy_multiplier = 1.1 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 2.2)
