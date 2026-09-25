## 主菜单：选择角色与候选武器，生成单局配置快照后请求开始。
##
## 只发出 `start_requested(loadout)`，不持有 GameSession 或玩家节点，也不读写存档。
## 在 T29 正式解锁前，目录内全部内容视为可用；候选池规则为 D01。
class_name MainMenu
extends Control

signal start_requested(loadout: RunLoadout)

@export var catalog: ContentCatalog

@onready var character_container: VBoxContainer = %CharacterContainer
@onready var weapon_container: VBoxContainer = %WeaponContainer
@onready var hint_label: Label = %HintLabel
@onready var start_button: Button = %StartButton

var _character_id: StringName = &""
var _selected_weapon_ids: Array[StringName] = []
var _character_buttons: Dictionary[StringName, Button] = {}
var _weapon_buttons: Dictionary[StringName, Button] = {}
var _pending_loadout: RunLoadout
var _start_locked: bool = false
var _status_text: String = ""


func _ready() -> void:
	start_button.pressed.connect(request_start)
	_build()


## 由入口在入树前或入树后注入目录；会重建选项。
func initialize(new_catalog: ContentCatalog) -> void:
	catalog = new_catalog
	if is_inside_tree():
		_build()


## 设置存档/加载状态提示（T27）；为空则清除。
func set_status(text: String) -> void:
	_status_text = text
	if is_inside_tree():
		_update_hint()


func get_status() -> String:
	return _status_text


## 记住上次配置，下次打开菜单时预选；只复制 ID，不影响原对象。
func preselect(loadout: RunLoadout) -> void:
	_pending_loadout = loadout.copy() if loadout != null else null


## 选择角色并自动补全其起始武器；未知 ID 返回 false。
func select_character(character_id: StringName) -> bool:
	if not is_instance_valid(catalog) or catalog.get_character(character_id) == null:
		return false
	_character_id = character_id
	if _character_buttons.has(character_id):
		_character_buttons[character_id].button_pressed = true
	for weapon_id: StringName in _starting_weapon_ids():
		if not _selected_weapon_ids.has(weapon_id):
			_selected_weapon_ids.append(weapon_id)
	_sync_weapon_buttons()
	_update_hint()
	return true


## 设置某把候选武器的选中状态；起始武器不可取消，超过上限会被拒绝。
func set_weapon_selected(weapon_id: StringName, selected: bool) -> bool:
	if not _weapon_buttons.has(weapon_id):
		return false
	if selected:
		if not _selected_weapon_ids.has(weapon_id):
			if _selected_weapon_ids.size() >= RunLoadout.MAX_CANDIDATE_WEAPONS:
				_sync_weapon_buttons()
				hint_label.text = "候选武器最多 %d 个。" % RunLoadout.MAX_CANDIDATE_WEAPONS
				return false
			_selected_weapon_ids.append(weapon_id)
	else:
		if _is_starting_weapon(weapon_id):
			_sync_weapon_buttons()
			hint_label.text = "起始武器必须保留在候选池中。"
			return false
		_selected_weapon_ids.erase(weapon_id)
	_sync_weapon_buttons()
	_update_hint()
	return true


func is_weapon_selected(weapon_id: StringName) -> bool:
	return _selected_weapon_ids.has(weapon_id)


func get_selected_weapon_ids() -> Array[StringName]:
	return _selected_weapon_ids.duplicate()


func get_character_id() -> StringName:
	return _character_id


func get_selected_loadout() -> RunLoadout:
	return RunLoadout.new(_character_id, _selected_weapon_ids, _starting_weapon_ids())


## 校验当前选择；有效时锁定按钮并发出 start_requested，无效时只更新提示。
func request_start() -> bool:
	if _start_locked or not is_instance_valid(catalog):
		return false
	var loadout: RunLoadout = get_selected_loadout()
	var errors: Array[String] = loadout.validate(catalog)
	if not errors.is_empty():
		hint_label.text = errors[0]
		return false
	_start_locked = true
	start_button.disabled = true
	start_requested.emit(loadout)
	return true


