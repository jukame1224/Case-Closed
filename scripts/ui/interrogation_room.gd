class_name InterrogationRoom
extends Control

@onready var _dialogue_log: RichTextLabel = %DialogueLog
@onready var _dialogue_log_overlay: Control = %DialogueLogOverlay
@onready var _dialogue_log_close_button: Button = %DialogueLogCloseButton
@onready var _overhead_narration_label: Label = %OverheadNarrationLabel
@onready var _guard_warning_label: Label = %GuardWarningLabel
@onready var _action_squares_container: Container = %ActionSquaresContainer
@onready var _stage_label: Label = %StageLabel
@onready var _suspect_tab_label: Label = %TabLabel
@onready var _suspect_dialogue_label: RichTextLabel = %SuspectDialogueLabel
@onready var _statement_input_panel: StatementInputPanel = %StatementInputPanel
@onready var _evidence_review: EvidenceReview = %EvidenceReview
@onready var _evidence_overlay: Control = %EvidenceOverlay
@onready var _text_popup_overlay: Control = %TextPopupOverlay
@onready var _text_popup_label: RichTextLabel = %TextPopupLabel
@onready var _suspect_portrait_texture: TextureRect = %SuspectPortraitTexture
@onready var _blip_player: AudioStreamPlayer = %BlipPlayer
@onready var _confession_continue_button: Button = %ConfessionContinueButton

@onready var _hint_icon: Button = %HintIcon
@onready var _case_file_icon: Button = %CaseFileIcon
@onready var _profile_icon: Button = %ProfileIcon
@onready var _evidence_icon: Button = %EvidenceIcon
@onready var _pen_icon: Button = %PenIcon
@onready var _memo_icon: Button = %MemoIcon
@onready var _evidence_close_button: Button = %EvidenceCloseButton
@onready var _text_popup_close_button: Button = %TextPopupCloseButton

const _ACTION_SLOT_FULL_TEXTURE: Texture2D = preload("res://assets/ui/slot_full.png")
const _ACTION_SLOT_EMPTY_TEXTURE: Texture2D = preload("res://assets/ui/slot_empty.png")
const _TYPEWRITER_SECONDS_PER_CHARACTER := 0.03
const _BLIP_CHARACTERS_PER_SOUND := 3
const _BLIP_EXCLUDED_CHARACTERS := [" ", "\n", ".", ",", "!", "?"]
const _OVERHEAD_NARRATION_HOLD_SECONDS := 3.0
const _OVERHEAD_NARRATION_FADE_SECONDS := 1.2
const _ALREADY_PRESENTED_TEXT := "이미 제시한 증거입니다."
const _NO_TURN_READING_TEXT := "아직 반응을 살필 발언이 없다."
const _DISSOCIATED_TURN_READING := "말이 전혀 닿지 않는다. 대화가 끊기고 있다."
const _GUARD_WARNING_FORMAT := "%s의 표정이 굳어 간다. 더 몰아붙이면 대화가 끝날 것 같다."

var _session_controller: SessionController
var _log_lines: Array[String] = []
var _action_squares: Array[TextureRect] = []
var _typewriter_tween: Tween
var _overhead_narration_tween: Tween
var _guard_warning_tween: Tween
var _latest_turn_reading: String = ""
var _is_suspect_dissociated: bool = false
var _emotion_controller := EmotionController.new()
var _is_typing: bool = false
var _typewriter_revealed_count: int = 0
var _blip_pending_count: int = 0
var _awaiting_confession_continue: bool = false

func _ready() -> void:
	_emotion_controller.emotion_changed.connect(_on_emotion_changed)
	_hint_icon.pressed.connect(_show_turn_reading)
	_case_file_icon.pressed.connect(_show_case_file)
	_profile_icon.pressed.connect(_show_profile_notebook)
	_evidence_icon.pressed.connect(_toggle_evidence_overlay)
	_pen_icon.pressed.connect(_toggle_statement_input_panel)
	_memo_icon.pressed.connect(_toggle_dialogue_log)
	_evidence_close_button.pressed.connect(_toggle_evidence_overlay)
	_dialogue_log_close_button.pressed.connect(_toggle_dialogue_log)
	_text_popup_close_button.pressed.connect(func(): _text_popup_overlay.visible = false)
	_confession_continue_button.pressed.connect(_on_confession_continue_button_pressed)

	for child in _action_squares_container.get_children():
		if child is TextureRect:
			_action_squares.append(child)

