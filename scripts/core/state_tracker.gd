class_name StateTracker
extends RefCounted

const GUARD_INFO_BLOCK := 80.0
const GUARD_DANGER_ZONE := 10.0

var guard_level: float
var rapport_level: float
var ego_level: float
var collapse_level: float = 0.0

func initialize(init_guard: float, init_rapport: float, init_ego: float) -> void:
	guard_level = init_guard
	rapport_level = init_rapport
	ego_level = init_ego
	collapse_level = 0.0

func apply_guard_delta(delta: float) -> void:
	guard_level = clampf(guard_level + delta, 0.0, 100.0)

func apply_rapport_delta(delta: float) -> void:
	rapport_level = clampf(rapport_level + delta, 0.0, 100.0)

func apply_ego_delta(delta: float) -> void:
	ego_level = clampf(ego_level + delta, 0.0, 100.0)

func apply_collapse_delta(delta: float) -> void:
	collapse_level = clampf(collapse_level + delta, 0.0, 100.0)
