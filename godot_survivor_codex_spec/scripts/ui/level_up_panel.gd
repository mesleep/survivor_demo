## 暂停态升级选择面板。
##
## 只展示 UpgradeSystem 发布的定义并提交一次选择，不直接访问玩家内部节点。
class_name LevelUpPanel
extends Control

const BASE_BUTTON_SIZE := Vector2(420.0, 64.0)
const BASE_BUTTON_FONT_SIZE := 16
const BASE_TITLE_FONT_SIZE := 24
const BASE_PANEL_MARGIN := 24
const BASE_CARD_HEIGHT := 86.0
const BASE_ICON_SIZE := 52.0
const BASE_DESC_FONT_SIZE := 13
const BUTTON_STYLE: StyleBox = preload("res://data/visuals/v2_dark_comic/button_style.tres")

@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var title: Label = %Title
@onready var panel_margin: MarginContainer = %MarginContainer

var _upgrade_system: UpgradeSystem
var _accepting_input: bool = false
var _ui_scale: float = 1.0
var _refresh_button: Button


## 调整居中面板内部控件尺寸，保持全屏根节点和居中锚点不受缩放影响。
func set_ui_scale(ui_scale: float) -> void:
	_ui_scale = clampf(ui_scale, 0.75, 2.0)
	title.add_theme_font_size_override("font_size", maxi(roundi(BASE_TITLE_FONT_SIZE * _ui_scale), 1))
	var margin_size: int = maxi(roundi(BASE_PANEL_MARGIN * _ui_scale), 1)
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		panel_margin.add_theme_constant_override(side, margin_size)
	if is_instance_valid(_refresh_button):
		_refresh_button.custom_minimum_size = BASE_BUTTON_SIZE * _ui_scale
		_refresh_button.add_theme_font_size_override("font_size", maxi(roundi(BASE_BUTTON_FONT_SIZE * _ui_scale), 1))


func initialize(upgrade_system: UpgradeSystem) -> void:
	_disconnect_system()
	_upgrade_system = upgrade_system
	if is_instance_valid(_upgrade_system):
		_upgrade_system.choices_ready.connect(show_choices)
	_ensure_refresh_button()
	hide_panel()


## 刷新按钮放在卡列表下方，切换升级时不被 _clear_buttons 清除（T28）。
func _ensure_refresh_button() -> void:
	if is_instance_valid(_refresh_button):
		return
	_refresh_button = Button.new()
	_refresh_button.text = "刷新"
	_refresh_button.custom_minimum_size = BASE_BUTTON_SIZE * _ui_scale
	_refresh_button.add_theme_font_size_override("font_size", maxi(roundi(BASE_BUTTON_FONT_SIZE * _ui_scale), 1))
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		_refresh_button.add_theme_stylebox_override(state, BUTTON_STYLE)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	choices_container.get_parent().add_child(_refresh_button)


func show_choices(choices: Array[UpgradeDefinition]) -> void:
	_clear_buttons()
	_accepting_input = not choices.is_empty()
	visible = _accepting_input
	for definition: UpgradeDefinition in choices:
		choices_container.add_child(_make_choice_button(definition))
	_update_refresh_button()
	if choices_container.get_child_count() > 0:
		(choices_container.get_child(0) as Button).grab_focus()


## 自绘卡面：图标 + 标题（分类前缀）+ 描述，避免 Button.icon 与多行文本混排错位。
func _make_choice_button(definition: UpgradeDefinition) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(BASE_BUTTON_SIZE.x, BASE_CARD_HEIGHT) * _ui_scale
	button.text = ""
	button.clip_text = false
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		button.add_theme_stylebox_override(state, BUTTON_STYLE)
	button.pressed.connect(_on_choice_pressed.bind(definition))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset: int = maxi(roundi(14.0 * _ui_scale), 1)
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, inset)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", maxi(roundi(12.0 * _ui_scale), 1))
	margin.add_child(row)

	if definition.icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = definition.icon
		icon_rect.custom_minimum_size = Vector2(BASE_ICON_SIZE, BASE_ICON_SIZE) * _ui_scale
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_rect)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)

	var title_label := Label.new()
	title_label.text = "%s%s" % [_category_tag(definition.category), definition.display_name]
	title_label.add_theme_font_size_override("font_size", maxi(roundi(BASE_BUTTON_FONT_SIZE * _ui_scale), 1))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = definition.description
	desc_label.add_theme_font_size_override("font_size", maxi(roundi(BASE_DESC_FONT_SIZE * _ui_scale), 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(desc_label)
	return button


func _update_refresh_button() -> void:
	if not is_instance_valid(_refresh_button):
		return
	var awaiting: bool = is_instance_valid(_upgrade_system) and _upgrade_system.is_awaiting_choice()
	_refresh_button.visible = awaiting
	_refresh_button.disabled = not (awaiting and _upgrade_system.can_refresh())
	_refresh_button.text = "刷新（剩余 %d）" % (
		_upgrade_system.get_remaining_refreshes() if is_instance_valid(_upgrade_system) else 0
	)


func _on_refresh_pressed() -> void:
	if not is_instance_valid(_upgrade_system):
		return
	_upgrade_system.refresh_choices()


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


## 卡面前缀：让玩家区分通用、获取、基础、质变与质变专属。
func _category_tag(category: UpgradeDefinition.UpgradeCategory) -> String:
	match category:
		UpgradeDefinition.UpgradeCategory.ACQUIRE_EQUIPMENT:
			return "【获取】"
		UpgradeDefinition.UpgradeCategory.BASE_UPGRADE:
			return "【基础】"
		UpgradeDefinition.UpgradeCategory.ASCENSION:
			return "【质变】"
		UpgradeDefinition.UpgradeCategory.BRANCH_UPGRADE:
			return "【专属】"
		_:
			return ""


func _disconnect_system() -> void:
	if is_instance_valid(_upgrade_system) and _upgrade_system.choices_ready.is_connected(show_choices):
		_upgrade_system.choices_ready.disconnect(show_choices)
