extends Node3D

## Main playable scene coordinator (pass 3).
## The vehicle is chosen ONLY in the main-menu showroom
## (SettingsManager.selected_vehicle_index) and is locked for the whole
## session: there is no in-game vehicle switching input or UI, and
## spawning a vehicle never mutates graphics settings. Graphics are
## applied exactly once at scene start from the persisted tier, and
## afterwards only when the user edits them in Settings.

@onready var track: DesertCircuit = $EngineeredTestTrack
@onready var camera_rig: VehicleCameraRig = $VehicleCameraRig
@onready var hud: VehicleHud = $VehicleHud

var vehicle: SaipaVehicleController = null
var active_vehicle_index: int = 0
## F2/F3 (K2-REDESIGN-001): replay snapshots + ghost segment recorder.
var recorder: ReplayRecorder = null


func _ready() -> void:
	VehicleInputMap.ensure_actions()
	SettingsManager.load_settings()
	active_vehicle_index = SettingsManager.selected_vehicle_index
	vehicle = spawn_vehicle(active_vehicle_index)

	var spawn_tf := track.get_spawn_transform()
	vehicle.set_spawn_transform(spawn_tf)
	vehicle.reset_vehicle(spawn_tf)
	camera_rig.bind_vehicle(vehicle)
	hud.bind_systems(vehicle, camera_rig, track, self)
	# Graphics: single application at scene start. Vehicle spawn above did
	# not (and must not) touch viewport/track graphics state.
	hud.apply_graphics_quality(SettingsManager.graphics_tier)
	SettingsManager.apply_to_systems(hud, camera_rig)
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_driving_music"):
		am.call("play_driving_music", false)
	recorder = ReplayRecorder.new()
	recorder.name = "ReplayRecorder"
	add_child(recorder)
	recorder.bind(vehicle, hud)
	recorder.replay_started.connect(func(): hud.set_replay_active(true))
	recorder.replay_finished.connect(func(): hud.set_replay_active(false))
	# v0.2-b2 desert circuit: start lights + lap timing. The lap clock starts when the 5-lamp
	# sequence ends; the grid sits behind the gantry at s=0.
	# The sequence is *not* started here any more. The v0.2-b2 loading screen dwells for 3 s, and
	# the countdown used to run behind it, so the player arrived at a lap already 1.4 s old with
	# no lights. `race_ready()` is called by the scene flow once the loading screen is gone.
	pass


## Called by the scene flow (and by the tests) once the loading screen has been dismissed, so
## the 5-lamp sequence and the lap clock start with the player actually watching.
func race_ready() -> void:
	if track != null and track.has_method("start_countdown"):
		track.start_countdown()


## Instantiates the catalog vehicle for `index` at the track spawn.
## Used once at startup; also used by automated tests/capture tools.
## There is intentionally no player-facing binding to this method.
func spawn_vehicle(index: int) -> SaipaVehicleController:
	var target_idx := posmod(index, VehicleCatalog.get_count())
	var spawn_tf := track.get_spawn_transform()

	# Remove every existing vehicle (including the scene's placeholder
	# instance on first spawn) so exactly one VehicleBody3D ever exists.
	for child in get_children():
		if child is SaipaVehicleController:
			remove_child(child)
			child.queue_free()
	vehicle = null

	var entry := VehicleCatalog.get_entry(target_idx)
	var packed := load(str(entry["vehicle_scene"])) as PackedScene
	if packed == null:
		push_error("Failed to load vehicle scene: " + str(entry["vehicle_scene"]))
		return vehicle
	var new_car := packed.instantiate() as SaipaVehicleController
	if new_car == null:
		push_error("Vehicle scene did not instantiate as SaipaVehicleController: " + str(entry["vehicle_scene"]))
		return vehicle
	new_car.name = "SaipaPrideVehicle" if target_idx == 0 else ("Vehicle_" + str(entry["id"]))
	add_child(new_car)
	# K2-FINAL-003: per-vehicle engine sound, parented to the car so it
	# frees and pauses with it.
	var engine_audio := EngineAudio.new()
	engine_audio.name = "EngineAudio"
	new_car.add_child(engine_audio)
	engine_audio.configure(new_car, target_idx)

	vehicle = new_car
	active_vehicle_index = target_idx
	vehicle.set_spawn_transform(spawn_tf)
	# Spawn-time initialization to the CURRENT global tier only; the tier
	# itself, viewport scaling and track shadows are never changed here.
	vehicle.set_graphics_quality_tier(SettingsManager.graphics_tier)
	vehicle.reset_vehicle(spawn_tf)
	if camera_rig != null:
		camera_rig.bind_vehicle(vehicle)
	if hud != null:
		hud.bind_systems(vehicle, camera_rig, track, self)
	if recorder != null:
		recorder.bind(vehicle, hud)
	return vehicle


## v0.2-b1: feeds the circuit's lap/sector/off-track telemetry once per physics tick.
## The track owns the state; the HUD reads it through `track.get_lap_state()`.
func _physics_process(_delta: float) -> void:
	if track != null and vehicle != null:
		track.update_telemetry(vehicle)


## F2: replay the last 15 seconds of driving (HUD tray entry point).
func start_replay() -> bool:
	if recorder != null:
		return recorder.start_replay()
	return false


## F3: toggle the translucent ghost of the best recorded segment.
func toggle_ghost() -> void:
	if recorder != null:
		recorder.toggle_ghost()
