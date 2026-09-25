## 通用设置面板：声音开关 + 可选返回主菜单。
##
## 输入：初始静音状态与是否允许返回主菜单。
## 输出：closed / return_to_menu_requested / mute_toggled 信号。
## process_mode 为 ALWAYS，暂停时仍可点击。
class_name SettingsPanel
extends Control

signal closed
signal return_to_menu_requested
signal mute_toggled(muted: bool)
signal quit_requested

const BUTTON_NORMAL: StyleBox = preload("res://data/visuals/v2_dark_comic/menu_button_normal.tres")
const BUTTON_HOVER: StyleBox = preload("res://data/visuals/v2_dark_comic/menu_button_hover.tres")
const BUTTON_PRESSED: StyleBox = preload("res://data/visuals/v2_dark_comic/menu_button_pressed.tres")

@onready var _mute_button: Button = %MuteButton
@onready var _return_button: Button = %ReturnButton
@onready var _close_button: Button = %CloseButton
@onready var _quit_button: Button = %QuitButton

var _muted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for button: Button in [_mute_button, _return_button, _close_button, _quit_button]:
		button.add_theme_stylebox_override(&"normal", BUTTON_NORMAL)
		button.add_theme_stylebox_override(&"hover", BUTTON_HOVER)
		button.add_theme_stylebox_override(&"pressed", BUTTON_PRESSED)
		button.add_theme_stylebox_override(&"disabled", BUTTON_NORMAL)
	_mute_button.pressed.connect(_on_mute_pressed)
	_return_button.pressed.connect(_on_return_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	visible = false


func initialize(muted: bool, allow_return_to_menu: bool) -> void:
	_muted = muted
	_return_button.visible = allow_return_to_menu
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


func _on_return_pressed() -> void:
	visible = false
	return_to_menu_requested.emit()


func _on_close_pressed() -> void:
	close()


func _on_quit_pressed() -> void:
	quit_requested.emit()
