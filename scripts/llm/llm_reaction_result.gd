class_name LLMReactionResult
extends RefCounted

var error_type: LLMErrorType.Type = LLMErrorType.Type.NONE
var error_message: String = ""
var dialogue: String = ""

func is_success() -> bool:
	return error_type == LLMErrorType.Type.NONE
