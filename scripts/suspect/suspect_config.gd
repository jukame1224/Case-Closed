@tool
class_name SuspectConfig
extends Resource

enum SuspectType {
	ANXIOUS,
	VICTIM,
	CYNIC,
	SHOWOFF,
	STRATEGIST,
	FOLLOWER,
	DISSOCIATOR,
	NARCISSIST,
	SILENT,
}

@export var suspect_type: SuspectType
@export var suspect_name: String

@export_group("LLM Prompt")
@export_multiline var personality_text: String
@export_multiline var background_text: String
@export_multiline var speech_style_text: String
@export_multiline var interrogation_attitude_text: String

@export_group("Keyword Reaction")
@export var reaction_keywords: Array[String] = []
@export var keyword_guard_delta: float = 0.0
@export var keyword_collapse_delta: float = 0.0
@export_multiline var keyword_reaction_note: String

@export_group("LLM Disclosure")
@export_multiline var cover_story_text: String
@export_multiline var disclosure_tier1_text: String
@export_multiline var disclosure_tier2_text: String

@export_group("UI Content")
@export_multiline var case_file_text: String
@export_multiline var profile_notebook_text: String
@export_multiline var opening_statement_text: String

@export_group("Fixed Dialogue")
@export_multiline var fake_evidence_detected_dialogue: String
@export_multiline var guard_blocked_dialogue: String
@export_multiline var classification_failed_dialogue: String
@export_multiline var panic_dialogue_text: String
@export var dissociation_dialogue_lines: Array[String] = []
@export_multiline var confession_dialogue_text: String

@export_group("Stats")
@export var charisma: int
@export var logic: int
@export var acting: int
@export var composure: int
@export var adaptability: int
@export var deception: int

func get_stats() -> SuspectStats:
	var stats := SuspectStats.new()
	stats.charisma = charisma
	stats.logic = logic
	stats.acting = acting
	stats.composure = composure
	stats.adaptability = adaptability
	stats.deception = deception
	return stats

@export_group("Initial Values")
@export var init_guard: float
@export var init_rapport: float
@export var init_ego: float

@export_group("Thresholds")
@export var guard_session_end: float
@export var ego_extreme: float

@export_group("Confession Conditions")
@export var confession_guard_max: float
@export var confession_rapport_min: float
@export var collapse_confession_min: float

@export_group("Emotion")
@export var emotion_sprites: Dictionary[String, Texture2D] = {}
@export var valid_emotion_tags: Array[String] = []
@export var emotion_tag_evidence_real: String = ""
@export var emotion_tag_evidence_fake_caught: String = ""
@export var emotion_tag_evidence_fake_caught_alt: String = ""
@export var emotion_tag_evidence_fake_caught_alt_min_acting: int = 0
@export var emotion_tag_name_trigger: String = ""

const _CONFIG_PATH_BY_TYPE := {
	SuspectType.ANXIOUS: "res://data/suspects/stage1_cha.tres",
	SuspectType.VICTIM: "res://data/suspects/stage2_oh.tres",
	SuspectType.CYNIC: "res://data/suspects/stage3_byun.tres",
	SuspectType.SHOWOFF: "res://data/suspects/stage4_na.tres",
	SuspectType.STRATEGIST: "res://data/suspects/stage5_seok.tres",
	SuspectType.FOLLOWER: "res://data/suspects/stage6_do.tres",
	SuspectType.DISSOCIATOR: "res://data/suspects/stage7_jin.tres",
	SuspectType.NARCISSIST: "res://data/suspects/stage8_eom.tres",
	SuspectType.SILENT: "res://data/suspects/stage9_bae.tres",
}

static func load_for_type(type: SuspectType) -> SuspectConfig:
	return load(_CONFIG_PATH_BY_TYPE[type]) as SuspectConfig
