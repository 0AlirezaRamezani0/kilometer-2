class_name SceneTransitionLayer
extends CanvasLayer

## Autoload «SceneTransition»: the K2 loading screen, mounted for every scene change.
##
## v0.2-b1 replaced the old fade-plus-Persian-caption veil with the v0.1-b6 identity-v2
## loading screen (`res://scenes/ui/loading_screen.tscn`). The art direction of that module
## is strict and is enforced here rather than at each call site:
##
##   • the only type on screen is the KILOMETER logotype,
##   • progress is a vermilion rule of pure geometry (no numerals, no percentage),
##   • no status sentences, no version strings.
##
## Calls used to pass a Persian caption («در حال بارگذاری…»); the parameter is still accepted
## so no caller breaks, but it is never drawn. Any text that used to be a caption is now
## interpreted as a *stage* so the progress rule can advance honestly:
##   "…آماده‌سازی پیست"  → map stage   (plate_map + slower first half: the track mesh)
##   anything else        → intro stage (vehicle plate)
##
## Reduced motion: no fades, the screen appears and disappears instantly and progress jumps.

signal loading_finished

const LOADER_SCENE := "res://scenes/ui/loading_screen.tscn"
## The design brief for v0.2-b2 asks the loading screen to actually be *seen*: three seconds of
## dwell, simulated so the screen holds even when the next scene is already in memory. The old
## 0.72 s minimum was so short that on a fast device the logotype only flickered.
const MIN_VISIBLE := 3.0
## Even a warm scene keeps the screen up for this long, so the dwell does not depend on load
## time at all (the brief says "simulate 3 seconds of loading").
const DWELL_SECONDS := 3.0
const PROGRESS_ENTER := 0.12

var _loader: LoadingScreen = null
var _busy := false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_busy() -> bool:
	return _busy


func _ensure_loader() -> LoadingScreen:
	if _loader != null and is_instance_valid(_loader):
		return _loader
	var ps: PackedScene = load(LOADER_SCENE)
	if ps != null:
		var inst := ps.instantiate()
		if inst is LoadingScreen:
			_loader = inst
			add_child(_loader)
	return _loader


## Fades to the loading screen, swaps the scene, and dismisses the screen once the new
## scene has finished its first frames. Returns immediately; await `loading_finished`
## if a caller needs the completion edge (nothing in the game does — the screen owns it).
func change_scene(path: String, caption: String = "") -> void:
	if _busy:
		return
	_busy = true
	var loader := _ensure_loader()
	var stage := _stage_for(caption)
	var vehicle_id := _vehicle_id_for_stage(stage)
	if loader != null:
		loader.present(stage, vehicle_id)
		loader.set_progress(PROGRESS_ENTER, true)
	var shown_at := Time.get_ticks_msec() / 1000.0
	var dwell := DWELL_SECONDS

	# Give the screen one presented frame before the load stalls the main thread.
	await get_tree().process_frame
	await get_tree().process_frame
	if loader != null:
		loader.set_progress(0.45, false)

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneTransition: could not open %s (%d)" % [path, err])
		if loader != null:
			loader.dismiss()
		_busy = false
		return

	if loader != null:
		loader.set_progress(0.82, false)
	await get_tree().process_frame
	await get_tree().process_frame
	if loader != null:
		loader.set_progress(1.0, false)
		# Hold the screen for the full dwell, spread over the progress rule so it still reads as
		# loading rather than a frozen splash: 82 % -> 92 % -> 100 %, then the rest of the time.
		var elapsed := Time.get_ticks_msec() / 1000.0 - shown_at
		var seg := maxf(0.0, dwell * 0.72 - elapsed)
		if seg > 0.0:
			await get_tree().create_timer(seg).timeout
			loader.set_progress(0.94, false)
			await get_tree().create_timer(maxf(0.0, dwell - (Time.get_ticks_msec() / 1000.0 - shown_at))).timeout
		else:
			var wait := maxf(0.0, dwell - elapsed)
			if wait > 0.0:
				await get_tree().create_timer(wait).timeout
		loader.dismiss()
	_busy = false
	loading_finished.emit()


## Which plate the screen shows. The track load is the long one, so it gets the map plate.
func _stage_for(caption: String) -> String:
	if caption.contains("پیست") or caption.contains("بارگذاری"):
		return "map"
	return "intro"


func _vehicle_id_for_stage(stage: String) -> String:
	if stage == "map":
		return ""
	var idx := posmod(SettingsManager.selected_vehicle_index, VehicleCatalog.get_count())
	var entry := VehicleCatalog.get_entry(idx)
	# plate files are keyed by the short id (pride, tara, megan, quick, samand, pride132)
	return _plate_id(str(entry.get("id", "")))


func _plate_id(catalog_id: String) -> String:
	match catalog_id:
		"sport_pride":
			return "pride"
		"veh_01_ikco_tara":
			return "tara"
		"veh_02_megan":
			return "megan"
		"veh_03_pride_132":
			return "pride132"
		"veh_04_quick":
			return "quick"
		"veh_05_samand_ef7":
			return "samand"
		_:
			return "pride"


## Helper for callers that must also work when the autoload is absent
## (isolated tests): falls back to a direct scene change.
static func go(tree: SceneTree, path: String, caption: String = "") -> void:
	var st := tree.root.get_node_or_null("SceneTransition")
	if st != null and st.has_method("change_scene"):
		st.call("change_scene", path, caption)
	else:
		tree.change_scene_to_file(path)
