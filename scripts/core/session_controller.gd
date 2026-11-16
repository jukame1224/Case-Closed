class_name SessionController
extends Node

signal session_ended(is_success: bool)
signal phase_changed(phase: GameManager.GamePhase)
signal llm_request_failed(error_message: String)
signal actions_remaining_changed(remaining: int)
signal turn_resolved(
		has_technique: bool,
		technique: TechniqueExecutor.TechniqueType,
		result: TechniqueExecutor.TechniqueResult,
		dialogue: String,
		emotion: String,
)
signal evidence_reaction(evidence: EvidenceItem, dialogue: String, emotion_event: String)
signal evidence_combination_resolved(is_valid: bool, combination_name: String, dialogue: String)
signal evidence_combination_unlocked
signal evidence_already_presented
signal suspect_dissociated
signal suspect_recovered
signal guard_danger_entered
signal confession_statement(dialogue: String)

const _SHOWOFF_RECOGNITION_EGO_MIN := 90.0
const _SILENT_EVIDENCE_UNLOCK_GUARD_MAX := 60.0
const _SILENT_INVALID_COMBINATION_GUARD_PENALTY := 15.0
const _SILENT_VALID_EVIDENCE_COMBINATIONS := [
	["E9-1", "E9-3"],
	["E9-2", "E9-1"],
]
const _SILENT_COMBINATION_NAME_BY_KEY := {
	"E9-1+E9-3": "실종 당일 알리바이 없음 + 현장 목격 제보",
	"E9-1+E9-2": "비자금 흐름 + 당일 행적 공백",
	"E9-2+E9-3": "내부 문건 + 제보",
}
const _SILENT_COMBINATION_SUCCESS_DIALOGUE := "... 계속하시죠."
const _SILENT_COMBINATION_INVALID_DIALOGUE := "비논리적이군요. 다시 생각해보시길."

const _FAKE_EVIDENCE_DETECTION_THRESHOLD := 40.0

const _PANIC_EMOTION_TAG := "panic"
const _DISSOCIATION_EMOTION_TAG := "idle"
const _DISSOCIATION_FALLBACK_DIALOGUE := "……."

const MAX_ACTIONS := 10

var suspect_config: SuspectConfig
var state_tracker: StateTracker
var failure_checker: FailureChecker
var confession_checker: ConfessionChecker
var suspect_behaviour: SuspectBehaviour
var technique_executor: TechniqueExecutor
var confession_context: ConfessionContext

var current_phase: GameManager.GamePhase
var round_number: int = 0
var actions_remaining: int = MAX_ACTIONS

var _is_session_active: bool = false
var _presented_evidence_keys: Dictionary = {}
var _dialogue_history: Array[String] = []
var _keyword_reaction_triggered: bool = false
var _was_in_guard_danger: bool = false

func start_session(suspect_type: SuspectConfig.SuspectType) -> void:
	suspect_config = SuspectConfig.load_for_type(suspect_type)

	state_tracker = StateTracker.new()
	state_tracker.initialize(suspect_config.init_guard, suspect_config.init_rapport, suspect_config.init_ego)

	failure_checker = FailureChecker.new()
	confession_checker = ConfessionChecker.new()
	suspect_behaviour = SuspectBehaviour.new()
	confession_context = ConfessionContext.new()

	technique_executor = TechniqueExecutor.new()
	add_child(technique_executor)
	technique_executor.technique_applied.connect(_on_technique_applied)

	round_number = 1
	actions_remaining = MAX_ACTIONS
	_is_session_active = true
	_set_phase(GameManager.GamePhase.ACTIVE)

