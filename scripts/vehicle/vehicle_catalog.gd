class_name VehicleCatalog
extends RefCounted

## Central registry of all 6 playable & showcase vehicles in Kilometer 2:
## v0.1-b3: "top_speed_kmh" / "engine_force_n" mirror the physics values in
## each *_vehicle.tscn (max_forward_speed_kmh / max_engine_force_n, or the
## controller defaults 165 km/h / 2650 N) so the showroom can show honest
## specs without loading the physics scenes; tests/test_ui_v3_design_system.gd
## fails if the two ever drift apart.
## - Index 0: Original baseline Sport Pride (preserved untouched as default startup car)
## - Indices 1..5: Integrated 5-car pack from Source A (carpack final):
##   IKCO Tara, Renault Megan, Saipa Pride 132, Saipa Quick, and IKCO Samand EF7.

const ENTRIES: Array[Dictionary] = [
	{
		"id": "sport_pride",
		"name_en": "Sport Pride (Tuned)",
		"name_fa": "پراید اسپرت",
		"short_fa": "پراید اسپرت",
		"vehicle_scene": "res://scenes/vehicle/saipa_pride_vehicle.tscn",
		"showcase_scene": "res://scenes/vehicle/saipa_pride_showcase.tscn",
		"visual_scene": "res://scenes/vehicle/saipa_pride_visual.tscn",
		"mass_kg": 950.0,
		"wheel_radius_m": 0.3032,
		"wheelbase_m": 2.6693,
		"top_speed_kmh": 165.0,
		"engine_force_n": 2650.0,
		"default_paint": Color(0.95, 0.95, 0.96, 1.0),
	},
	{
		"id": "veh_01_ikco_tara",
		"name_en": "IKCO Tara",
		"name_fa": "ایران‌خودرو تارا",
		"short_fa": "تارا",
		"vehicle_scene": "res://scenes/vehicle/veh_01_ikco_tara_vehicle.tscn",
		"showcase_scene": "res://scenes/vehicle/veh_01_ikco_tara_showcase.tscn",
		"visual_scene": "res://scenes/vehicle/veh_01_ikco_tara_visual.tscn",
		"mass_kg": 1220.0,
		"wheel_radius_m": 0.3364,
		"wheelbase_m": 2.9031,
		"top_speed_kmh": 190.0,
		"engine_force_n": 3350.0,
		"default_paint": Color(0.95, 0.95, 0.97, 1.0),
	},
	{
		"id": "veh_02_megan",
		"name_en": "Renault Megan",
		"name_fa": "رنو مگان",
		"short_fa": "مگان",
		"vehicle_scene": "res://scenes/vehicle/veh_02_megan_vehicle.tscn",
		"showcase_scene": "res://scenes/vehicle/veh_02_megan_showcase.tscn",
		"visual_scene": "res://scenes/vehicle/veh_02_megan_visual.tscn",
		"mass_kg": 1315.0,
		"wheel_radius_m": 0.3213,
		"wheelbase_m": 2.7736,
		"top_speed_kmh": 195.0,
		"engine_force_n": 3650.0,
		"default_paint": Color(0.76, 0.79, 0.84, 1.0),
	},
	{
		"id": "veh_03_pride_132",
		"name_en": "Saipa Pride 132",
		"name_fa": "سایپا پراید ۱۳۲",
		"short_fa": "پراید ۱۳۲",
		"vehicle_scene": "res://scenes/vehicle/veh_03_pride_132_vehicle.tscn",
		"showcase_scene": "res://scenes/vehicle/veh_03_pride_132_showcase.tscn",
		"visual_scene": "res://scenes/vehicle/veh_03_pride_132_visual.tscn",
		"mass_kg": 935.0,
		"wheel_radius_m": 0.3303,
		"wheelbase_m": 2.6439,
		"top_speed_kmh": 160.0,
		"engine_force_n": 2550.0,
		"default_paint": Color(0.96, 0.96, 0.96, 1.0),
	},
	{
		"id": "veh_04_quick",
		"name_en": "Saipa Quick",
		"name_fa": "سایپا کوییک",
		"short_fa": "کوییک",
		"vehicle_scene": "res://scenes/vehicle/veh_04_quick_vehicle.tscn",
		"showcase_scene": "res://scenes/vehicle/veh_04_quick_showcase.tscn",
		"visual_scene": "res://scenes/vehicle/veh_04_quick_visual.tscn",
		"mass_kg": 1065.0,
		"wheel_radius_m": 0.3173,
		"wheelbase_m": 2.7849,
		"top_speed_kmh": 170.0,
		"engine_force_n": 2880.0,
		"default_paint": Color(0.84, 0.14, 0.16, 1.0),
	},
	{
		"id": "veh_05_samand_ef7",
		"name_en": "IKCO Samand EF7",
		"name_fa": "سمند EF7",
		"short_fa": "سمند EF7",
		"vehicle_scene": "res://scenes/vehicle/veh_05_samand_ef7_vehicle.tscn",
		"showcase_scene": "res://scenes/vehicle/veh_05_samand_ef7_showcase.tscn",
		"visual_scene": "res://scenes/vehicle/veh_05_samand_ef7_visual.tscn",
		"mass_kg": 1240.0,
		"wheel_radius_m": 0.2931,
		"wheelbase_m": 2.6703,
		"top_speed_kmh": 188.0,
		"engine_force_n": 3450.0,
		"default_paint": Color(0.95, 0.95, 0.96, 1.0),
	},
]


static func get_count() -> int:
	return ENTRIES.size()


static func get_entry(index: int) -> Dictionary:
	var clamped := posmod(index, ENTRIES.size())
	return ENTRIES[clamped]


static func find_index_by_id(vehicle_id: String) -> int:
	for i in range(ENTRIES.size()):
		if str(ENTRIES[i]["id"]) == vehicle_id:
			return i
	return 0
