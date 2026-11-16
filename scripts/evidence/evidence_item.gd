@tool
class_name EvidenceItem
extends Resource

enum EvidenceType {
	REAL,
	FAKE,
}

@export var evidence_id: String
@export var stage: int
@export var description: String
@export var evidence_type: EvidenceType

@export_multiline var reaction_dialogue: String
