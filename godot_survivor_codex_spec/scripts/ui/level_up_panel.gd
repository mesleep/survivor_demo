## 暂停态升级选择面板。
##
## 只展示 UpgradeSystem 发布的定义并提交一次选择，不直接访问玩家内部节点。
class_name LevelUpPanel
extends Control

const BASE_BUTTON_SIZE := Vector2(420.0, 64.0)
const BASE_BUTTON_FONT_SIZE := 16
const BASE_TITLE_FONT_SIZE := 24
const BASE_PANEL_MARGIN := 24
const BUTTON_STYLE: StyleBox = preload("res://data/visuals/v2_dark_comic/button_style.tres")

@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var title: Label = %Title
@onready var panel_margin: MarginContainer = %MarginContainer

var _upgrade_system: UpgradeSystem
var _accepting_input: bool = false
var _ui_scale: float = 1.0


## 调整居中面板内部控件尺寸，保持全屏根节点和居中锚点不受缩放影响。
func set_ui_scale(ui_scale: float) -> void:
	_ui_scale = clampf(ui_scale, 0.75, 2.0)
	title.add_theme_font_size_override("font_size", maxi(roundi(BASE_TITLE_FONT_SIZE * _ui_scale), 1))
	var margin_size: int = maxi(roundi(BASE_PANEL_MARGIN * _ui_scale), 1)
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		panel_margin.add_theme_constant_override(side, margin_size)


func initialize(upgrade_system: UpgradeSystem) -> void:
	_disconnect_system()
	_upgrade_system = upgrade_system
	if is_instance_valid(_upgrade_system):
		_upgrade_system.choices_ready.connect(show_choices)
	hide_panel()


func show_choices(choices: Array[UpgradeDefinition]) -> void:
	_clear_buttons()
	_accepting_input = not choices.is_empty()
	visible = _accepting_input
	for definition: UpgradeDefinition in choices:
		var button := Button.new()
		button.custom_minimum_size = BASE_BUTTON_SIZE * _ui_scale
		button.add_theme_font_size_override("font_size", maxi(roundi(BASE_BUTTON_FONT_SIZE * _ui_scale), 1))
		for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
			button.add_theme_stylebox_override(state, BUTTON_STYLE)
		button.text = "%s\n%s" % [definition.display_name, definition.description]
		button.pressed.connect(_on_choice_pressed.bind(definition))
		choices_container.add_child(button)
	if choices_container.get_child_count() > 0:
		(choices_container.get_child(0) as Button).grab_focus()


func hide_panel() -> void:
	_accepting_input = false
	visible = false
	_clear_buttons()


func _on_choice_pressed(definition: UpgradeDefinition) -> void:
	if not _accepting_input or not is_instance_valid(_upgrade_system):
		return
	_accepting_input = false
	_set_buttons_disabled(true)
	if not _upgrade_system.apply_choice(definition):
		_accepting_input = true
		_set_buttons_disabled(false)


func _set_buttons_disabled(disabled: bool) -> void:
	for child: Node in choices_container.get_children():
		if child is Button:
			(child as Button).disabled = disabled


func _clear_buttons() -> void:
	for child: Node in choices_container.get_children():
		choices_container.remove_child(child)
		child.queue_free()


func _disconnect_system() -> void:
	if is_instance_valid(_upgrade_system) and _upgrade_system.choices_ready.is_connected(show_choices):
		_upgrade_system.choices_ready.disconnect(show_choices)
