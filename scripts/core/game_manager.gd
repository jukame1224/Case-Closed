class_name GameManager
extends Node

enum GamePhase {
	ACTIVE,
	LLM_WAITING,
	CONFESSION,
	SESSION_FAILED,
}

const MAX_STAGE := 9

signal game_ended(is_success: bool)
signal stage_started(stage: int)
signal game_cleared

var session_controller: SessionController
var current_stage: int = 1

func start_game() -> void:
	current_stage = 1
	_start_stage(current_stage)

func continue_saved_game() -> void:
	current_stage = SaveManager.load_progress()
	_start_stage(current_stage)

func continue_to_next_stage() -> void:
	_start_stage(current_stage)

func _start_stage(stage: int) -> void:
	if session_controller != null:
		session_controller.queue_free()

	var suspect_type := (stage - 1) as SuspectConfig.SuspectType
	session_controller = SessionController.new()
	add_child(session_controller)
	session_controller.session_ended.connect(_on_session_ended)
	session_controller.start_session(suspect_type)
	stage_started.emit(stage)

func _on_session_ended(is_success: bool) -> void:
	if is_success:
		if current_stage >= MAX_STAGE:
			SaveManager.clear_save()
			game_cleared.emit()
			return
		current_stage += 1
		SaveManager.save_progress(current_stage)
	game_ended.emit(is_success)
