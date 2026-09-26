## 数值/素材工作台 UI：左侧分类资源树，右侧按中文字段名编辑数值与替换素材。
##
## 输入：ConfigWorkbenchService 的分类/属性数据。
## 输出：closed 信号；改动即时写回内存资源，点“保存”才写回 .tres。
## 只作为开发工具，从主菜单设置面板打开；不参与正式玩法流程。
class_name ConfigWorkbench
extends Control

signal closed

const BUTTON_STYLE: StyleBox = preload("res://data/visuals/v2_dark_comic/button_style.tres")
const GOLD := Color(0.92, 0.85, 0.61)
const DIM := Color(0.66, 0.77, 0.82)
const FIELD_LABEL_WIDTH := 210

var _service: ConfigWorkbenchService
var _tree: Tree
var _path_label: Label
var _type_label: Label
var _status_label: Label
var _property_list: VBoxContainer
var _scroll: ScrollContainer
var _save_button: Button
var _reload_button: Button
var _back_button: Button
var _file_dialog: FileDialog
var _current: Resource
var _history: Array[Resource] = []
var _dirty: bool = false
var _pending_property: String = ""
var _pending_kind: String = ""


func _ready() -> void:
	_service = ConfigWorkbenchService.new()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_build_file_dialog()
	_build_tree()
	_show_empty_state()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- UI 构建

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.01, 0.015, 0.03, 0.92)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.028, 0.045, 0.08, 0.98)
	panel_style.border_color = Color(0.36, 0.57, 0.68, 0.85)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 18
	panel_style.content_margin_top = 16
	panel_style.content_margin_right = 18
	panel_style.content_margin_bottom = 16
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", panel_style)
	margin.add_child(panel)

	var body := HSplitContainer.new()
	body.split_offset = 320
	panel.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)

	var left_title := Label.new()
	left_title.text = "数值 / 素材分类"
	left_title.add_theme_font_size_override("font_size", 20)
	left_title.add_theme_color_override("font_color", GOLD)
	left.add_child(left_title)

	_tree = Tree.new()
	_tree.name = "CategoryTree"
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.allow_reselect = true
	_tree.item_selected.connect(_on_tree_item_selected)
	left.add_child(_tree)

	var left_hint := Label.new()
	left_hint.text = "点分类展开；点条目在右侧编辑。\n改数值即时生效，点“保存”写入 .tres。"
	left_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_hint.add_theme_font_size_override("font_size", 12)
	left_hint.add_theme_color_override("font_color", DIM)
	left.add_child(left_hint)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	right.add_child(header)

	_back_button = _make_button("← 返回")
	_back_button.custom_minimum_size = Vector2(90, 0)
	_back_button.pressed.connect(_on_back_pressed)
	header.add_child(_back_button)

	var header_text := VBoxContainer.new()
	header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_text.add_theme_constant_override("separation", 2)
	header.add_child(header_text)

	_path_label = Label.new()
	_path_label.add_theme_font_size_override("font_size", 16)
	_path_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	_path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_text.add_child(_path_label)

	_type_label = Label.new()
	_type_label.add_theme_font_size_override("font_size", 12)
	_type_label.add_theme_color_override("font_color", DIM)
	header_text.add_child(_type_label)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_scroll)

	_property_list = VBoxContainer.new()
	_property_list.name = "PropertyList"
	_property_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_property_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_property_list)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	right.add_child(footer)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", DIM)
	footer.add_child(_status_label)

	_reload_button = _make_button("放弃修改并重载")
	_reload_button.pressed.connect(_on_reload_pressed)
	footer.add_child(_reload_button)

	_save_button = _make_button("保存到文件")
	_save_button.name = "SaveButton"
	_save_button.pressed.connect(_on_save_pressed)
	footer.add_child(_save_button)

	var close_button := _make_button("关闭")
	close_button.pressed.connect(_on_close_pressed)
	footer.add_child(close_button)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		button.add_theme_stylebox_override(state, BUTTON_STYLE)
	button.add_theme_font_size_override("font_size", 15)
	return button