func bind(session_controller: SessionController) -> void:
	_session_controller = session_controller
	_log_lines.clear()

	_statement_input_panel.bind(session_controller)
	_evidence_review.bind(session_controller)
	_statement_input_panel.visible = true
	_evidence_overlay.visible = false
	_text_popup_overlay.visible = false
	_dialogue_log_overlay.visible = false
	_latest_turn_reading = ""
	_is_suspect_dissociated = false
	_hide_overhead_narration()
	_hide_guard_warning()
	_confession_continue_button.visible = false
	_awaiting_confession_continue = false

	if _statement_input_panel.input_submitted.is_connected(_on_player_input_submitted):
		_statement_input_panel.input_submitted.disconnect(_on_player_input_submitted)
	_statement_input_panel.input_submitted.connect(_on_player_input_submitted)

	if _session_controller.turn_resolved.is_connected(_on_turn_resolved):
		_session_controller.turn_resolved.disconnect(_on_turn_resolved)
	_session_controller.turn_resolved.connect(_on_turn_resolved)

	if _session_controller.actions_remaining_changed.is_connected(_update_action_squares):
		_session_controller.actions_remaining_changed.disconnect(_update_action_squares)
	_session_controller.actions_remaining_changed.connect(_update_action_squares)

	if _session_controller.evidence_reaction.is_connected(_on_evidence_reaction):
		_session_controller.evidence_reaction.disconnect(_on_evidence_reaction)
	_session_controller.evidence_reaction.connect(_on_evidence_reaction)

	if _session_controller.evidence_combination_resolved.is_connected(_on_evidence_combination_resolved):
		_session_controller.evidence_combination_resolved.disconnect(_on_evidence_combination_resolved)
	_session_controller.evidence_combination_resolved.connect(_on_evidence_combination_resolved)

	if _session_controller.guard_danger_entered.is_connected(_on_guard_danger_entered):
		_session_controller.guard_danger_entered.disconnect(_on_guard_danger_entered)
	_session_controller.guard_danger_entered.connect(_on_guard_danger_entered)

	if _session_controller.suspect_dissociated.is_connected(_on_suspect_dissociated):
		_session_controller.suspect_dissociated.disconnect(_on_suspect_dissociated)
	_session_controller.suspect_dissociated.connect(_on_suspect_dissociated)

	if _session_controller.suspect_recovered.is_connected(_on_suspect_recovered):
		_session_controller.suspect_recovered.disconnect(_on_suspect_recovered)
	_session_controller.suspect_recovered.connect(_on_suspect_recovered)

	if _session_controller.evidence_already_presented.is_connected(_on_evidence_already_presented):
		_session_controller.evidence_already_presented.disconnect(_on_evidence_already_presented)
	_session_controller.evidence_already_presented.connect(_on_evidence_already_presented)

	if _session_controller.evidence_combination_unlocked.is_connected(_on_evidence_combination_unlocked):
		_session_controller.evidence_combination_unlocked.disconnect(_on_evidence_combination_unlocked)
	_session_controller.evidence_combination_unlocked.connect(_on_evidence_combination_unlocked)

	if _session_controller.confession_statement.is_connected(_on_confession_statement):
		_session_controller.confession_statement.disconnect(_on_confession_statement)
	_session_controller.confession_statement.connect(_on_confession_statement)

	if _session_controller.session_ended.is_connected(_on_session_ended):
		_session_controller.session_ended.disconnect(_on_session_ended)
	_session_controller.session_ended.connect(_on_session_ended)

	var suspect_config := session_controller.suspect_config
	_emotion_controller.bind(suspect_config)
	_stage_label.text = "STAGE %d - %s" % [suspect_config.suspect_type + 1, suspect_config.suspect_name]
	_suspect_tab_label.text = suspect_config.suspect_name
	_emotion_controller.set_emotion("idle")
	_update_action_squares(_session_controller.actions_remaining)

