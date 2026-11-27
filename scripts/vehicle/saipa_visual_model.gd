class_name SaipaVisualModel
extends Node3D

## Manages the visual 3D body hierarchy of the Sport Pride (Kilometer 2),
## including shadow-caster pruning on enclosed interior/engine meshes, distance HLOD culling,
## tunable PBR paint/trim colors, toggleable twin SpotLight3D headlights, and live cockpit needles.

const EXTERIOR_SHADOW_MESHES: Array[String] = [
	"chassis",
	"body",
	"bodyshell",
	"badane",
	"bonnet",
	"bonnet_ok",
	"boot",
	"boot_ok",
	"bump_front_ok",
	"bump_font_ok",
	"bump_rear_ok",
	"bump_rear",
	"bumper_f_ok",
	"bumper_r_ok",
	"front_bump_ok",
	"rear_bump_ok",
	"e",
	"door_lf_ok",
	"door_rf_ok",
	"door_lr_ok",
	"door_rr_ok",
	"door_lf",
	"door_rf",
	"door_lr",
	"door_rr",
]

const TINY_DETAIL_MESHES: Array[String] = [
	"speedook",
	"tahook",
	"temperature",
	"radio",
	"jp",
	"f_gas_ax=-7",
	"f_brake_ax=-15",
	"dvorleft",
	"dvorright",
	"engine1",
	"motor",
	"rngom",
	"f_fan",
	"f_fan_001",
	"f_shake",
	"jjjek",
	"jjkekeeekk",
	"zir",
	"kaf",
	"extra",
]

@export var headlight_pos_fl: Vector3 = Vector3(0.56, 0.62, 2.24)

@export var body_paint_color: Color = Color(0.95, 0.95, 0.96, 1.0):
	set(value):
		body_paint_color = value
		if is_inside_tree():
			_apply_material_tuning()

@export var secondary_trim_color: Color = Color(0.95, 0.95, 0.96, 1.0):
	set(value):
		secondary_trim_color = value
		if is_inside_tree():
			_apply_material_tuning()

@export_range(0.0, 1.0, 0.01) var paint_roughness: float = 0.20
@export_range(0.0, 1.0, 0.01) var paint_metallic: float = 0.25
@export_range(0.15, 0.90, 0.01) var window_glass_opacity: float = 0.56
@export var headlights_enabled: bool = false:
	set(value):
		headlights_enabled = value
		_update_headlights()

var _steering_wheel_node: Node3D = null
var _steering_base_basis: Basis = Basis.IDENTITY
var _speedo_needle_node: Node3D = null
var _speedo_base_basis: Basis = Basis.IDENTITY
var _tacho_needle_node: Node3D = null
var _tacho_base_basis: Basis = Basis.IDENTITY

var _paint_primary_materials: Array[StandardMaterial3D] = []
var _paint_bumper_materials: Array[StandardMaterial3D] = []
var _trim_materials: Array[StandardMaterial3D] = []
var _window_glass_materials: Array[StandardMaterial3D] = []
var _taillight_materials: Array[StandardMaterial3D] = []
var _headlamp_materials: Array[StandardMaterial3D] = []

var _headlight_spot_l: SpotLight3D = null
var _headlight_spot_r: SpotLight3D = null
var _detail_meshes: Array[MeshInstance3D] = []
var _exterior_shadow_meshes: Array[MeshInstance3D] = []
var _batched_exterior_mi: MeshInstance3D = null
var _batched_interior_mi: MeshInstance3D = null
var _batched_tiny_mi: MeshInstance3D = null
var _is_batched: bool = false


func _ready() -> void:
	_cache_articulated_nodes()
	_prepare_unique_materials_and_lod()
	_setup_headlight_rig()
	_apply_material_tuning()
	_update_headlights()


func _cache_articulated_nodes() -> void:
	_steering_wheel_node = _find_node_contains("f_steer")
	if _steering_wheel_node == null:
		_steering_wheel_node = _find_node_contains("movsteer")
	if _steering_wheel_node != null:
		_steering_base_basis = _steering_wheel_node.transform.basis

	_speedo_needle_node = _find_node_exact("speedook")
	if _speedo_needle_node != null:
		_speedo_base_basis = _speedo_needle_node.transform.basis

	_tacho_needle_node = _find_node_exact("tahook")
	if _tacho_needle_node != null:
		_tacho_base_basis = _tacho_needle_node.transform.basis