func submit_player_input(player_input: String) -> void:
	if not _is_session_active or current_phase != GameManager.GamePhase.ACTIVE:
		push_error("ACTIVE 단계가 아닌 상태에서 submit_player_input가 호출됨")
		return

	_set_phase(GameManager.GamePhase.LLM_WAITING)
	var was_combination_unlocked := confession_context.evidence_combination_unlocked

	if suspect_behaviour.is_fully_dissociated():
		_consume_action()
		var dissociated: Array = _take_dissociation_line()
		_append_investigator_line(player_input)
		_append_suspect_line(dissociated[0])
		turn_resolved.emit(false, TechniqueExecutor.TechniqueType.RAPPORT_BUILDING, TechniqueExecutor.TechniqueResult.NO_EFFECT,
				dissociated[0], _DISSOCIATION_EMOTION_TAG)
		if dissociated[1]:
			suspect_recovered.emit()
		_finish_turn()
		return

	var classification := await LLMManager.classify(player_input, suspect_config, state_tracker, _dialogue_history)
	if not classification.is_success():
		llm_request_failed.emit(classification.error_message)
		_set_phase(GameManager.GamePhase.ACTIVE)
		return

	_consume_action()
	var keyword_note := _apply_keyword_reaction(player_input)

	var technique := TechniqueExecutor.TechniqueType.RAPPORT_BUILDING
	var technique_result := TechniqueExecutor.TechniqueResult.NO_EFFECT
	if classification.has_technique:
		technique = classification.technique
		technique_result = technique_executor.execute(
			technique,
			suspect_config,
			state_tracker,
			failure_checker,
			suspect_behaviour,
			failure_checker.has_real_evidence_been_presented(),
			classification.target_has_emotional_relevance,
			classification.defends_accomplice,
		)
		_track_technique_for_confession(technique)

	_apply_special_event(classification.special_event_detected)
	if suspect_config.suspect_type == SuspectConfig.SuspectType.SHOWOFF:
		suspect_behaviour.set_showoff_reaction(suspect_config, state_tracker, classification.special_event_detected)

	if check_confession():
		return

	var dialogue: String
	var emotion := classification.emotion
	var just_dissociated := suspect_behaviour.is_fully_dissociated()
	if just_dissociated:
		var dissociated: Array = _take_dissociation_line()
		dialogue = dissociated[0]
		emotion = _DISSOCIATION_EMOTION_TAG
	elif _is_panic_locked():
		dialogue = suspect_config.panic_dialogue_text
		emotion = _PANIC_EMOTION_TAG
	else:
		var reaction := await LLMManager.generate_reaction(
			player_input,
			suspect_config,
			state_tracker,
			suspect_behaviour,
			classification.has_technique,
			technique,
			technique_result,
			_dialogue_history,
			keyword_note,
		)
		dialogue = reaction.dialogue if reaction.is_success() else suspect_config.classification_failed_dialogue

	_append_investigator_line(player_input)
	_append_suspect_line(dialogue)
	turn_resolved.emit(classification.has_technique, technique, technique_result, dialogue, emotion)
	if not was_combination_unlocked and confession_context.evidence_combination_unlocked:
		evidence_combination_unlocked.emit()
	if just_dissociated:
		suspect_dissociated.emit()
	_finish_turn()

func _finish_turn() -> void:
	suspect_behaviour.update_round_state(suspect_config, state_tracker)
	_check_session_end_conditions()
	if _is_session_active:
		round_number += 1
		_set_phase(GameManager.GamePhase.ACTIVE)

func _apply_keyword_reaction(player_input: String) -> String:
	if _keyword_reaction_triggered:
		return ""
	for keyword in suspect_config.reaction_keywords:
		if player_input.contains(keyword):
			_keyword_reaction_triggered = true
			if suspect_config.keyword_guard_delta != 0.0:
				state_tracker.apply_guard_delta(suspect_config.keyword_guard_delta)
			if suspect_config.keyword_collapse_delta != 0.0:
				state_tracker.apply_collapse_delta(suspect_config.keyword_collapse_delta)
			return suspect_config.keyword_reaction_note
	return ""

func _take_dissociation_line() -> Array:
	var lines: Array[String] = suspect_config.dissociation_dialogue_lines
	var line: String = _DISSOCIATION_FALLBACK_DIALOGUE
	if not lines.is_empty():
		line = lines[mini(suspect_behaviour.get_dissociation_turn_index(), lines.size() - 1)]
	var ended := suspect_behaviour.consume_dissociation_turn()
	return [line, ended]

func _apply_special_event(detected: bool) -> void:
	if not detected:
		return
	match suspect_config.suspect_type:
		SuspectConfig.SuspectType.NARCISSIST:
			confession_context.narcissist_accomplice_event_occurred = true
		SuspectConfig.SuspectType.VICTIM:
			confession_context.victim_emotion_event_occurred = true
		SuspectConfig.SuspectType.DISSOCIATOR:
			confession_context.dissociator_contradiction_event_occurred = true
		SuspectConfig.SuspectType.FOLLOWER:
			confession_context.betrayal_info_presented = true
		SuspectConfig.SuspectType.SHOWOFF:
			if state_tracker.ego_level >= _SHOWOFF_RECOGNITION_EGO_MIN:
				confession_context.showoff_recognition_event_occurred = true

