class_name ConfessionChecker
extends RefCounted

const STRATEGIST_REQUIRED_REAL_EVIDENCE_AFTER_COGLOAD := 1

func check(
		suspect_config: SuspectConfig,
		state_tracker: StateTracker,
		suspect_behaviour: SuspectBehaviour,
		context: ConfessionContext,
) -> bool:
	if not _is_rapport_route_met(suspect_config, state_tracker) \
			and not _is_collapse_route_met(suspect_config, state_tracker):
		return false

	return _check_special_condition(suspect_config, suspect_behaviour, context)

func _is_rapport_route_met(suspect_config: SuspectConfig, state_tracker: StateTracker) -> bool:
	if state_tracker.guard_level > suspect_config.confession_guard_max:
		return false
	if suspect_config.suspect_type != SuspectConfig.SuspectType.SILENT \
			and state_tracker.rapport_level < suspect_config.confession_rapport_min:
		return false
	return true

func _is_collapse_route_met(suspect_config: SuspectConfig, state_tracker: StateTracker) -> bool:
	return state_tracker.collapse_level >= suspect_config.collapse_confession_min

func _check_special_condition(
		suspect_config: SuspectConfig,
		suspect_behaviour: SuspectBehaviour,
		context: ConfessionContext,
) -> bool:
	match suspect_config.suspect_type:
		SuspectConfig.SuspectType.ANXIOUS:
			return context.minimization_used
		SuspectConfig.SuspectType.VICTIM:
			return context.victim_emotion_event_occurred
		SuspectConfig.SuspectType.CYNIC:
			return context.real_evidence_presented_count >= 2 and suspect_behaviour.has_rapport_ever_reached_30()
		SuspectConfig.SuspectType.SHOWOFF:
			return context.showoff_recognition_event_occurred
		SuspectConfig.SuspectType.STRATEGIST:
			return context.real_evidence_after_cogload_streak >= STRATEGIST_REQUIRED_REAL_EVIDENCE_AFTER_COGLOAD
		SuspectConfig.SuspectType.FOLLOWER:
			return context.rapport_building_after_betrayal
		SuspectConfig.SuspectType.DISSOCIATOR:
			return context.dissociator_contradiction_event_occurred
		SuspectConfig.SuspectType.NARCISSIST:
			return context.silence_used_at_ego_collapse or context.narcissist_accomplice_event_occurred
		SuspectConfig.SuspectType.SILENT:
			return context.silent_valid_combination_submitted

	return false
