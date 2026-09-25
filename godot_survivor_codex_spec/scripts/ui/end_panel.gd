## 单局结算面板，只显示 GameResult 并发布重开请求。
class_name EndPanel
extends Control

signal restart_requested

const BASE_TITLE_FONT_SIZE := 36
const BASE_BODY_FONT_SIZE := 20
const BASE_BUTTON_SIZE := Vector2(280.0, 56.0)

@onready var title: Label = %Title
@onready var stats_label: Label = %StatsLabel
@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	if not restart_button.pressed.is_connected(_on_restart_button_pressed):
		restart_button.pressed.connect(_on_restart_button_pressed)
	hide_panel()


func set_ui_scale(ui_scale: float) -> void:
	var safe_scale: float = clampf(ui_scale, 0.75, 2.0)
	title.add_theme_font_size_override("font_size", maxi(roundi(BASE_TITLE_FONT_SIZE * safe_scale), 1))
	stats_label.add_theme_font_size_override("font_size", maxi(roundi(BASE_BODY_FONT_SIZE * safe_scale), 1))
	restart_button.add_theme_font_size_override("font_size", maxi(roundi(BASE_BODY_FONT_SIZE * safe_scale), 1))
	restart_button.custom_minimum_size = BASE_BUTTON_SIZE * safe_scale


func show_result(result: GameResult) -> void:
	if result == null:
		return
	title.text = "庭院守护成功" if result.outcome == GameResult.Outcome.VICTORY else "休息一下，再来一局"
	stats_label.text = "生存时间  %s\n等级  %d\n击退数量  %d\n金币  %d（拾取 %d + 击退 %d）" % [
		_format_time(result.elapsed_seconds),
		result.level,
		result.kill_count,
		result.total_coins,
		result.coins_collected,
		result.coins_from_kills,
	]
	restart_button.disabled = false
	visible = true


func hide_panel() -> void:
	visible = false
	restart_button.disabled = false


func _on_restart_button_pressed() -> void:
	if restart_button.disabled:
		return
	restart_button.disabled = true
	restart_requested.emit()


func _format_time(seconds: float) -> String:
	var total_seconds: int = maxi(floori(seconds), 0)
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
