class_name SuspectBehaviour
extends RefCounted

const CYNIC_AUTO_END_ROUND_THRESHOLD := 4
const CYNIC_RAPPORT_EVER_THRESHOLD := 30.0
const ANXIOUS_PANIC_GUARD_THRESHOLD := 70.0
const STRATEGIST_FALSE_EVIDENCE_GUARD_BONUS := 30.0
const DISSOCIATION_TURNS := 2

var _rapport_ever_reached_30: bool = false
var _is_panicking: bool = false
var _dissociation_turns_remaining: int = 0
var _accomplice_bond_reinforced: bool = false
var _is_blockaded: bool = false

func update_round_state(suspect_config: SuspectConfig, state_tracker: StateTracker) -> void:
	if suspect_config.suspect_type == SuspectConfig.SuspectType.CYNIC \
			and state_tracker.rapport_level >= CYNIC_RAPPORT_EVER_THRESHOLD:
		_rapport_ever_reached_30 = true

	if suspect_config.suspect_type == SuspectConfig.SuspectType.ANXIOUS \
			and state_tracker.guard_level >= ANXIOUS_PANIC_GUARD_THRESHOLD:
		_is_panicking = true

func on_technique_applied(
		technique_type: TechniqueExecutor.TechniqueType,
		result: TechniqueExecutor.TechniqueResult,
		suspect_config: SuspectConfig,
		state_tracker: StateTracker,
) -> void:
	if result != TechniqueExecutor.TechniqueResult.CRITICAL_FAIL:
		return

	if suspect_config.suspect_type == SuspectConfig.SuspectType.STRATEGIST \
			and technique_type == TechniqueExecutor.TechniqueType.FALSE_EVIDENCE:
		state_tracker.apply_guard_delta(STRATEGIST_FALSE_EVIDENCE_GUARD_BONUS)

	if suspect_config.suspect_type == SuspectConfig.SuspectType.DISSOCIATOR \
			and technique_type == TechniqueExecutor.TechniqueType.INCONSISTENCY_POINT:
		_dissociation_turns_remaining = DISSOCIATION_TURNS

	if suspect_config.suspect_type == SuspectConfig.SuspectType.FOLLOWER \
			and technique_type == TechniqueExecutor.TechniqueType.THIRD_PARTY_MENTION:
		_accomplice_bond_reinforced = true

func set_showoff_reaction(suspect_config: SuspectConfig, state_tracker: StateTracker, was_acknowledged: bool) -> void:
	if suspect_config.suspect_type != SuspectConfig.SuspectType.SHOWOFF:
		return
	if state_tracker.ego_level <= suspect_config.ego_extreme and not was_acknowledged:
		_is_blockaded = true

func has_rapport_ever_reached_30() -> bool:
	return _rapport_ever_reached_30

func is_panicking() -> bool:
	return _is_panicking

func is_fully_dissociated() -> bool:
	return _dissociation_turns_remaining > 0

func get_dissociation_turn_index() -> int:
	return DISSOCIATION_TURNS - _dissociation_turns_remaining

func consume_dissociation_turn() -> bool:
	if _dissociation_turns_remaining <= 0:
		return false
	_dissociation_turns_remaining -= 1
	return _dissociation_turns_remaining == 0

func is_blockaded() -> bool:
	return _is_blockaded

func are_all_techniques_ineffective(suspect_config: SuspectConfig, state_tracker: StateTracker) -> bool:
	if suspect_config.suspect_type == SuspectConfig.SuspectType.NARCISSIST:
		return state_tracker.ego_level <= suspect_config.ego_extreme
	if suspect_config.suspect_type == SuspectConfig.SuspectType.SHOWOFF:
		return _is_blockaded
	if suspect_config.suspect_type == SuspectConfig.SuspectType.DISSOCIATOR:
		return is_fully_dissociated()
	return false

func should_end_session(suspect_config: SuspectConfig, round_number: int) -> bool:
	if suspect_config.suspect_type == SuspectConfig.SuspectType.CYNIC \
			and round_number >= CYNIC_AUTO_END_ROUND_THRESHOLD and not _rapport_ever_reached_30:
		return true
	if suspect_config.suspect_type == SuspectConfig.SuspectType.FOLLOWER and _accomplice_bond_reinforced:
		return true
	return false
