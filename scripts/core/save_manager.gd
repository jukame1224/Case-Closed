class_name SaveManager
extends RefCounted

const _SAVE_PATH := "user://savegame.cfg"
const _SECTION := "progress"
const _KEY_STAGE := "current_stage"

static func has_save() -> bool:
	return FileAccess.file_exists(_SAVE_PATH)

static func save_progress(stage: int) -> void:
	var config := ConfigFile.new()
	config.set_value(_SECTION, _KEY_STAGE, stage)
	config.save(_SAVE_PATH)

static func load_progress() -> int:
	var config := ConfigFile.new()
	if config.load(_SAVE_PATH) != OK:
		return 1
	return config.get_value(_SECTION, _KEY_STAGE, 1)

static func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(_SAVE_PATH)