func _find_node_exact(target_name: String) -> Node3D:
	var found := find_child(target_name, true, false)
	return found as Node3D


func _find_node_contains(substr: String) -> Node3D:
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Node3D and current.name.to_lower().contains(substr.to_lower()):
			return current as Node3D
		for child in current.get_children():
			stack.append(child)
	return null


func _prepare_unique_materials_and_lod() -> void:
	_paint_primary_materials.clear()
	_paint_bumper_materials.clear()
	_trim_materials.clear()
	_window_glass_materials.clear()
	_taillight_materials.clear()
	_headlamp_materials.clear()
	_detail_meshes.clear()
	_exterior_shadow_meshes.clear()

	var meshes := _collect_meshes(self)
	var seen_map: Dictionary = {}

	for mi: MeshInstance3D in meshes:
		var lower_name := mi.name.to_lower()
		# 1. Shadow Caster Pruning: only outer opaque body panels cast directional shadows!
		if EXTERIOR_SHADOW_MESHES.has(lower_name):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			_exterior_shadow_meshes.append(mi)
		else:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# 2. Distance HLOD Culling for tiny enclosed cockpit/engine sub-meshes
		if TINY_DETAIL_MESHES.has(lower_name):
			mi.visibility_range_end = 22.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			_detail_meshes.append(mi)

		if mi.mesh == null:
			continue
		var surf_count := mi.mesh.get_surface_count()
		for s_idx in range(surf_count):
			var mat: Material = mi.get_active_material(s_idx)
			if not (mat is BaseMaterial3D):
				continue
			var orig_name := mat.resource_name
			var dup_mat: StandardMaterial3D
			if seen_map.has(mat):
				dup_mat = seen_map[mat]
			else:
				dup_mat = (mat.duplicate() as StandardMaterial3D)
				if dup_mat == null:
					continue
				dup_mat.resource_name = orig_name
				seen_map[mat] = dup_mat
				_classify_and_polish_material(dup_mat)
			mi.set_surface_override_material(s_idx, dup_mat)


func set_vehicle_lod_tier(tier: int) -> void:
	var lod_dist := 12.0 if tier == 0 else (22.0 if tier == 1 else 45.0)
	var cast_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if tier == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if _is_batched:
		if _batched_tiny_mi != null:
			_batched_tiny_mi.visibility_range_end = lod_dist
		if _batched_exterior_mi != null:
			_batched_exterior_mi.cast_shadow = cast_mode
	else:
		for dm in _detail_meshes:
			if dm != null:
				dm.visibility_range_end = lod_dist
		for em in _exterior_shadow_meshes:
			if em != null:
				em.cast_shadow = cast_mode


func _is_articulated_mesh(mi: MeshInstance3D) -> bool:
	var cur: Node = mi
	while cur != null and cur != self:
		if cur == _steering_wheel_node or cur == _speedo_needle_node or cur == _tacho_needle_node:
			return true
		cur = cur.get_parent()
	return false


func _get_transform_relative_to_self(node: Node3D) -> Transform3D:
	var tf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != self:
		if cur is Node3D:
			tf = (cur as Node3D).transform * tf
		cur = cur.get_parent()
	return tf


