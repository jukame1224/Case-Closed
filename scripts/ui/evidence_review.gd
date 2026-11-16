class_name EvidenceReview
extends Control

const _EVIDENCE_DIR := "res://data/evidence/"
const _COMBINATION_HINT_TEXT := "증거를 끌어다 다른 증거에 겹치면 조합할 수 있습니다."
const _DRAG_DATA_KEY := "evidence_entry_index"

@onready var _list_container: Container = %ListContainer

var _session_controller: SessionController
var _entries: Array[Array] = []

func bind(session_controller: SessionController) -> void:
	if is_instance_valid(_session_controller) and _session_controller.evidence_combination_unlocked.is_connected(_rebuild_rows):
		_session_controller.evidence_combination_unlocked.disconnect(_rebuild_rows)
	_session_controller = session_controller
	_session_controller.evidence_combination_unlocked.connect(_rebuild_rows)
	_load_entries()
	_rebuild_rows()

func _load_entries() -> void:
	_entries.clear()
	var current_stage := _session_controller.suspect_config.suspect_type + 1

	var file_names := ResourceLoader.list_directory(_EVIDENCE_DIR)
	file_names.sort()
	for file_name in file_names:
		if not file_name.ends_with(".tres"):
			continue
		var evidence: EvidenceItem = load(_EVIDENCE_DIR + file_name)
		if evidence.stage != current_stage:
			continue
		_entries.append([evidence])

func _rebuild_rows() -> void:
	for child in _list_container.get_children():
		_list_container.remove_child(child)
		child.queue_free()

	if _session_controller.is_evidence_combination_available():
		var hint_label := Label.new()
		hint_label.text = _COMBINATION_HINT_TEXT
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list_container.add_child(hint_label)

	for entry_index in _entries.size():
		_add_entry_row(entry_index)

func _add_entry_row(entry_index: int) -> void:
	var entry: Array = _entries[entry_index]
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = _get_entry_display_text(entry)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.set_drag_forwarding(
			_get_entry_drag_data.bind(entry_index, label),
			_can_drop_on_entry.bind(entry_index),
			_drop_on_entry.bind(entry_index),
	)
	row.add_child(label)

	var present_button := Button.new()
	present_button.text = "제시"
	present_button.pressed.connect(_on_present_pressed.bind(entry_index))
	row.add_child(present_button)

	if entry.size() == 2:
		var split_button := Button.new()
		split_button.text = "분리"
		split_button.pressed.connect(_on_split_pressed.bind(entry_index))
		row.add_child(split_button)

	_list_container.add_child(row)

func _get_entry_display_text(entry: Array) -> String:
	if entry.size() == 2:
		return "조합 — %s" % _session_controller.get_evidence_combination_name(entry[0], entry[1])
	var evidence: EvidenceItem = entry[0]
	return "%s — %s" % [evidence.evidence_id, evidence.description]

func _get_entry_drag_data(_at_position: Vector2, entry_index: int, source_label: Label) -> Variant:
	if not _session_controller.is_evidence_combination_available():
		return null
	if _entries[entry_index].size() != 1:
		return null

	var preview := Label.new()
	preview.text = source_label.text
	preview.modulate.a = 0.8
	source_label.set_drag_preview(preview)
	return {_DRAG_DATA_KEY: entry_index}

func _can_drop_on_entry(_at_position: Vector2, data: Variant, target_index: int) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has(_DRAG_DATA_KEY):
		return false
	var source_index: int = data[_DRAG_DATA_KEY]
	return source_index != target_index \
			and _entries[source_index].size() == 1 \
			and _entries[target_index].size() == 1

func _drop_on_entry(at_position: Vector2, data: Variant, target_index: int) -> void:
	if not _can_drop_on_entry(at_position, data, target_index):
		return
	var source_index: int = data[_DRAG_DATA_KEY]
	_entries[target_index] = [_entries[target_index][0], _entries[source_index][0]]
	_entries.remove_at(source_index)
	_rebuild_rows.call_deferred()

func _on_split_pressed(entry_index: int) -> void:
	var entry: Array = _entries[entry_index]
	_entries[entry_index] = [entry[0]]
	_entries.insert(entry_index + 1, [entry[1]])
	_rebuild_rows()

func _on_present_pressed(entry_index: int) -> void:
	if _session_controller == null:
		return
	var entry: Array = _entries[entry_index]
	if entry.size() == 2:
		_session_controller.submit_evidence_combination(entry[0], entry[1])
	else:
		_session_controller.present_evidence(entry[0])
