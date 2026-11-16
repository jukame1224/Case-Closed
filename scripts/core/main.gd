extends Control

@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _settings_dialog: AcceptDialog = %SettingsDialog
@onready var _exit_to_title_button: Button = %ExitToTitleButton
@onready var _next_button: Button = %NextButton
@onready var _status_label: Label = %StatusLabel
@onready var _interrogation_room: InterrogationRoom = %InterrogationRoom
@onready var _title_logo: TextureRect = %TitleLogo
@onready var _title_background: ColorRect = %Background
@onready var _title_background_image: TextureRect = %BackgroundImage
@onready var _stage_intro: Control = %StageIntro
@onready var _stage_intro_label: Label = %StageLabel
@onready var _title_music_player: AudioStreamPlayer = %TitleMusicPlayer
@onready var _interrogation_music_player: AudioStreamPlayer = %InterrogationMusicPlayer
@onready var _stage_intro_door_player: AudioStreamPlayer = %StageIntroDoorPlayer
@onready var _music_volume_slider: HSlider = %MusicVolumeSlider
@onready var _resolution_option_button: OptionButton = %ResolutionOptionButton
@onready var _fullscreen_checkbox: CheckBox = %FullscreenCheckBox

const _MUSIC_BUS_NAME := "Music"
const _RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]
const _STAGE_INTRO_DURATION_SECONDS := 3.5
const _STAGE_INTRO_LABEL_FADE_SECONDS := 0.5
const _STAGE_INTRO_LABEL_HOLD_SECONDS := 1.0
const _STAGE_INTRO_BACKGROUND_FADE_SECONDS := 1.0

var _game_manager: GameManager

func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_button_pressed)
	_continue_button.pressed.connect(_on_continue_button_pressed)
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)
	_exit_to_title_button.pressed.connect(_on_exit_to_title_button_pressed)
	_next_button.pressed.connect(_on_next_button_pressed)
	_music_volume_slider.value_changed.connect(_on_music_volume_slider_value_changed)
	_ensure_music_bus()
	_setup_resolution_settings()
	_continue_button.disabled = not SaveManager.has_save()
	_status_label.visible = false
	_title_music_player.play()

func _setup_resolution_settings() -> void:
	for preset in _RESOLUTION_PRESETS:
		_resolution_option_button.add_item("%d x %d" % [preset.x, preset.y])
	_resolution_option_button.item_selected.connect(_on_resolution_selected)
	_fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)

func _on_resolution_selected(index: int) -> void:
	_fullscreen_checkbox.button_pressed = false
	get_window().mode = Window.MODE_WINDOWED
	DisplayServer.window_set_size(_RESOLUTION_PRESETS[index])
	get_window().move_to_center()

func _on_fullscreen_toggled(enabled: bool) -> void:
	get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if enabled else Window.MODE_WINDOWED

func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index(_MUSIC_BUS_NAME) != -1:
		return
	var bus_index := AudioServer.bus_count
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, _MUSIC_BUS_NAME)
	AudioServer.set_bus_send(bus_index, "Master")

func _on_music_volume_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(_MUSIC_BUS_NAME), value / 100.0)

func _on_new_game_button_pressed() -> void:
	_hide_title_screen()
	_create_game_manager()
	_game_manager.start_game()

func _on_continue_button_pressed() -> void:
	_hide_title_screen()
	_create_game_manager()
	_game_manager.continue_saved_game()

func _on_settings_button_pressed() -> void:
	_exit_to_title_button.visible = false
	_settings_dialog.popup_centered()

func _unhandled_input(event: InputEvent) -> void:
	if _stage_intro.visible:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _settings_dialog.visible:
		_settings_dialog.hide()
	else:
		_exit_to_title_button.visible = _game_manager != null
		_settings_dialog.popup_centered()
	get_viewport().set_input_as_handled()