func _on_character_pressed(character_id: StringName) -> void:
	select_character(character_id)


func _on_weapon_pressed(weapon_id: StringName) -> void:
	var button: Button = _weapon_buttons.get(weapon_id)
	if button == null:
		return
	set_weapon_selected(weapon_id, button.button_pressed)


func _build() -> void:
	_clear_containers()
	_character_buttons.clear()
	_weapon_buttons.clear()
	_character_id = &""
	_selected_weapon_ids.clear()
	_start_locked = false
	start_button.disabled = false
	if not is_instance_valid(catalog):
		hint_label.text = "缺少内容目录，无法开局。"
		start_button.disabled = true
		return
	var catalog_errors: Array[String] = catalog.validate()
	if not catalog_errors.is_empty():
		hint_label.text = "内容目录错误：%s" % catalog_errors[0]
		start_button.disabled = true
		return
	if catalog.characters.is_empty():
		hint_label.text = "没有可用角色。"
		start_button.disabled = true
		return

	var default_loadout: RunLoadout = RunLoadout.default_for(catalog)
	var has_preselect: bool = (
		_pending_loadout != null
		and catalog.get_character(_pending_loadout.character_id) != null
	)
	if has_preselect:
		default_loadout = _pending_loadout

	var group := ButtonGroup.new()
	for character: CharacterDefinition in catalog.characters:
		var button := Button.new()
		button.text = character.display_name
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_on_character_pressed.bind(character.id))
		character_container.add_child(button)
		_character_buttons[character.id] = button

	for weapon: WeaponDefinition in catalog.weapons:
		var button := Button.new()
		button.text = weapon.display_name
		button.toggle_mode = true
		button.pressed.connect(_on_weapon_pressed.bind(weapon.id))
		weapon_container.add_child(button)
		_weapon_buttons[weapon.id] = button

	var start_character_id: StringName = default_loadout.character_id
	if start_character_id == StringName() or not _character_buttons.has(start_character_id):
		start_character_id = catalog.characters[0].id
	select_character(start_character_id)

	_selected_weapon_ids.clear()
	for weapon_id: StringName in default_loadout.candidate_weapon_ids:
		if _weapon_buttons.has(weapon_id):
			_selected_weapon_ids.append(weapon_id)
	for weapon_id: StringName in _starting_weapon_ids():
		if not _selected_weapon_ids.has(weapon_id):
			_selected_weapon_ids.append(weapon_id)
	_sync_weapon_buttons()
	_update_hint()


func _starting_weapon_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if not is_instance_valid(catalog):
		return ids
	var character: CharacterDefinition = catalog.get_character(_character_id)
	if character == null:
		return ids
	for weapon: WeaponDefinition in character.starting_weapons:
		if weapon != null and not ids.has(weapon.id):
			ids.append(weapon.id)
	return ids


func _is_starting_weapon(weapon_id: StringName) -> bool:
	return _starting_weapon_ids().has(weapon_id)


func _sync_weapon_buttons() -> void:
	for weapon_id: StringName in _weapon_buttons.keys():
		_weapon_buttons[weapon_id].button_pressed = _selected_weapon_ids.has(weapon_id)


func _update_hint() -> void:
	var character: CharacterDefinition = null
	if is_instance_valid(catalog):
		character = catalog.get_character(_character_id)
	var character_name: String = character.display_name if character != null else "未选择"
	hint_label.text = "角色：%s ｜ 候选武器 %d/%d（起始武器自动保留）" % [
		character_name, _selected_weapon_ids.size(), RunLoadout.MAX_CANDIDATE_WEAPONS
	]
	if not _status_text.is_empty():
		hint_label.text += "\n%s" % _status_text


func _clear_containers() -> void:
	for container: VBoxContainer in [character_container, weapon_container]:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.queue_free()
