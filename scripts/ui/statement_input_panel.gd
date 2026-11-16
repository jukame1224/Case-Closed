class_name StatementInputPanel
extends Control

signal input_submitted(text: String)

@onready var _input_field: TextEdit = %InputField
@onready var _status_label: Label = %StatusLabel
@onready var _char_count_label: Label = %CharCountLabel

const _MAX_INPUT_LENGTH := 40

var _session_controller: SessionController

var _had_recent_failure: bool = false

func _ready() -> void:
	_input_field.gui_input.connect(_on_input_field_gui_input)
	_input_field.text_changed.connect(_on_input_field_text_changed)

func bind(session_controller: SessionController) -> void:
	_session_controller = session_controller
	_session_controller.phase_changed.connect(_on_phase_changed)
	_session_controller.llm_request_failed.connect(_on_llm_request_failed)
	_had_recent_failure = false
	_update_for_phase(_session_controller.current_phase)

func _on_phase_changed(phase: GameManager.GamePhase) -> void:
	_update_for_phase(phase)

func _update_for_phase(phase: GameManager.GamePhase) -> void:
	match phase:
		GameManager.GamePhase.ACTIVE:
			_set_enabled(true)
			if not _had_recent_failure:
				_status_label.text = ""
			_had_recent_failure = false
		GameManager.GamePhase.LLM_WAITING:
			_set_enabled(false)
			_status_label.text = "용의자의 반응을 기다리는 중..."
		_:
			_set_enabled(false)
			_status_label.text = ""

func _on_llm_request_failed(error_message: String) -> void:
	_had_recent_failure = true
	_status_label.text = "오류: %s (다시 시도해주세요)" % error_message

func _on_input_field_gui_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.shift_pressed:
		return
	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		_input_field.accept_event()
		_on_submit_pressed()

func _on_input_field_text_changed() -> void:
	if _input_field.text.length() > _MAX_INPUT_LENGTH:
		var caret_line := _input_field.get_caret_line()
		var caret_column := _input_field.get_caret_column()
		_input_field.text = _input_field.text.substr(0, _MAX_INPUT_LENGTH)
		_input_field.set_caret_line(mini(caret_line, _input_field.get_line_count() - 1))
		_input_field.set_caret_column(mini(caret_column, _input_field.text.length()))
	_char_count_label.text = "%d/%d" % [_input_field.text.length(), _MAX_INPUT_LENGTH]

func _on_submit_pressed() -> void:
	if _session_controller == null:
		return
	var player_input := _input_field.text.strip_edges()
	if player_input.is_empty():
		return
	_input_field.text = ""
	_char_count_label.text = "%d/%d" % [0, _MAX_INPUT_LENGTH]
	_status_label.text = ""
	input_submitted.emit(player_input)
	_session_controller.submit_player_input(player_input)

func _set_enabled(enabled: bool) -> void:
	_input_field.editable = enabled
