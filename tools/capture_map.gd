extends SceneTree

## Runtime capture of the desert circuit.
##   xvfb-run godot --path . --script res://_shot_map.gd -- <W> <H> <mode> <out.png>
## modes: chase (the real follow camera over the grid), top, gantry

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1]); var mode := String(a[2]); var out := String(a[3])
	root.size = Vector2i(w, h)
	var main: Node3D = (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 120:
		await physics_frame
	var car: Node3D = main.vehicle
	# v0.2-b2: "ramp" and "bridge" place the car on the overpass approach / crest so the
	# elevation and the drawn barriers can be inspected in a still. This has to happen *before*
	# the rig is switched off, otherwise the still is taken from wherever the camera happened to
	# be (the first cut of this tool produced a view of the underside of the deck).
	if mode == "ramp" or mode == "bridge" or mode == "corner":
		var lane: Array = main.track._lane
		var idx := 566 if mode == "ramp" else (584 if mode == "bridge" else 200)
		var lp: Dictionary = lane[idx]
		var tf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(lp["yaw"]))),
			Vector3(float(lp["x"]), float(lp["y"]) + 0.1, float(lp["z"])))
		car.reset_vehicle(tf)
		for i in 3:
			await physics_frame
		if main.get("camera_rig") != null:
			main.camera_rig.snap_immediately()
		for i in 3:
			await process_frame
	if main.get("camera_rig") != null:
		main.camera_rig.process_mode = Node.PROCESS_MODE_DISABLED
		main.camera_rig.set_process(false)
		main.camera_rig.set_physics_process(false)
	if main.get("hud") != null:
		main.hud.visible = false
	if mode == "corner":
		# keep the real chase camera, parked on a corner apex so the kerb and the paint agree
		pass
	elif mode == "ramp" or mode == "bridge":
		# external viewpoint: the chase camera sits 5 m behind the car at deck height, which on
		# the ramp means it fills the frame with tarmac and no car. A fixed three-quarter view
		# shows the ramp, the drawn barrier and the elevation in one still.
		var lane2: Array = main.track._lane
		var lp2: Dictionary = lane2[566 if mode == "ramp" else 584]
		var c := Vector3(float(lp2["x"]), float(lp2["y"]), float(lp2["z"]))
		var cam_e := Camera3D.new()
		# add_child() first: look_at() on a node that is not in the tree is a no-op and silently
		# leaves the camera facing -Z (that is what framed the empty desert in the first cut).
		main.add_child(cam_e)
		var fwd := Vector3(sin(deg_to_rad(float(lp2["yaw"]))), 0.0, cos(deg_to_rad(float(lp2["yaw"]))))
		var right := Vector3(fwd.z, 0.0, -fwd.x)
		# behind-left, 10 m up: the ramp, the deck and the drawn barrier all in frame
		cam_e.position = c - fwd * 26.0 - right * 20.0 + Vector3(0.0, 11.0, 0.0)
		cam_e.look_at(c + fwd * 6.0)
		cam_e.fov = 55.0
		cam_e.far = 900.0
		cam_e.make_current()
	elif mode == "top":
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 430.0
		cam.position = Vector3(15, 260, -45)
		cam.rotation_degrees = Vector3(-90, 0, 0)
		cam.far = 800.0
		main.add_child(cam)
		cam.make_current()
	elif mode == "hero":
		var cam3 := Camera3D.new()
		cam3.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam3.size = 250.0
		cam3.position = Vector3(75, 175, 75)
		cam3.look_at(Vector3(5, 0, -48))
		cam3.far = 900.0
		main.add_child(cam3)
		cam3.make_current()
	elif mode == "gantry":
		var cam2 := Camera3D.new()
		cam2.position = Vector3(14, 6.5, 26)
		cam2.look_at(Vector3(0, 2.2, 2))
		cam2.fov = 62
		main.add_child(cam2)
		cam2.make_current()
	for i in 30:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("SHOT ", out, " ", img.get_width(), "x", img.get_height(), " car=", car.global_position)
	quit()
