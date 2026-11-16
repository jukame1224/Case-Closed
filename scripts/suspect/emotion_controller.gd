class_name EmotionController
extends RefCounted

signal emotion_changed(tag: String, texture: Texture2D)

const _EVIDENCE_BLOCKED_TAG := "deny"
const _CONFESSION_TAG := "confess"
const _SESSION_END_TAG := "deny"

var _suspect_config: SuspectConfig

func bind(suspect_config: SuspectConfig) -> void:
	_suspect_config = suspect_config

func set_emotion(tag: String) -> void:
	if tag.is_empty() or not _suspect_config.emotion_sprites.has(tag):
		return
	emotion_changed.emit(tag, _suspect_config.emotion_sprites[tag])

func set_emotion_for_event(event: String) -> void:
	match event:
		"evidence_real":
			set_emotion(_suspect_config.emotion_tag_evidence_real)
		"evidence_fake_caught":
			set_emotion(_resolve_fake_caught_tag())
		"evidence_blocked":
			set_emotion(_EVIDENCE_BLOCKED_TAG)
		"confession":
			set_emotion(_CONFESSION_TAG)
		"session_end":
			set_emotion(_SESSION_END_TAG)
		"name_trigger":
			set_emotion(_suspect_config.emotion_tag_name_trigger)

func _resolve_fake_caught_tag() -> String:
	var alt_tag := _suspect_config.emotion_tag_evidence_fake_caught_alt
	if not alt_tag.is_empty():
		var acting := _suspect_config.get_stats().acting
		if acting >= _suspect_config.emotion_tag_evidence_fake_caught_alt_min_acting:
			return alt_tag
	return _suspect_config.emotion_tag_evidence_fake_caught