func _track_technique_for_confession(technique: TechniqueExecutor.TechniqueType) -> void:
	match technique:
		TechniqueExecutor.TechniqueType.MINIMIZATION:
			confession_context.minimization_used = true
		TechniqueExecutor.TechniqueType.COGNITIVE_LOAD:
			confession_context.cognitive_load_used = true
		TechniqueExecutor.TechniqueType.RAPPORT_BUILDING:
			if confession_context.betrayal_info_presented:
				confession_context.rapport_building_after_betrayal = true
		TechniqueExecutor.TechniqueType.SILENCE:
			if state_tracker.ego_level <= suspect_config.ego_extreme:
				confession_context.silence_used_at_ego_collapse = true

	if suspect_config.suspect_type == SuspectConfig.SuspectType.SILENT \
			and state_tracker.guard_level <= _SILENT_EVIDENCE_UNLOCK_GUARD_MAX:
		confession_context.evidence_combination_unlocked = true

func check_confession() -> bool:
	if not _is_session_active:
		return false

	var confessed := confession_checker.check(suspect_config, state_tracker, suspect_behaviour, confession_context)
	if confessed:
		_trigger_confession_sequence()
	return confessed

func _trigger_confession_sequence() -> void:
	_is_session_active = false
	_set_phase(GameManager.GamePhase.CONFESSION)
	confession_statement.emit(suspect_config.confession_dialogue_text)

func finalize_confession() -> void:
	session_ended.emit(true)

func present_evidence(evidence: EvidenceItem) -> bool:
	if not _is_session_active:
		return false
	if _presented_evidence_keys.has(evidence.evidence_id):
		evidence_already_presented.emit()
		return false

	if suspect_behaviour.is_fully_dissociated():
		_consume_action()
		var dissociated: Array = _take_dissociation_line()
		_append_investigator_line("(증거 제시 — %s)" % evidence.description)
		_append_suspect_line(dissociated[0])
		evidence_reaction.emit(evidence, dissociated[0], "")
		if dissociated[1]:
			suspect_recovered.emit()
		_check_session_end_conditions()
		return false

	_presented_evidence_keys[evidence.evidence_id] = true

	_consume_action()

	if evidence.evidence_type == EvidenceItem.EvidenceType.REAL:
		confession_context.real_evidence_presented_count += 1
		if confession_context.cognitive_load_used:
			confession_context.real_evidence_after_cogload_streak += 1
		failure_checker.record_real_evidence_presented()
	else:
		confession_context.real_evidence_after_cogload_streak = 0
	_apply_evidence_collapse(evidence)

	if check_confession():
		return true

	var evidence_dialogue := _resolve_evidence_dialogue(evidence)
	_append_investigator_line("(증거 제시 — %s)" % evidence.description)
	_append_suspect_line(evidence_dialogue)
	evidence_reaction.emit(evidence, evidence_dialogue, _resolve_evidence_emotion_event(evidence))
	_check_session_end_conditions()
	return false

func _resolve_evidence_dialogue(evidence: EvidenceItem) -> String:
	if suspect_config.suspect_type == SuspectConfig.SuspectType.SILENT:
		return evidence.reaction_dialogue
	if state_tracker.guard_level >= StateTracker.GUARD_INFO_BLOCK:
		return suspect_config.guard_blocked_dialogue
	if evidence.evidence_type == EvidenceItem.EvidenceType.FAKE and _can_detect_fake_evidence():
		return suspect_config.fake_evidence_detected_dialogue
	return evidence.reaction_dialogue

func _resolve_evidence_emotion_event(evidence: EvidenceItem) -> String:
	if suspect_config.suspect_type == SuspectConfig.SuspectType.SILENT:
		return ""
	if state_tracker.guard_level >= StateTracker.GUARD_INFO_BLOCK:
		return "evidence_blocked"
	if evidence.evidence_type == EvidenceItem.EvidenceType.FAKE:
		return "evidence_fake_caught" if _can_detect_fake_evidence() else ""
	return "evidence_real"

func _apply_evidence_collapse(evidence: EvidenceItem) -> void:
	if suspect_config.suspect_type != SuspectConfig.SuspectType.SILENT \
			and state_tracker.guard_level >= StateTracker.GUARD_INFO_BLOCK:
		return
	var logic := suspect_config.get_stats().logic
	if evidence.evidence_type == EvidenceItem.EvidenceType.REAL:
		state_tracker.apply_collapse_delta(TechniqueEffects.get_applied_delta(TechniqueEffects.REAL_EVIDENCE_COLLAPSE_DELTA, logic))
	elif _can_detect_fake_evidence():
		state_tracker.apply_collapse_delta(TechniqueEffects.DETECTED_FAKE_EVIDENCE_COLLAPSE_DELTA)
	else:
		state_tracker.apply_collapse_delta(TechniqueEffects.get_applied_delta(TechniqueEffects.UNDETECTED_FAKE_EVIDENCE_COLLAPSE_DELTA, logic))

func _can_detect_fake_evidence() -> bool:
	var stats := suspect_config.get_stats()
	return (stats.deception + stats.logic) / 2.0 >= _FAKE_EVIDENCE_DETECTION_THRESHOLD

