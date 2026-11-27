class_name AssetIntegrationPreview
extends Node3D

## Dedicated Studio Asset Integration Preview Scene (Phase 5).
## Displays the baseline Sport Pride alongside all 5 newly integrated Source A vehicles
## on calibrated 5.2m × 2.4m metric plinths with clean 3-point lighting, neutral ground,
## 3D labels, and deterministic multi-angle camera framing (without altering main_scene).

const STUDIO_SLOTS: Array[Dictionary] = [
	{"catalog_idx": 1, "pos": Vector3(-5.2, 0.0, 2.4), "yaw_deg": -26.0, "tag": "[VEH_01] IKCO Tara — ایران‌خودرو تارا\n4.93×2.05×1.59m | R=0.336m | 96.3k tris"},
	{"catalog_idx": 2, "pos": Vector3(0.0, 0.0, 2.8), "yaw_deg": -18.0, "tag": "[VEH_02] Renault Megan — رنو مگان\n4.66×2.05×1.71m | R=0.321m | 152.3k tris"},
	{"catalog_idx": 3, "pos": Vector3(5.2, 0.0, 2.4), "yaw_deg": 24.0, "tag": "[VEH_03] Saipa Pride 132 — پراید ۱۳۲\n4.42×2.10×1.59m | R=0.330m | 169.2k tris"},
	{"catalog_idx": 4, "pos": Vector3(-5.0, 0.0, -3.2), "yaw_deg": -28.0, "tag": "[VEH_04] Saipa Quick — سایپا کوییک\n4.54×2.20×1.69m | R=0.317m | 60.5k tris"},
	{"catalog_idx": 5, "pos": Vector3(0.0, 0.0, -3.0), "yaw_deg": -18.0, "tag": "[VEH_05] IKCO Samand EF7 — سمند EF7\n4.53×2.06×1.40m | R=0.293m | 92.5k tris"},
	{"catalog_idx": 0, "pos": Vector3(5.0, 0.0, -3.2), "yaw_deg": 24.0, "tag": "[BASE] Sport Pride — پراید اسپرت (مرجع)\n4.44×1.95×1.45m | R=0.303m | Baseline"},
]

@onready var preview_camera: Camera3D = $PreviewCamera3D
@onready var vehicles_root: Node3D = $ShowcaseVehicles
@onready var header_label: Label = $OverlayHud/BannerPanel/BannerMargin/BannerVBox/TitleLabel
@onready var sub_label: Label = $OverlayHud/BannerPanel/BannerMargin/BannerVBox/SubtitleLabel

var spawned_showcases: Array[Node3D] = []
var active_preset: int = 0


