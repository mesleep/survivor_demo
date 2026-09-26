## 通用设置面板：声音开关 + 可选返回主菜单 / 重置存档 / 打开工作台。
##
## 输入：初始静音状态与是否处于单局内（单局内隐藏重置与工作台）。
## 输出：closed / return_to_menu_requested / mute_toggled / quit_requested /
##       reset_requested / tools_requested 信号。
## process_mode 为 ALWAYS，暂停时仍可点击。
class_name SettingsPanel
extends Control

signal closed
signal return_to_menu_requested
signal mute_toggled(muted: bool)
signal quit_requested
signal reset_requested
signal tools_requested

const BUTTON_NORMAL: StyleBox = preload("res://data/visuals/v2_dark_comic/menu_button_normal.tres")
const BUTTON_HOVER: StyleBox = preload("res://data/visuals/v2_dark_comic/menu_button_hover.tres")
const BUTTON_PRESSED: StyleBox = preload("res://data/visuals/v2_dark_comic/menu_button_pressed.tres")

@onready var _mute_button: Button = %MuteButton
@onready var _reset_button: Button = %ResetButton
@onready var _tools_button: Button = %ToolsButton
@onready var _return_button: Button = %ReturnButton
@onready var _close_button: Button = %CloseButton
@onready var _quit_button: Button = %QuitButton

var _muted: bool = false
var _reset_confirm: ConfirmationDialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for button: Button in [
		_mute_button, _reset_button, _tools_button, _return_button, _close_button, _quit_button
	]:
		button.add_theme_stylebox_override(&"normal", BUTTON_NORMAL)
		button.add_theme_stylebox_override(&"hover", BUTTON_HOVER)
		button.add_theme_stylebox_override(&"pressed", BUTTON_PRESSED)
		button.add_theme_stylebox_override(&"disabled", BUTTON_NORMAL)
	_mute_button.pressed.connect(_on_mute_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_tools_button.pressed.connect(_on_tools_pressed)
	_return_button.pressed.connect(_on_return_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_build_reset_confirm()
	visible = false


## 重置为危险操作，先弹确认框，避免误触清档。
func _build_reset_confirm() -> void:
	_reset_confirm = ConfirmationDialog.new()
	_reset_confirm.dialog_text = "确定重置存档吗？\n将清空金币、解锁与永久强化，恢复初始状态。"
	_reset_confirm.title = "重置存档"
	_reset_confirm.ok_button_text = "重置"
	_reset_confirm.cancel_button_text = "取消"
	_reset_confirm.confirmed.connect(_on_reset_confirmed)
	add_child(_reset_confirm)


## allow_return_to_menu 为 true 表示由单局暂停进入，此时隐藏重置与工作台。
func initialize(muted: bool, allow_return_to_menu: bool) -> void:
	_muted = muted
	_return_button.visible = allow_return_to_menu
	_reset_button.visible = not allow_return_to_menu
	_tools_button.visible = not allow_return_to_menu
	_refresh()


func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func get_muted() -> bool:
	return _muted


func _refresh() -> void:
	_mute_button.text = "声音：%s" % ("关" if _muted else "开")


func _on_mute_pressed() -> void:
	_muted = not _muted
	_refresh()
	mute_toggled.emit(_muted)


func _on_reset_pressed() -> void:
	_reset_confirm.popup_centered()


func _on_reset_confirmed() -> void:
	close()
	reset_requested.emit()


func _on_tools_pressed() -> void:
	close()
	tools_requested.emit()


func _on_return_pressed() -> void:
	visible = false
	return_to_menu_requested.emit()


func _on_close_pressed() -> void:
	close()


func _on_quit_pressed() -> void:
	quit_requested.emit()