func start_opening_statement() -> void:
	var opening_line := _session_controller.suspect_config.opening_statement_text
	_session_controller.record_opening_statement(opening_line)
	_push_log_line("%s: %s" % [_session_controller.suspect_config.suspect_name, opening_line], true)
	_show_suspect_line(opening_line)

func _on_player_input_submitted(text: String) -> void:
	_push_log_line("수사관: %s" % text)

func _on_turn_resolved(
		has_technique: bool,
		technique: TechniqueExecutor.TechniqueType,
		result: TechniqueExecutor.TechniqueResult,
		dialogue: String,
		emotion: String,
) -> void:
	if _is_suspect_dissociated:
		_latest_turn_reading = _DISSOCIATED_TURN_READING
	else:
		_latest_turn_reading = TechniqueLabels.describe_turn(has_technique, technique, result)
	_push_log_line("%s: %s" % [_session_controller.suspect_config.suspect_name, dialogue], true)
	_show_suspect_line(dialogue)
	_emotion_controller.set_emotion(emotion)

func _on_evidence_reaction(evidence: EvidenceItem, dialogue: String, emotion_event: String) -> void:
	_push_log_line("수사관: (증거 제시 — %s)" % evidence.description)
	_push_log_line("%s: %s" % [_session_controller.suspect_config.suspect_name, dialogue], true)
	_show_suspect_line(dialogue)
	if not emotion_event.is_empty():
		_emotion_controller.set_emotion_for_event(emotion_event)

func _on_session_ended(is_success: bool) -> void:
	_emotion_controller.set_emotion_for_event("confession" if is_success else "session_end")

func _on_emotion_changed(_tag: String, texture: Texture2D) -> void:
	_suspect_portrait_texture.texture = texture

func _on_evidence_combination_resolved(_is_valid: bool, combination_name: String, dialogue: String) -> void:
	_push_log_line("수사관: (증거 조합 제시 — %s)" % combination_name)
	_push_log_line("%s: %s" % [_session_controller.suspect_config.suspect_name, dialogue], true)
	_show_suspect_line(dialogue)

func _on_evidence_combination_unlocked() -> void:
	var narration := "%s의 시선이 처음으로 증거 쪽을 향한다." % _session_controller.suspect_config.suspect_name
	_push_log_line("(%s)" % narration)
	_show_overhead_narration(narration)

func _on_suspect_dissociated() -> void:
	_is_suspect_dissociated = true
	var narration := "%s의 눈이 초점을 잃었다." % _session_controller.suspect_config.suspect_name
	_push_log_line("(%s)" % narration)
	_show_overhead_narration(narration)

func _on_suspect_recovered() -> void:
	_is_suspect_dissociated = false
	var narration := "%s의 눈에 초점이 돌아왔다." % _session_controller.suspect_config.suspect_name
	_push_log_line("(%s)" % narration)
	_show_overhead_narration(narration)

func _on_evidence_already_presented() -> void:
	_show_overhead_narration(_ALREADY_PRESENTED_TEXT)

func _show_overhead_narration(text: String) -> void:
	_hide_overhead_narration()
	_overhead_narration_label.text = text
	_overhead_narration_label.visible = true
	_overhead_narration_tween = create_tween()
	_overhead_narration_tween.tween_interval(_OVERHEAD_NARRATION_HOLD_SECONDS)
	_overhead_narration_tween.tween_property(_overhead_narration_label, "modulate:a", 0.0, _OVERHEAD_NARRATION_FADE_SECONDS)
	_overhead_narration_tween.tween_callback(_hide_overhead_narration)

func _hide_overhead_narration() -> void:
	if _overhead_narration_tween != null and _overhead_narration_tween.is_valid():
		_overhead_narration_tween.kill()
	_overhead_narration_label.visible = false
	_overhead_narration_label.modulate.a = 1.0

