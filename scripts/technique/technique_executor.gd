class_name TechniqueExecutor
extends Node

enum TechniqueType {
	RAPPORT_BUILDING,
	INCONSISTENCY_POINT,
	HIGH_PRESSURE,
	SILENCE,
	MINIMIZATION,
	MAXIMIZATION,
	FALSE_EVIDENCE,
	COGNITIVE_LOAD,
	THIRD_PARTY_MENTION,
	ROLE_REVERSAL,
}

enum TechniqueResult {
	SUCCESS,
	NO_EFFECT,
	BACKFIRE,
	CRITICAL_FAIL,
}

signal technique_applied(technique: TechniqueType, result: TechniqueResult)

var _success_count_by_technique: Dictionary = {}

func execute(
		technique_type: TechniqueType,
		suspect_config: SuspectConfig,
		state_tracker: StateTracker,
		failure_checker: FailureChecker,
		suspect_behaviour: SuspectBehaviour,
		has_evidence: bool = true,
		target_has_emotional_relevance: bool = true,
		defends_accomplice: bool = false,
) -> TechniqueResult:
	var result: TechniqueResult

	if suspect_behaviour.are_all_techniques_ineffective(suspect_config, state_tracker):
		result = TechniqueResult.NO_EFFECT
	else:
		result = failure_checker.check(
			technique_type,
			suspect_config,
			state_tracker,
			has_evidence,
			target_has_emotional_relevance,
			defends_accomplice,
		)

	var guard_delta := 0.0
	var rapport_delta := 0.0
	var ego_delta := 0.0

	if result == TechniqueResult.SUCCESS:
		var stats := suspect_config.get_stats()
		var deltas := _get_base_deltas_and_defense_stat(technique_type, stats)
		var multiplier := failure_checker.get_effectiveness_multiplier(technique_type)

		guard_delta = TechniqueEffects.get_applied_delta(deltas[0], deltas[3]) * multiplier
		rapport_delta = TechniqueEffects.get_applied_delta(deltas[1], deltas[3]) * multiplier
		ego_delta = TechniqueEffects.get_applied_delta(deltas[2], deltas[3]) * multiplier

		state_tracker.apply_guard_delta(guard_delta)
		state_tracker.apply_rapport_delta(rapport_delta)
		state_tracker.apply_ego_delta(ego_delta)

		var previous_successes: int = _success_count_by_technique.get(technique_type, 0)
		var collapse_delta := TechniqueEffects.get_applied_delta(
				TechniqueEffects.get_collapse_base_delta(technique_type), deltas[3]) \
				* multiplier * pow(TechniqueEffects.COLLAPSE_REPEAT_DECAY, previous_successes)
		if collapse_delta != 0.0:
			state_tracker.apply_collapse_delta(collapse_delta)
		_success_count_by_technique[technique_type] = previous_successes + 1
	elif result == TechniqueResult.BACKFIRE or result == TechniqueResult.CRITICAL_FAIL:
		var penalty := _get_failure_penalty(technique_type, result, state_tracker, suspect_config)
		guard_delta = penalty[0]
		rapport_delta = penalty[1]
		state_tracker.apply_guard_delta(guard_delta)
		state_tracker.apply_rapport_delta(rapport_delta)

	failure_checker.record_result(technique_type, result)
	technique_applied.emit(technique_type, result)
	return result

func _get_failure_penalty(technique_type: TechniqueType, result: TechniqueResult, state_tracker: StateTracker,
		suspect_config: SuspectConfig) -> Array:
	if result == TechniqueResult.CRITICAL_FAIL and technique_type == TechniqueType.INCONSISTENCY_POINT \
			and suspect_config.suspect_type == SuspectConfig.SuspectType.DISSOCIATOR:
		return [0.0, 0.0]
	if technique_type == TechniqueType.HIGH_PRESSURE and result == TechniqueResult.BACKFIRE:
		return [TechniqueEffects.HIGH_PRESSURE_AFTER_RAPPORT_GUARD_PENALTY, -state_tracker.rapport_level]
	if result == TechniqueResult.CRITICAL_FAIL:
		return [TechniqueEffects.CRITICAL_FAIL_GUARD_PENALTY, -TechniqueEffects.CRITICAL_FAIL_RAPPORT_PENALTY]
	return [TechniqueEffects.BACKFIRE_GUARD_PENALTY, -TechniqueEffects.BACKFIRE_RAPPORT_PENALTY]

