class_name FailureChecker
extends RefCounted

const FAILURE_COUNT_FOR_HALF_EFFECT := 2
const FAILURE_COUNT_FOR_LOCK := 3
const TOTAL_FAILURE_COUNT_FOR_GUARD_PENALTY := 5
const GUARD_SESSION_END_PENALTY := 10.0
const CONSECUTIVE_USE_THRESHOLD := 3

var last_used_technique: int = -1

var _consecutive_technique: int = -1
var _consecutive_count: int = 0

var _technique_use_count: Dictionary = {}
var _technique_failure_count: Dictionary = {}
var _total_failure_count: int = 0

var _real_evidence_presented_count: int = 0

func record_real_evidence_presented() -> void:
	_real_evidence_presented_count += 1

func has_real_evidence_been_presented() -> bool:
	return _real_evidence_presented_count > 0

func get_effectiveness_multiplier(technique_type: TechniqueExecutor.TechniqueType) -> float:
	var failures: int = _technique_failure_count.get(technique_type, 0)
	if failures >= FAILURE_COUNT_FOR_LOCK:
		return 0.0
	if failures >= FAILURE_COUNT_FOR_HALF_EFFECT:
		return 0.5
	return 1.0

func is_locked(technique_type: TechniqueExecutor.TechniqueType) -> bool:
	return _technique_failure_count.get(technique_type, 0) >= FAILURE_COUNT_FOR_LOCK

func get_guard_session_end_penalty() -> float:
	return GUARD_SESSION_END_PENALTY if _total_failure_count >= TOTAL_FAILURE_COUNT_FOR_GUARD_PENALTY else 0.0

func get_effective_guard_session_end(suspect_config: SuspectConfig) -> float:
	return suspect_config.guard_session_end - get_guard_session_end_penalty()

func check(
		technique_type: TechniqueExecutor.TechniqueType,
		suspect_config: SuspectConfig,
		state_tracker: StateTracker,
		has_evidence: bool = true,
		target_has_emotional_relevance: bool = true,
		defends_accomplice: bool = false,
) -> TechniqueExecutor.TechniqueResult:
	if is_locked(technique_type):
		return TechniqueExecutor.TechniqueResult.NO_EFFECT

	match technique_type:
		TechniqueExecutor.TechniqueType.RAPPORT_BUILDING:
			return _check_rapport_building(suspect_config, state_tracker)
		TechniqueExecutor.TechniqueType.INCONSISTENCY_POINT:
			return _check_inconsistency_point(suspect_config, has_evidence)
		TechniqueExecutor.TechniqueType.HIGH_PRESSURE:
			return _check_high_pressure(suspect_config, state_tracker)
		TechniqueExecutor.TechniqueType.SILENCE:
			return _check_silence(suspect_config, state_tracker)
		TechniqueExecutor.TechniqueType.MINIMIZATION:
			return _check_minimization(suspect_config)
		TechniqueExecutor.TechniqueType.MAXIMIZATION:
			return _check_maximization(suspect_config, state_tracker)
		TechniqueExecutor.TechniqueType.FALSE_EVIDENCE:
			return _check_false_evidence(suspect_config)
		TechniqueExecutor.TechniqueType.COGNITIVE_LOAD:
			return _check_cognitive_load(suspect_config, state_tracker)
		TechniqueExecutor.TechniqueType.THIRD_PARTY_MENTION:
			return _check_third_party_mention(suspect_config, target_has_emotional_relevance, defends_accomplice)
		TechniqueExecutor.TechniqueType.ROLE_REVERSAL:
			return _check_role_reversal(suspect_config, state_tracker)

	return TechniqueExecutor.TechniqueResult.SUCCESS

func record_result(technique_type: TechniqueExecutor.TechniqueType, result: TechniqueExecutor.TechniqueResult) -> void:
	if technique_type == _consecutive_technique:
		_consecutive_count += 1
	else:
		_consecutive_technique = technique_type
		_consecutive_count = 1

	_technique_use_count[technique_type] = _technique_use_count.get(technique_type, 0) + 1

	if result != TechniqueExecutor.TechniqueResult.SUCCESS:
		_technique_failure_count[technique_type] = _technique_failure_count.get(technique_type, 0) + 1
		_total_failure_count += 1

	last_used_technique = technique_type

func _predicted_consecutive_count(technique_type: TechniqueExecutor.TechniqueType) -> int:
	if technique_type == _consecutive_technique:
		return _consecutive_count + 1
	return 1

func _check_rapport_building(suspect_config: SuspectConfig, state_tracker: StateTracker) -> TechniqueExecutor.TechniqueResult:
	var stats := suspect_config.get_stats()
	if stats.charisma >= 80 and _predicted_consecutive_count(TechniqueExecutor.TechniqueType.RAPPORT_BUILDING) >= CONSECUTIVE_USE_THRESHOLD:
		return TechniqueExecutor.TechniqueResult.CRITICAL_FAIL
	if last_used_technique == TechniqueExecutor.TechniqueType.HIGH_PRESSURE:
		return TechniqueExecutor.TechniqueResult.BACKFIRE
	if state_tracker.guard_level >= 75.0:
		return TechniqueExecutor.TechniqueResult.NO_EFFECT
	return TechniqueExecutor.TechniqueResult.SUCCESS