func _ready() -> void:
	_build_studio_plinths_and_vehicles()
	set_camera_preset(0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_0 and k <= KEY_6:
			set_camera_preset(int(k - KEY_0))


func _build_studio_plinths_and_vehicles() -> void:
	spawned_showcases.clear()
	var font_bold := load("res://assets/fonts/Estedad-Bold.ttf") as FontFile

	var plinth_mat := StandardMaterial3D.new()
	plinth_mat.albedo_color = Color(0.16, 0.19, 0.24, 1.0)
	plinth_mat.roughness = 0.65
	plinth_mat.metallic = 0.12

	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.24, 0.62, 0.96, 1.0)
	rim_mat.emission_enabled = true
	rim_mat.emission = Color(0.18, 0.50, 0.88, 1.0)
	rim_mat.emission_energy_multiplier = 0.45

	for slot in STUDIO_SLOTS:
		var cat_idx := int(slot["catalog_idx"])
		var entry := VehicleCatalog.get_entry(cat_idx)
		var slot_pos: Vector3 = slot["pos"]
		var yaw_deg := float(slot["yaw_deg"])

		var holder := Node3D.new()
		holder.name = "Slot_" + str(entry["id"])
		holder.position = slot_pos
		vehicles_root.add_child(holder)

		# Metric calibration plinth (2.50m wide x 5.20m long x 0.04m high)
		var plinth := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(2.50, 0.04, 5.20)
		plinth.mesh = p_box
		plinth.position = Vector3(0.0, -0.02, 0.0)
		plinth.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
		plinth.material_override = plinth_mat
		holder.add_child(plinth)

		var accent := MeshInstance3D.new()
		var a_box := BoxMesh.new()
		a_box.size = Vector3(2.56, 0.015, 5.26)
		accent.mesh = a_box
		accent.position = Vector3(0.0, -0.035, 0.0)
		accent.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
		accent.material_override = rim_mat
		holder.add_child(accent)

		var packed := load(str(entry["showcase_scene"])) as PackedScene
		if packed != null:
			var car_node := packed.instantiate() as Node3D
			car_node.name = "ShowcaseModel"
			car_node.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
			holder.add_child(car_node)
			spawned_showcases.append(car_node)

			# Apply distinct showroom paint on monochrome white models so body lines pop under studio lighting
			for ch in car_node.get_children():
				if ch is SaipaVisualModel:
					var vm := ch as SaipaVisualModel
					vm.body_paint_color = entry["default_paint"]
					vm.headlights_enabled = true

		var lbl := Label3D.new()
		lbl.name = "SpecLabel3D"
		lbl.position = Vector3(0.0, 2.08, 0.0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = false
		lbl.pixel_size = 0.0038
		lbl.font = font_bold
		lbl.font_size = 38
		lbl.outline_size = 10
		lbl.modulate = Color(0.95, 0.98, 1.0, 1.0)
		lbl.outline_modulate = Color(0.04, 0.07, 0.12, 0.96)
		lbl.text = str(slot["tag"])
		holder.add_child(lbl)


func set_camera_preset(preset_idx: int) -> void:
	active_preset = clampi(preset_idx, 0, STUDIO_SLOTS.size())
	if preview_camera == null:
		return
	var holders := vehicles_root.get_children()
	for i in range(holders.size()):
		if holders[i] is Node3D:
			var h := holders[i] as Node3D
			h.visible = (active_preset == 0 or i == active_preset - 1)
			var lbl := h.get_node_or_null("SpecLabel3D") as Label3D
			if lbl != null:
				lbl.visible = (active_preset == 0)
	preview_camera.make_current()
	if active_preset == 0:
		preview_camera.fov = 46.0
		preview_camera.look_at_from_position(Vector3(0.0, 5.85, 11.8), Vector3(0.0, 0.72, -0.35), Vector3.UP)
		if header_label != null:
			header_label.text = "SAIPA BETA 3 — INTEGRATED 6-VEHICLE STUDIO PREVIEW (GODOT 4.7.2)"
		if sub_label != null:
			sub_label.text = "5 Integrated Source A Vehicles (Tara, Megan, Pride 132, Quick, Samand EF7) + Baseline Sport Pride | Keys [0-6] Camera Presets"
	else:
		var slot := STUDIO_SLOTS[active_preset - 1]
		var cat_idx := int(slot["catalog_idx"])
		var entry := VehicleCatalog.get_entry(cat_idx)
		var base_pos: Vector3 = slot["pos"]
		var yaw_rad := deg_to_rad(float(slot["yaw_deg"]))
		var fwd := Vector3(sin(yaw_rad), 0.0, cos(yaw_rad)).normalized()
		var right_v := Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad)).normalized()
		var cam_pos := base_pos + fwd * 3.85 + right_v * 2.65 + Vector3(0.0, 1.48, 0.0)
		preview_camera.fov = 42.0
		preview_camera.look_at_from_position(cam_pos, base_pos + Vector3(0.0, 0.68, 0.0), Vector3.UP)
		if header_label != null:
			header_label.text = "ASSET DETAIL PREVIEW — %s (%s)" % [str(entry["name_en"]), str(entry["name_fa"])]
		if sub_label != null:
			sub_label.text = "Scene: %s | Mass: %.0f kg | Wheel Radius: %.3f m | Wheelbase: %.2f m" % [
				str(entry["vehicle_scene"]),
				float(entry["mass_kg"]),
				float(entry["wheel_radius_m"]),
				float(entry["wheelbase_m"]),
			]