func _on_exit_to_title_button_pressed() -> void:
	_settings_dialog.hide()
	_game_manager.queue_free()
	_game_manager = null
	_interrogation_room.visible = false
	_next_button.visible = false
	_status_label.visible = false
	_show_title_screen()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _hide_title_screen() -> void:
	_new_game_button.visible = false
	_continue_button.visible = false
	_settings_button.visible = false
	_quit_button.visible = false
	_title_logo.visible = false
	_title_background.visible = false
	_title_background_image.visible = false
	_title_music_player.stop()

func _show_title_screen() -> void:
	_new_game_button.visible = true
	_continue_button.visible = true
	_continue_button.disabled = not SaveManager.has_save()
	_settings_button.visible = true
	_quit_button.visible = true
	_title_logo.visible = true
	_title_background.visible = true
	_title_background_image.visible = true
	_interrogation_music_player.stop()
	_title_music_player.play()

func _create_game_manager() -> void:
	_game_manager = GameManager.new()
	add_child(_game_manager)
	_game_manager.stage_started.connect(_on_stage_started)
	_game_manager.game_ended.connect(_on_game_ended)
	_game_manager.game_cleared.connect(_on_game_cleared)

func _on_stage_started(stage: int) -> void:
	var session := _game_manager.session_controller
	_interrogation_room.bind(session)
	_interrogation_room.visible = false
	_next_button.visible = false
	_status_label.visible = false
	_status_label.text = "스테이지 %d — %s" % [stage, session.suspect_config.suspect_name]
	_show_stage_intro(stage)

func _show_stage_intro(stage: int) -> void:
	_interrogation_music_player.stop()
	_stage_intro_door_player.play()
	_stage_intro_label.text = "STAGE %d" % stage
	_stage_intro.modulate.a = 1.0
	_stage_intro_label.modulate.a = 0.0
	_stage_intro.visible = true

	var black_hold_seconds := _STAGE_INTRO_DURATION_SECONDS - (
			_STAGE_INTRO_LABEL_FADE_SECONDS * 2.0
			+ _STAGE_INTRO_LABEL_HOLD_SECONDS
			+ _STAGE_INTRO_BACKGROUND_FADE_SECONDS
	)
	var tween := create_tween()
	tween.tween_property(_stage_intro_label, "modulate:a", 1.0, _STAGE_INTRO_LABEL_FADE_SECONDS)
	tween.tween_interval(_STAGE_INTRO_LABEL_HOLD_SECONDS)
	tween.tween_property(_stage_intro_label, "modulate:a", 0.0, _STAGE_INTRO_LABEL_FADE_SECONDS)
	tween.tween_interval(black_hold_seconds)
	tween.tween_callback(func():
		_interrogation_room.visible = true
		_interrogation_music_player.play()
		_interrogation_room.start_opening_statement()
	)
	tween.tween_property(_stage_intro, "modulate:a", 0.0, _STAGE_INTRO_BACKGROUND_FADE_SECONDS)
	tween.finished.connect(_on_stage_intro_tween_finished)

func _on_stage_intro_tween_finished() -> void:
	_stage_intro.visible = false

func _on_next_button_pressed() -> void:
	_next_button.visible = false
	_game_manager.continue_to_next_stage()

func _on_game_ended(is_success: bool) -> void:
	_interrogation_room.visible = false
	_interrogation_music_player.stop()
	_next_button.visible = true
	_status_label.visible = true
	if is_success:
		_status_label.text = "스테이지 %d 자백 받아냄! '다음'을 눌러 다음 스테이지로 진행하세요." % (_game_manager.current_stage - 1)
	else:
		_status_label.text = "심문 실패 — '다음'을 눌러 같은 용의자를 다시 심문하세요."

func _on_game_cleared() -> void:
	_interrogation_room.visible = false
	_interrogation_music_player.stop()
	_next_button.visible = false
	_status_label.visible = true
	_status_label.text = "게임 클리어! 9명의 용의자를 모두 자백시켰습니다."