## Merges non-articulated static sub-meshes by shared StandardMaterial3D into 3 batched ArrayMeshes
## (Exterior Shadow Shell, Main Interior/Glass, Tiny HLOD Details), slashing per-frame draw calls
## while preserving articulated cockpit needles/steering wheel and all live material overrides.
func enable_runtime_static_batching() -> void:
	if _is_batched:
		return
	var ext_buckets: Dictionary = {}
	var int_buckets: Dictionary = {}
	var tiny_buckets: Dictionary = {}

	var meshes := _collect_meshes(self)
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null or _is_articulated_mesh(mi):
			continue
		var lower_name := mi.name.to_lower()
		var rel_tf := _get_transform_relative_to_self(mi)
		var is_tiny := TINY_DETAIL_MESHES.has(lower_name)
		var is_ext := EXTERIOR_SHADOW_MESHES.has(lower_name)

		for s_idx in range(mi.mesh.get_surface_count()):
			var mat := mi.get_active_material(s_idx)
			var is_transparent := (mat is BaseMaterial3D) and ((mat as BaseMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_ALPHA)
			var target_dict: Dictionary = tiny_buckets if is_tiny else (ext_buckets if (is_ext and not is_transparent) else int_buckets)
			if not target_dict.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				target_dict[mat] = st
			var st_ref: SurfaceTool = target_dict[mat]
			st_ref.append_from(mi.mesh, s_idx, rel_tf)

		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false

	_batched_exterior_mi = _commit_bucket_mesh("BatchedExteriorShell", ext_buckets, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, 0.0)
	_batched_interior_mi = _commit_bucket_mesh("BatchedInteriorAndGlass", int_buckets, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, 0.0)
	_batched_tiny_mi = _commit_bucket_mesh("BatchedTinyDetails", tiny_buckets, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, 22.0)
	_is_batched = true


func _commit_bucket_mesh(node_name: String, buckets: Dictionary, shadow_mode: GeometryInstance3D.ShadowCastingSetting, vis_end: float) -> MeshInstance3D:
	if buckets.is_empty():
		return null
	var arr_mesh := ArrayMesh.new()
	var mats_ordered: Array[Material] = []
	# Append opaque surfaces first, alpha-blended glass surfaces last for clean sorting
	for pass_alpha in [false, true]:
		for mat_key in buckets.keys():
			var is_alpha := (mat_key is BaseMaterial3D) and ((mat_key as BaseMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_ALPHA)
			if is_alpha != pass_alpha:
				continue
			var st: SurfaceTool = buckets[mat_key]
			st.commit(arr_mesh)
			mats_ordered.append(mat_key as Material)

	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = arr_mesh
	mi.cast_shadow = shadow_mode
	if vis_end > 0.0:
		mi.visibility_range_end = vis_end
	for i in range(mats_ordered.size()):
		mi.set_surface_override_material(i, mats_ordered[i])
	add_child(mi)
	return mi


func _setup_headlight_rig() -> void:
	# Lightweight mobile SpotLight3D beams (shadow_enabled = false -> zero shadow-map cost)
	# SpotLight3D shines along local -Z, so Y=180 deg points forward along +Z (MODEL_FRONT) with 7 deg downward dip.
	_headlight_spot_l = SpotLight3D.new()
	_headlight_spot_l.name = "HeadlightSpotFL"
	_headlight_spot_l.position = Vector3(absf(headlight_pos_fl.x), headlight_pos_fl.y, headlight_pos_fl.z)
	_headlight_spot_l.rotation_degrees = Vector3(-7.0, 180.0, 0.0)
	_headlight_spot_l.light_color = Color(0.94, 0.97, 1.0)
	_headlight_spot_l.light_energy = 3.4
	_headlight_spot_l.spot_range = 44.0
	_headlight_spot_l.spot_angle = 30.0
	_headlight_spot_l.shadow_enabled = false
	add_child(_headlight_spot_l)

	_headlight_spot_r = SpotLight3D.new()
	_headlight_spot_r.name = "HeadlightSpotFR"
	_headlight_spot_r.position = Vector3(-absf(headlight_pos_fl.x), headlight_pos_fl.y, headlight_pos_fl.z)
	_headlight_spot_r.rotation_degrees = Vector3(-7.0, 180.0, 0.0)
	_headlight_spot_r.light_color = Color(0.94, 0.97, 1.0)
	_headlight_spot_r.light_energy = 3.4
	_headlight_spot_r.spot_range = 44.0
	_headlight_spot_r.spot_angle = 30.0
	_headlight_spot_r.shadow_enabled = false
	add_child(_headlight_spot_r)


func _update_headlights() -> void:
	if _headlight_spot_l != null:
		_headlight_spot_l.visible = headlights_enabled
	if _headlight_spot_r != null:
		_headlight_spot_r.visible = headlights_enabled
	for hm in _headlamp_materials:
		hm.emission_enabled = headlights_enabled
		hm.emission = Color(0.92, 0.96, 1.0)
		hm.emission_energy_multiplier = 1.15 if headlights_enabled else 0.0


func _classify_and_polish_material(mat: StandardMaterial3D) -> void:
	var mname := mat.resource_name.to_lower()

	if mname == "paint_primary" or mname == "primary" or mname.begins_with("primary."):
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_paint_primary_materials.append(mat)
	elif mname == "paint_primary_bumper":
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_paint_bumper_materials.append(mat)
	elif mname == "paint_secondary":
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_trim_materials.append(mat)
	elif mname == "glass_000000_a181":
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.03
		mat.metallic = 0.08
		mat.metallic_specular = 0.90
		_window_glass_materials.append(mat)
	elif mname == "glass" or mname.begins_with("glass.") or mname == "clear_light_glass":
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.metallic_specular = 0.88
	elif mname.begins_with("glass_") or mname.begins_with("lamp_"):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.metallic_specular = 0.88
		if mname.contains("taillamp"):
			mat.emission_enabled = true
			mat.emission = Color(0.85, 0.05, 0.04)
			mat.emission_energy_multiplier = 0.18
			_taillight_materials.append(mat)
		elif mname.contains("headlamp"):
			_headlamp_materials.append(mat)
	elif mname == "tex_vehiclelights" or mname.contains("rear light") or mname.contains("breaklight") or mname == "3d-lights.5" or mname == "boot.2":
		mat.emission_enabled = true
		mat.emission = Color(0.90, 0.08, 0.05)
		mat.emission_energy_multiplier = 0.20
		_taillight_materials.append(mat)
	elif mname == "tex_lights" or mname.contains("front light") or mname.contains("foglight"):
		_headlamp_materials.append(mat)
	elif mname == "tex_imperza_sticker":
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.20
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func _apply_material_tuning() -> void:
	for pmat in _paint_primary_materials:
		pmat.albedo_color = body_paint_color
		pmat.metallic = paint_metallic
		pmat.roughness = paint_roughness
		pmat.metallic_specular = 0.78
	for bmat in _paint_bumper_materials:
		bmat.albedo_color = body_paint_color
		bmat.metallic = maxf(0.10, paint_metallic - 0.10)
		bmat.roughness = minf(1.0, paint_roughness + 0.08)
		bmat.metallic_specular = 0.72
	for tmat in _trim_materials:
		tmat.albedo_color = secondary_trim_color
		tmat.metallic = 0.25
		tmat.roughness = 0.20
		tmat.metallic_specular = 0.75
	for gmat in _window_glass_materials:
		gmat.albedo_color = Color(0.04, 0.045, 0.055, window_glass_opacity)


var _last_brake_energy: float = -1.0


func update_cockpit_Telemetry(steer_ratio: float, speed_kmh: float, rpm_norm: float, braking: bool) -> void:
	if _steering_wheel_node != null:
		var steer_visual_rad := clampf(steer_ratio, -1.0, 1.0) * deg_to_rad(320.0)
		_steering_wheel_node.transform.basis = _steering_base_basis * Basis(Vector3(0, 0, 1), -steer_visual_rad)

	if _speedo_needle_node != null:
		var spd_ratio := clampf(absf(speed_kmh) / 180.0, 0.0, 1.0)
		var spd_angle := deg_to_rad(spd_ratio * 220.0)
		_speedo_needle_node.transform.basis = _speedo_base_basis * Basis(Vector3(0, 0, 1), -spd_angle)

	if _tacho_needle_node != null:
		var rpm_clamped := clampf(rpm_norm, 0.0, 1.0)
		var rpm_angle := deg_to_rad(rpm_clamped * 210.0)
		_tacho_needle_node.transform.basis = _tacho_base_basis * Basis(Vector3(0, 0, 1), -rpm_angle)

	var rest_glow := 0.42 if headlights_enabled else 0.18
	var brake_energy := 1.55 if braking else rest_glow
	if not is_equal_approx(brake_energy, _last_brake_energy):
		_last_brake_energy = brake_energy
		for tl in _taillight_materials:
			tl.emission_energy_multiplier = brake_energy


func _collect_meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			result.append(n as MeshInstance3D)
		for ch in n.get_children():
			stack.append(ch)
	return result