func submit_evidence_combination(evidence_a: EvidenceItem, evidence_b: EvidenceItem) -> bool:
	if not is_evidence_combination_available():
		return false
	var combination_key := _get_combination_key(evidence_a, evidence_b)
	if _presented_evidence_keys.has(combination_key):
		evidence_already_presented.emit()
		return false
	_presented_evidence_keys[combination_key] = true

	_consume_action()
	var combination_name := get_evidence_combination_name(evidence_a, evidence_b)

	if _is_valid_evidence_combination(evidence_a.evidence_id, evidence_b.evidence_id):
		confession_context.silent_valid_combination_submitted = true
		state_tracker.apply_collapse_delta(TechniqueEffects.SILENT_VALID_COMBINATION_COLLAPSE_DELTA)
		if check_confession():
			return true
		_append_investigator_line("(증거 조합 제시 — %s)" % combination_name)
		_append_suspect_line(_SILENT_COMBINATION_SUCCESS_DIALOGUE)
		evidence_combination_resolved.emit(true, combination_name, _SILENT_COMBINATION_SUCCESS_DIALOGUE)
		return false

	_append_investigator_line("(증거 조합 제시 — %s)" % combination_name)
	_append_suspect_line(_SILENT_COMBINATION_INVALID_DIALOGUE)
	evidence_combination_resolved.emit(false, combination_name, _SILENT_COMBINATION_INVALID_DIALOGUE)
	state_tracker.apply_guard_delta(_SILENT_INVALID_COMBINATION_GUARD_PENALTY)
	_check_session_end_conditions()
	return false

func _is_panic_locked() -> bool:
	return suspect_behaviour.is_panicking() and not suspect_config.panic_dialogue_text.is_empty()

func is_evidence_combination_available() -> bool:
	return _is_session_active \
			and suspect_config.suspect_type == SuspectConfig.SuspectType.SILENT \
			and confession_context.evidence_combination_unlocked

func get_evidence_combination_name(evidence_a: EvidenceItem, evidence_b: EvidenceItem) -> String:
	var key := _get_combination_key(evidence_a, evidence_b)
	return str(_SILENT_COMBINATION_NAME_BY_KEY.get(key, key.replace("+", " + ")))

func _get_combination_key(evidence_a: EvidenceItem, evidence_b: EvidenceItem) -> String:
	var ids := [evidence_a.evidence_id, evidence_b.evidence_id]
	ids.sort()
	return "%s+%s" % ids

func _is_valid_evidence_combination(evidence_id_a: String, evidence_id_b: String) -> bool:
	for combo: Array in _SILENT_VALID_EVIDENCE_COMBINATIONS:
		if (combo[0] == evidence_id_a and combo[1] == evidence_id_b) \
				or (combo[0] == evidence_id_b and combo[1] == evidence_id_a):
			return true
	return false

func record_opening_statement(line: String) -> void:
	_append_suspect_line(line)

func _append_investigator_line(line: String) -> void:
	_dialogue_history.append("수사관: %s" % line)

func _append_suspect_line(line: String) -> void:
	_dialogue_history.append("%s: %s" % [suspect_config.suspect_name, line])

func _consume_action() -> void:
	actions_remaining -= 1
	actions_remaining_changed.emit(actions_remaining)

func _on_technique_applied(technique_type: TechniqueExecutor.TechniqueType, result: TechniqueExecutor.TechniqueResult) -> void:
	suspect_behaviour.on_technique_applied(technique_type, result, suspect_config, state_tracker)

func _check_session_end_conditions() -> void:
	if not _is_session_active:
		return

	if state_tracker.guard_level >= failure_checker.get_effective_guard_session_end(suspect_config):
		_end_session(false)
		return

	if actions_remaining <= 0:
		_end_session(false)
		return

	if suspect_behaviour.should_end_session(suspect_config, round_number):
		_end_session(false)
		return

	_check_guard_danger()

func _check_guard_danger() -> void:
	var danger_line := failure_checker.get_effective_guard_session_end(suspect_config) - StateTracker.GUARD_DANGER_ZONE
	var in_danger := state_tracker.guard_level >= danger_line
	if in_danger and not _was_in_guard_danger:
		guard_danger_entered.emit()
	_was_in_guard_danger = in_danger

func _end_session(is_success: bool) -> void:
	_is_session_active = false
	_set_phase(GameManager.GamePhase.CONFESSION if is_success else GameManager.GamePhase.SESSION_FAILED)
	session_ended.emit(is_success)

func _set_phase(phase: GameManager.GamePhase) -> void:
	current_phase = phase
	phase_changed.emit(phase)