func _check_inconsistency_point(suspect_config: SuspectConfig, has_evidence: bool) -> TechniqueExecutor.TechniqueResult:
	if suspect_config.suspect_type == SuspectConfig.SuspectType.DISSOCIATOR \
			and _predicted_consecutive_count(TechniqueExecutor.TechniqueType.INCONSISTENCY_POINT) >= CONSECUTIVE_USE_THRESHOLD:
		return TechniqueExecutor.TechniqueResult.CRITICAL_FAIL
	if not has_evidence:
		return TechniqueExecutor.TechniqueResult.BACKFIRE
	return TechniqueExecutor.TechniqueResult.SUCCESS

func _check_high_pressure(suspect_config: SuspectConfig, state_tracker: StateTracker) -> TechniqueExecutor.TechniqueResult:
	if state_tracker.guard_level >= get_effective_guard_session_end(suspect_config) - 10.0:
		return TechniqueExecutor.TechniqueResult.CRITICAL_FAIL
	if suspect_config.suspect_type == SuspectConfig.SuspectType.ANXIOUS and state_tracker.guard_level >= 55.0:
		return TechniqueExecutor.TechniqueResult.CRITICAL_FAIL
	if last_used_technique == TechniqueExecutor.TechniqueType.RAPPORT_BUILDING:
		return TechniqueExecutor.TechniqueResult.BACKFIRE
	return TechniqueExecutor.TechniqueResult.SUCCESS

func _check_silence(suspect_config: SuspectConfig, state_tracker: StateTracker) -> TechniqueExecutor.TechniqueResult:
	if suspect_config.suspect_type == SuspectConfig.SuspectType.STRATEGIST:
		return TechniqueExecutor.TechniqueResult.BACKFIRE
	if suspect_config.suspect_type == SuspectConfig.SuspectType.SILENT:
		return TechniqueExecutor.TechniqueResult.NO_EFFECT
	if state_tracker.rapport_level < 30.0:
		return TechniqueExecutor.TechniqueResult.NO_EFFECT
	return TechniqueExecutor.TechniqueResult.SUCCESS

func _check_minimization(suspect_config: SuspectConfig) -> TechniqueExecutor.TechniqueResult:
	if suspect_config.suspect_type == SuspectConfig.SuspectType.CYNIC:
		return TechniqueExecutor.TechniqueResult.BACKFIRE
	if _technique_use_count.get(TechniqueExecutor.TechniqueType.MINIMIZATION, 0) >= 2:
		return TechniqueExecutor.TechniqueResult.BACKFIRE
	return TechniqueExecutor.TechniqueResult.SUCCESS

func _check_maximization(suspect_config: SuspectConfig, state_tracker: StateTracker) -> TechniqueExecutor.TechniqueResult:
	if suspect_config.suspect_type == SuspectConfig.SuspectType.ANXIOUS and state_tracker.guard_level >= 55.0:
		return TechniqueExecutor.TechniqueResult.CRITICAL_FAIL
	if suspect_config.suspect_type == SuspectConfig.SuspectType.VICTIM:
		return TechniqueExecutor.TechniqueResult.BACKFIRE
	if state_tracker.rapport_level < 20.0:
		return TechniqueExecutor.TechniqueResult.BACKFIRE
	return TechniqueExecutor.TechniqueResult.SUCCESS

func _check_false_evidence(suspect_config: SuspectConfig) -> TechniqueExecutor.TechniqueResult:
	if suspect_config.suspect_type == SuspectConfig.SuspectType.STRATEGIST \
			or suspect_config.suspect_type == SuspectConfig.SuspectType.CYNIC:
		return TechniqueExecutor.TechniqueResult.CRITICAL_FAIL
	if _technique_use_count.get(TechniqueExecutor.TechniqueType.FALSE_EVIDENCE, 0) >= 1:
		return TechniqueExecutor.TechniqueResult.CRITICAL_FAIL
	if _real_evidence_presented_count == 0:
		return TechniqueExecutor.TechniqueResult.BACKFIRE
	return TechniqueExecutor.TechniqueResult.SUCCESS

func _check_cognitive_load(suspect_config: SuspectConfig, state_tracker: StateTracker) -> TechniqueExecutor.TechniqueResult:
	if state_tracker.rapport_level < 40.0:
		return TechniqueExecutor.TechniqueResult.BACKFIRE
	if suspect_config.suspect_type == SuspectConfig.SuspectType.STRATEGIST \
			and _technique_use_count.get(TechniqueExecutor.TechniqueType.COGNITIVE_LOAD, 0) >= 1:
		return TechniqueExecutor.TechniqueResult.NO_EFFECT
	return TechniqueExecutor.TechniqueResult.SUCCESS

func _check_third_party_mention(
		suspect_config: SuspectConfig,
		target_has_emotional_relevance: bool,
		defends_accomplice: bool,
) -> TechniqueExecutor.TechniqueResult:
	if suspect_config.suspect_type == SuspectConfig.SuspectType.FOLLOWER and defends_accomplice:
		return TechniqueExecutor.TechniqueResult.CRITICAL_FAIL
	if not target_has_emotional_relevance:
		return TechniqueExecutor.TechniqueResult.NO_EFFECT
	return TechniqueExecutor.TechniqueResult.SUCCESS

func _check_role_reversal(suspect_config: SuspectConfig, state_tracker: StateTracker) -> TechniqueExecutor.TechniqueResult:
	var stats := suspect_config.get_stats()
	if stats.charisma >= 80:
		return TechniqueExecutor.TechniqueResult.CRITICAL_FAIL
	if state_tracker.guard_level >= 70.0:
		return TechniqueExecutor.TechniqueResult.NO_EFFECT
	return TechniqueExecutor.TechniqueResult.SUCCESS
