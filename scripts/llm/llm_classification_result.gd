class_name LLMClassificationResult
extends RefCounted

var error_type: LLMErrorType.Type = LLMErrorType.Type.NONE
var error_message: String = ""

var has_technique: bool = false
var technique: TechniqueExecutor.TechniqueType

var target_has_emotional_relevance: bool = true
var defends_accomplice: bool = false
var special_event_detected: bool = false
var emotion: String = "talking"

func is_success() -> bool:
	return error_type == LLMErrorType.Type.NONE
