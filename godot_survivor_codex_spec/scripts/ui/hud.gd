## 单局 HUD，只将玩家信号转换为生命、等级和经验显示。
##
## 不计算经验阈值，也不直接修改任何游戏状态。
class_name HUD
extends Control

const BASE_LABEL_FONT_SIZE := 16
const BASE_BAR_SIZE := Vector2(300.0, 18.0)
const BAR_TRACK: Texture2D = preload("res://assets/v2_dark_comic/ui/ui_progress_track.png")
const HEALTH_FILL: Texture2D = preload("res://assets/v2_dark_comic/ui/ui_progress_fill_health.png")
const XP_FILL: Texture2D = preload("res://assets/v2_dark_comic/ui/ui_progress_fill_xp.png")

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var level_label: Label = %LevelLabel
@onready var experience_bar: ProgressBar = %ExperienceBar
@onready var time_label: Label = %TimeLabel

var _player: PlayerActor


func _ready() -> void:
	_style_bar(health_bar, HEALTH_FILL)
	_style_bar(experience_bar, XP_FILL)
	for label: Label in [health_label, level_label, time_label]:
		label.add_theme_color_override("font_shadow_color", Color("142a32"))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)


func _style_bar(bar: ProgressBar, fill_texture: Texture2D) -> void:
	var background := StyleBoxTexture.new()
	background.texture = BAR_TRACK
	background.texture_margin_left = 20.0
	background.texture_margin_right = 20.0
	background.texture_margin_top = 8.0
	background.texture_margin_bottom = 8.0
	var fill := StyleBoxTexture.new()
	fill.texture = fill_texture
	fill.texture_margin_left = 12.0
	fill.texture_margin_right = 12.0
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)


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
	health_label.text = "生命 %d / %d" % [roundi(current), roundi(maximum)]


func _on_level_progress_changed(level: int, current: int, required: int) -> void:
	level_label.text = "等级 %d" % level
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
