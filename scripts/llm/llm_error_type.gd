class_name LLMErrorType
extends RefCounted

enum Type {
	NONE,
	BUSY,
	CONNECTION_FAILED,
	TIMEOUT,
	PARSE_ERROR,
	LOW_QUALITY_RESPONSE,
}