func _build_file_dialog() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.use_native_dialog = false
	_file_dialog.size = Vector2(900, 620)
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)


func _build_tree() -> void:
	var root: TreeItem = _tree.create_item()
	for category: Dictionary in _service.get_categories():
		var category_item: TreeItem = _tree.create_item(root)
		category_item.set_text(0, String(category["name"]))
		category_item.set_metadata(0, {"kind": "category", "category": String(category["id"])})
		category_item.set_selectable(0, true)
		category_item.collapsed = true
		for path: String in ConfigWorkbenchService.list_resource_paths(String(category["id"])):
			var resource: Resource = ConfigWorkbenchService.load_resource(path)
			var item_name: String = ConfigWorkbenchService.get_resource_display_name(resource, path)
			var resource_item: TreeItem = _tree.create_item(category_item)
			resource_item.set_text(0, item_name if not item_name.is_empty() else path.get_file())
			resource_item.set_tooltip_text(0, path)
			resource_item.set_metadata(0, {"kind": "resource", "path": path})


# ---------------------------------------------------------------- 交互

func _on_tree_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return
	var metadata: Dictionary = item.get_metadata(0)
	if String(metadata.get("kind", "")) != "resource":
		return
	var path: String = String(metadata.get("path", ""))
	var resource: Resource = ConfigWorkbenchService.load_resource(path)
	if resource == null:
		_set_status("无法加载：%s" % path, true)
		return
	_history.clear()
	_open_resource(resource)


func _open_resource(resource: Resource) -> void:
	_current = resource
	_dirty = false
	_show_current()


func _on_back_pressed() -> void:
	if _history.is_empty():
		return
	_current = _history.pop_back()
	_show_current()


func _on_save_pressed() -> void:
	if _current == null:
		return
	if _current.resource_path.is_empty():
		_set_status("内联子资源没有独立路径，请返回上层保存。", true)
		return
	var result: Error = ConfigWorkbenchService.save_resource(_current)
	if result == OK:
		_dirty = false
		_set_status("已保存：%s" % _current.resource_path, false)
	else:
		_set_status("保存失败（错误码 %d）：%s" % [result, _current.resource_path], true)


func _on_reload_pressed() -> void:
	if _current == null or _current.resource_path.is_empty():
		return
	var path: String = _current.resource_path
	var reloaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if reloaded == null:
		_set_status("重载失败：%s" % path, true)
		return
	_current = reloaded
	_dirty = false
	_show_current()
	_set_status("已从文件重载。", false)


func _on_close_pressed() -> void:
	closed.emit()


func _show_empty_state() -> void:
	_path_label.text = "请选择左侧分类与资源"
	_type_label.text = ""
	_set_status("", false)
	_clear_property_list()
	_back_button.disabled = true
	_save_button.disabled = true
	_reload_button.disabled = true


func _show_current() -> void:
	if _current == null:
		_show_empty_state()
		return
	var path: String = _current.resource_path if not _current.resource_path.is_empty() else "（内联子资源）"
	_path_label.text = ConfigWorkbenchService.get_resource_display_name(_current)
	_type_label.text = "%s ｜ %s" % [_current.get_class(), path]
	_back_button.disabled = _history.is_empty()
	_save_button.disabled = _current.resource_path.is_empty()
	_reload_button.disabled = _current.resource_path.is_empty()
	_rebuild_property_rows()
	_scroll.scroll_vertical = 0


func _set_status(text: String, is_error: bool) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override(
		"font_color", Color(0.95, 0.55, 0.5) if is_error else DIM
	)


# ---------------------------------------------------------------- 属性行

func _clear_property_list() -> void:
	for child: Node in _property_list.get_children():
		_property_list.remove_child(child)
		child.queue_free()