func _on_guard_danger_entered() -> void:
	var warning := _GUARD_WARNING_FORMAT % _session_controller.suspect_config.suspect_name
	_push_log_line("(%s)" % warning)
	_hide_guard_warning()
	_guard_warning_label.text = warning
	_guard_warning_label.visible = true
	_guard_warning_tween = create_tween()
	_guard_warning_tween.tween_interval(_OVERHEAD_NARRATION_HOLD_SECONDS)
	_guard_warning_tween.tween_property(_guard_warning_label, "modulate:a", 0.0, _OVERHEAD_NARRATION_FADE_SECONDS)
	_guard_warning_tween.tween_callback(_hide_guard_warning)

func _hide_guard_warning() -> void:
	if _guard_warning_tween != null and _guard_warning_tween.is_valid():
		_guard_warning_tween.kill()
	_guard_warning_label.visible = false
	_guard_warning_label.modulate.a = 1.0

func _on_confession_statement(dialogue: String) -> void:
	_push_log_line("%s: %s" % [_session_controller.suspect_config.suspect_name, dialogue], true)
	_show_suspect_line(dialogue)
	_emotion_controller.set_emotion_for_event("confession")
	_awaiting_confession_continue = true
	_confession_continue_button.visible = true

func _on_confession_continue_button_pressed() -> void:
	if _is_typing:
		_skip_typing()
		return
	_confession_continue_button.visible = false
	_awaiting_confession_continue = false
	_session_controller.finalize_confession()

func _show_suspect_line(line: String) -> void:
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	_suspect_dialogue_label.text = line
	_suspect_dialogue_label.visible_characters = 0
	_typewriter_revealed_count = 0
	_blip_pending_count = 0
	_is_typing = true
	var character_count := _suspect_dialogue_label.get_total_character_count()
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_method(_on_typewriter_progress, 0, character_count,
			character_count * _TYPEWRITER_SECONDS_PER_CHARACTER)
	_typewriter_tween.finished.connect(_on_typewriter_finished)

func _on_typewriter_progress(value: float) -> void:
	var new_revealed_count := int(value)
	_suspect_dialogue_label.visible_characters = new_revealed_count
	var full_text := _suspect_dialogue_label.text
	for i in range(_typewriter_revealed_count, new_revealed_count):
		if i >= full_text.length():
			break
		if full_text[i] in _BLIP_EXCLUDED_CHARACTERS:
			continue
		_blip_pending_count += 1
		if _blip_pending_count >= _BLIP_CHARACTERS_PER_SOUND:
			_blip_player.play()
			_blip_pending_count = 0
	_typewriter_revealed_count = new_revealed_count

func _on_typewriter_finished() -> void:
	_is_typing = false

func _unhandled_input(event: InputEvent) -> void:
	if not _is_typing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_skip_typing()

func _skip_typing() -> void:
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	_suspect_dialogue_label.visible_characters = _suspect_dialogue_label.get_total_character_count()
	_is_typing = false

func _push_log_line(line: String, is_suspect_line: bool = false) -> void:
	_log_lines.append(("▶ " if is_suspect_line else "") + line)
	_render_log()

func _render_log() -> void:
	_dialogue_log.text = "\n".join(_log_lines)
	_dialogue_log.scroll_to_line(_dialogue_log.get_line_count() - 1)

func _update_action_squares(remaining: int) -> void:
	for i in _action_squares.size():
		_action_squares[i].texture = _ACTION_SLOT_FULL_TEXTURE if i < remaining else _ACTION_SLOT_EMPTY_TEXTURE

func _show_turn_reading() -> void:
	_show_overhead_narration(_NO_TURN_READING_TEXT if _latest_turn_reading.is_empty() else _latest_turn_reading)

func _show_case_file() -> void:
	_show_text_popup(_session_controller.suspect_config.case_file_text)

func _show_profile_notebook() -> void:
	_show_text_popup(_session_controller.suspect_config.profile_notebook_text)

func _show_text_popup(text: String) -> void:
	_text_popup_label.text = text
	_text_popup_overlay.visible = true

func _toggle_evidence_overlay() -> void:
	_evidence_overlay.visible = not _evidence_overlay.visible

func _toggle_statement_input_panel() -> void:
	_statement_input_panel.visible = not _statement_input_panel.visible

func _toggle_dialogue_log() -> void:
	_dialogue_log_overlay.visible = not _dialogue_log_overlay.visible
