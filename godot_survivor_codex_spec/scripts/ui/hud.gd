## 单局 HUD，只将玩家信号转换为生命、等级和经验显示。
##
## 不计算经验阈值，也不直接修改任何游戏状态。
class_name HUD
extends Control

const BASE_LABEL_FONT_SIZE := 16
const BASE_BAR_SIZE := Vector2(300.0, 18.0)

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var level_label: Label = %LevelLabel
@onready var experience_bar: ProgressBar = %ExperienceBar
@onready var time_label: Label = %TimeLabel

var _player: PlayerActor


## 按统一倍率调整 HUD 字体和进度条，不改变游戏世界缩放。
func set_ui_scale(ui_scale: float) -> void:
	var safe_scale: float = clampf(ui_scale, 0.75, 2.0)
	var font_size: int = maxi(roundi(BASE_LABEL_FONT_SIZE * safe_scale), 1)
	health_label.add_theme_font_size_override("font_size", font_size)
	level_label.add_theme_font_size_override("font_size", font_size)
	time_label.add_theme_font_size_override("font_size", font_size)
	health_bar.custom_minimum_size = BASE_BAR_SIZE * safe_scale
	experience_bar.custom_minimum_size = BASE_BAR_SIZE * safe_scale


func initialize(player: PlayerActor) -> void:
	_disconnect_player()
	_player = player
	if not is_instance_valid(_player):
		return
	_player.health_component.health_changed.connect(_on_health_changed)
	_player.level_progress_changed.connect(_on_level_progress_changed)
	_on_health_changed(_player.health_component.current_health, _player.health_component.maximum_health)
	_on_level_progress_changed(
		_player.get_current_level(),
		_player.get_current_level_experience(),
		_player.get_required_experience()
	)


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maxf(maximum, 1.0)
	health_bar.value = current
	health_label.text = "HP %d / %d" % [roundi(current), roundi(maximum)]


func _on_level_progress_changed(level: int, current: int, required: int) -> void:
	level_label.text = "Level %d" % level
	experience_bar.max_value = maxi(required, 1)
	experience_bar.value = current


func update_remaining_time(remaining_seconds: float) -> void:
	var total_seconds: int = maxi(ceili(remaining_seconds), 0)
	time_label.text = "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _disconnect_player() -> void:
	if not is_instance_valid(_player):
		return
	if _player.health_component.health_changed.is_connected(_on_health_changed):
		_player.health_component.health_changed.disconnect(_on_health_changed)
	if _player.level_progress_changed.is_connected(_on_level_progress_changed):
		_player.level_progress_changed.disconnect(_on_level_progress_changed)