func _rebuild_property_rows() -> void:
	_clear_property_list()
	for row: Dictionary in ConfigWorkbenchService.collect_rows(_current):
		if String(row.get("kind", "")) == "group":
			_property_list.add_child(_make_group_row(String(row.get("label", ""))))
			continue
		var control: Control = _make_property_row(row)
		if control != null:
			_property_list.add_child(control)
	if _property_list.get_child_count() == 0:
		var note := Label.new()
		note.text = "该资源没有可在此编辑的字段；序列帧等复杂资源请在上层定义里更换引用。"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", 14)
		note.add_theme_color_override("font_color", DIM)
		_property_list.add_child(note)


func _make_group_row(title: String) -> Control:
	if title.is_empty():
		return HSeparator.new()
	var label := Label.new()
	label.text = "—— %s ——" % title
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", GOLD)
	return label


func _make_field_label(row: Dictionary) -> Label:
	var label := Label.new()
	label.text = String(row.get("label", row.get("name", "")))
	label.custom_minimum_size = Vector2(FIELD_LABEL_WIDTH, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.tooltip_text = String(row.get("comment", ""))
	return label


func _make_property_row(row: Dictionary) -> Control:
	if ConfigWorkbenchService.is_asset_row(row):
		return _make_asset_row(row)
	if ConfigWorkbenchService.is_resource_property(row):
		return _make_resource_row(row)
	match int(row.get("type", 0)):
		TYPE_BOOL:
			return _make_bool_row(row)
		TYPE_INT:
			if int(row.get("hint", 0)) == PROPERTY_HINT_ENUM:
				return _make_enum_row(row)
			return _make_number_row(row)
		TYPE_FLOAT:
			return _make_number_row(row)
		TYPE_STRING, TYPE_STRING_NAME:
			return _make_string_row(row)
		TYPE_COLOR:
			return _make_color_row(row)
		TYPE_VECTOR2:
			return _make_vector2_row(row)
		TYPE_ARRAY:
			return _make_array_row(row)
	return _make_readonly_row(row)


func _make_enum_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.add_child(_make_field_label(row))
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(220, 0)
	var options: PackedStringArray = String(row.get("hint_string", "")).split(",")
	var current_value: int = int(_current.get(String(row["name"])))
	for index: int in range(options.size()):
		option.add_item(options[index], index)
	option.selected = clampi(current_value, 0, maxi(options.size() - 1, 0))
	option.item_selected.connect(_on_enum_changed.bind(String(row["name"])))
	line.add_child(option)
	return line


func _make_bool_row(row: Dictionary) -> Control:
	var box := CheckBox.new()
	box.text = String(row.get("label", row.get("name", "")))
	box.tooltip_text = String(row.get("comment", ""))
	box.button_pressed = bool(_current.get(String(row["name"])))
	box.add_theme_font_size_override("font_size", 14)
	box.toggled.connect(_on_bool_changed.bind(String(row["name"])))
	return box


func _make_number_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.add_child(_make_field_label(row))
	var spin := SpinBox.new()
	spin.custom_minimum_size = Vector2(260, 0)
	spin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	spin.step = 0.01 if int(row["type"]) == TYPE_FLOAT else 1.0
	_apply_range_hint(spin, int(row.get("hint", 0)), String(row.get("hint_string", "")))
	var is_integer: bool = int(row["type"]) == TYPE_INT
	spin.value = float(_current.get(String(row["name"])))
	spin.value_changed.connect(_on_number_changed.bind(String(row["name"]), is_integer))
	line.add_child(spin)
	return line


func _make_string_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.add_child(_make_field_label(row))
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text = String(_current.get(String(row["name"])))
	edit.tooltip_text = String(row.get("comment", ""))
	var is_string_name: bool = int(row["type"]) == TYPE_STRING_NAME
	edit.text_changed.connect(_on_string_changed.bind(String(row["name"]), is_string_name))
	line.add_child(edit)
	return line


func _make_color_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.add_child(_make_field_label(row))
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(120, 34)
	picker.color = _current.get(String(row["name"]))
	picker.color_changed.connect(_on_color_changed.bind(String(row["name"])))
	line.add_child(picker)
	return line


func _make_vector2_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.add_child(_make_field_label(row))
	var current_value: Vector2 = _current.get(String(row["name"]))
	var x_spin := SpinBox.new()
	x_spin.min_value = -100000.0
	x_spin.max_value = 100000.0
	x_spin.step = 0.01
	x_spin.value = current_value.x
	line.add_child(x_spin)
	var y_spin := SpinBox.new()
	y_spin.min_value = -100000.0
	y_spin.max_value = 100000.0
	y_spin.step = 0.01
	y_spin.value = current_value.y
	line.add_child(y_spin)
	var setter := func(_value: float) -> void:
		var updated := Vector2(snappedf(x_spin.value, 0.001), snappedf(y_spin.value, 0.001))
		_current.set(String(row["name"]), updated)
		_mark_dirty()
	x_spin.value_changed.connect(setter)
	y_spin.value_changed.connect(setter)
	return line


func _make_array_row(row: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.add_child(_make_field_label(row))
	var raw_value: Variant = _current.get(String(row["name"]))
	if not (raw_value is Array):
		return _make_readonly_row(row)
	var value: Array = raw_value
	var count_label := Label.new()
	count_label.text = "%d 项" % value.size()
	count_label.add_theme_font_size_override("font_size", 14)
	line.add_child(count_label)
	box.add_child(line)
	for index: int in range(value.size()):
		var element: Variant = value[index]
		var element_line := HBoxContainer.new()
		element_line.add_theme_constant_override("separation", 10)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(FIELD_LABEL_WIDTH, 0)
		element_line.add_child(spacer)
		if element is Resource:
			var element_button := _make_button(
				"[%d] %s" % [index, ConfigWorkbenchService.get_resource_display_name(element)]
			)
			element_button.pressed.connect(_on_open_reference.bind(element))
			element_line.add_child(element_button)
		else:
			var value_label := Label.new()
			value_label.text = "[%d] %s" % [index, str(element)]
			value_label.add_theme_font_size_override("font_size", 13)
			value_label.add_theme_color_override("font_color", DIM)
			element_line.add_child(value_label)
		box.add_child(element_line)
	return box


func _make_readonly_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.add_child(_make_field_label(row))
	var value_label := Label.new()
	value_label.text = str(_current.get(String(row["name"])))
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", DIM)
	line.add_child(value_label)
	return line


func _make_asset_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.add_child(_make_field_label(row))
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(56, 56)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var value: Variant = _current.get(String(row["name"]))
	if value is SpriteFrames:
		preview.texture = _first_frame_texture(value)
	elif value is Texture2D:
		preview.texture = value
	line.add_child(preview)
	var path_label := Label.new()
	path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_label.add_theme_font_size_override("font_size", 12)
	path_label.add_theme_color_override("font_color", DIM)
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	path_label.text = "（未设置）" if value == null else (value as Resource).resource_path
	line.add_child(path_label)
	var replace_button := _make_button("更换素材")
	replace_button.pressed.connect(_on_replace_asset_pressed.bind(row))
	line.add_child(replace_button)
	if value != null:
		var open_button := _make_button("打开")
		open_button.pressed.connect(_on_open_reference.bind(value))
		line.add_child(open_button)
	var clear_button := _make_button("清除")
	clear_button.pressed.connect(_on_clear_property.bind(String(row["name"])))
	line.add_child(clear_button)
	return line


func _make_resource_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.add_child(_make_field_label(row))
	var value: Variant = _current.get(String(row["name"]))
	var path_label := Label.new()
	path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_label.add_theme_font_size_override("font_size", 12)
	path_label.add_theme_color_override("font_color", DIM)
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	path_label.text = "（未设置）" if value == null else (value as Resource).resource_path
	line.add_child(path_label)
	if value != null:
		var edit_button := _make_button("编辑")
		edit_button.pressed.connect(_on_open_reference.bind(value))
		line.add_child(edit_button)
	var replace_button := _make_button("更换引用")
	replace_button.pressed.connect(_on_replace_asset_pressed.bind(row))
	line.add_child(replace_button)
	var clear_button := _make_button("清除")
	clear_button.pressed.connect(_on_clear_property.bind(String(row["name"])))
	line.add_child(clear_button)
	return line


# ---------------------------------------------------------------- 数值回调

func _apply_range_hint(spin: SpinBox, hint: int, hint_string: String) -> void:
	var allow_greater: bool = hint_string.contains("or_greater")
	var parts: PackedStringArray = hint_string.split(",")
	if hint == PROPERTY_HINT_RANGE and not parts.is_empty():
		if parts.size() >= 1 and parts[0].is_valid_float():
			spin.min_value = parts[0].to_float()
		if parts.size() >= 2 and parts[1].is_valid_float() and not allow_greater:
			spin.max_value = parts[1].to_float()
		if parts.size() >= 3 and parts[2].is_valid_float():
			spin.step = parts[2].to_float()
	if not allow_greater:
		spin.max_value = maxf(spin.max_value, spin.min_value)
	else:
		spin.max_value = 1000000000.0


func _mark_dirty() -> void:
	_dirty = true
	_set_status("有未保存修改（改动即时生效）", false)


func _on_number_changed(value: float, property_name: String, is_integer: bool) -> void:
	_current.set(property_name, int(round(value)) if is_integer else value)
	_mark_dirty()


func _on_bool_changed(pressed: bool, property_name: String) -> void:
	_current.set(property_name, pressed)
	_mark_dirty()


func _on_string_changed(text: String, property_name: String, is_string_name: bool) -> void:
	_current.set(property_name, StringName(text) if is_string_name else text)
	_mark_dirty()


func _on_enum_changed(index: int, property_name: String) -> void:
	_current.set(property_name, index)
	_mark_dirty()


func _on_color_changed(color: Color, property_name: String) -> void:
	_current.set(property_name, color)
	_mark_dirty()


func _on_clear_property(property_name: String) -> void:
	_current.set(property_name, null)
	_mark_dirty()
	_show_current()


func _on_open_reference(reference: Resource) -> void:
	if reference == null:
		return
	if _current != null:
		_history.append(_current)
	_current = reference
	_dirty = false
	_show_current()


# ---------------------------------------------------------------- 素材替换

func _on_replace_asset_pressed(row: Dictionary) -> void:
	_pending_property = String(row["name"])
	_pending_kind = "asset"
	_file_dialog.title = "选择新的素材"
	_file_dialog.filters = PackedStringArray(["*.png,*.svg,*.jpg,*.webp ; 图片素材", "*.tres,*.tscn ; 资源文件"])
	if ConfigWorkbenchService.is_sprite_frames_property(row):
		_file_dialog.title = "选择新的 SpriteFrames"
		_file_dialog.filters = PackedStringArray(["*.tres ; 序列帧资源"])
	elif ConfigWorkbenchService.is_resource_property(row):
		var class_name_text: String = ConfigWorkbenchService.resource_class_of(row)
		_pending_kind = "resource"
		_file_dialog.title = "选择新的 %s" % (class_name_text if not class_name_text.is_empty() else "资源")
		_file_dialog.filters = PackedStringArray(["*.tres ; 资源文件", "*.tscn ; 场景文件"])
	_file_dialog.popup_centered()


func _on_file_selected(path: String) -> void:
	if _current == null or _pending_property.is_empty():
		return
	var loaded: Resource = load(path)
	if loaded == null:
		_set_status("无法加载：%s" % path, true)
		return
	_current.set(_pending_property, loaded)
	_pending_property = ""
	_mark_dirty()
	_show_current()


func _first_frame_texture(frames: SpriteFrames) -> Texture2D:
	if frames == null:
		return null
	for animation_name: StringName in frames.get_animation_names():
		if frames.get_frame_count(animation_name) > 0:
			return frames.get_frame_texture(animation_name, 0)
	return null