func _get_base_deltas_and_defense_stat(technique_type: TechniqueType, stats: SuspectStats) -> Array:
	match technique_type:
		TechniqueType.RAPPORT_BUILDING:
			return [TechniqueEffects.RAPPORT_BUILDING_GUARD_DELTA, TechniqueEffects.RAPPORT_BUILDING_RAPPORT_DELTA, TechniqueEffects.RAPPORT_BUILDING_EGO_DELTA, stats.charisma]
		TechniqueType.INCONSISTENCY_POINT:
			return [TechniqueEffects.INCONSISTENCY_POINT_GUARD_DELTA, TechniqueEffects.INCONSISTENCY_POINT_RAPPORT_DELTA, TechniqueEffects.INCONSISTENCY_POINT_EGO_DELTA, stats.logic]
		TechniqueType.HIGH_PRESSURE:
			return [TechniqueEffects.HIGH_PRESSURE_GUARD_DELTA, TechniqueEffects.HIGH_PRESSURE_RAPPORT_DELTA, TechniqueEffects.HIGH_PRESSURE_EGO_DELTA, stats.composure]
		TechniqueType.SILENCE:
			return [TechniqueEffects.SILENCE_GUARD_DELTA, TechniqueEffects.SILENCE_RAPPORT_DELTA, TechniqueEffects.SILENCE_EGO_DELTA, stats.composure]
		TechniqueType.MINIMIZATION:
			return [TechniqueEffects.MINIMIZATION_GUARD_DELTA, TechniqueEffects.MINIMIZATION_RAPPORT_DELTA, TechniqueEffects.MINIMIZATION_EGO_DELTA, stats.acting]
		TechniqueType.MAXIMIZATION:
			return [TechniqueEffects.MAXIMIZATION_GUARD_DELTA, TechniqueEffects.MAXIMIZATION_RAPPORT_DELTA, TechniqueEffects.MAXIMIZATION_EGO_DELTA, stats.composure]
		TechniqueType.FALSE_EVIDENCE:
			return [TechniqueEffects.FALSE_EVIDENCE_GUARD_DELTA, TechniqueEffects.FALSE_EVIDENCE_RAPPORT_DELTA, TechniqueEffects.FALSE_EVIDENCE_EGO_DELTA, max(stats.logic, stats.adaptability)]
		TechniqueType.COGNITIVE_LOAD:
			return [TechniqueEffects.COGNITIVE_LOAD_GUARD_DELTA, TechniqueEffects.COGNITIVE_LOAD_RAPPORT_DELTA, TechniqueEffects.COGNITIVE_LOAD_EGO_DELTA, stats.adaptability]
		TechniqueType.THIRD_PARTY_MENTION:
			return [TechniqueEffects.THIRD_PARTY_MENTION_GUARD_DELTA, TechniqueEffects.THIRD_PARTY_MENTION_RAPPORT_DELTA, TechniqueEffects.THIRD_PARTY_MENTION_EGO_DELTA, stats.deception]
		TechniqueType.ROLE_REVERSAL:
			return [TechniqueEffects.ROLE_REVERSAL_GUARD_DELTA, TechniqueEffects.ROLE_REVERSAL_RAPPORT_DELTA, TechniqueEffects.ROLE_REVERSAL_EGO_DELTA, stats.charisma]
	return [0.0, 0.0, 0.0, 0]
