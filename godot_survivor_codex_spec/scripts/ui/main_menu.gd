## 主菜单：选择角色与候选武器，生成单局配置快照后请求开始。
##
## 只发出 `start_requested(loadout)`，不持有 GameSession 或玩家节点，也不读写存档。
## 在 T29 正式解锁前，目录内全部内容视为可用；候选池规则为 D01。
class_name MainMenu
extends Control

signal start_requested(loadout: RunLoadout)

const BUTTON_NORMAL: StyleBox = preload("res://data/visuals/v2_dark_comic/menu_button_normal.tres")
const BUTTON_HOVER: StyleBox = preload("res://data/visuals/v2_dark_comic/menu_button_hover.tres")
const BUTTON_PRESSED: StyleBox = preload("res://data/visuals/v2_dark_comic/menu_button_pressed.tres")
const TAB_STYLE: StyleBox = preload("res://data/visuals/v2_dark_comic/menu_tab_style.tres")

@export var catalog: ContentCatalog

## 跨局档案与解锁服务（T29）；为空时视为全部可用，保持旧直启兼容。
var profile: Profile
var unlock_service: UnlockService
## 永久强化目录（T30）。
var permanent_catalog: PermanentUpgradeCatalog
@onready var _permanent_container: VBoxContainer = %PermanentContainer

@onready var character_container: VBoxContainer = %CharacterContainer
@onready var weapon_container: VBoxContainer = %WeaponContainer
@onready var map_container: HBoxContainer = %MapContainer
@onready var hint_label: Label = %HintLabel
@onready var start_button: Button = %StartButton
@onready var unlock_all_button: Button = %UnlockAllButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

var _character_id: StringName = &""
var _selected_weapon_ids: Array[StringName] = []
var _map_id: StringName = &""
var _character_buttons: Dictionary[StringName, Button] = {}
var _weapon_buttons: Dictionary[StringName, Button] = {}
var _map_buttons: Dictionary[StringName, Button] = {}
var _pending_loadout: RunLoadout
var _start_locked: bool = false
var _status_text: String = ""
var _settings_panel: SettingsPanel
var _menu_muted: bool = false


func _ready() -> void:
	start_button.pressed.connect(request_start)
	unlock_all_button.pressed.connect(_on_unlock_all_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_style_button(start_button)
	_style_button(unlock_all_button)
	_style_button(settings_button)
	_style_button(quit_button)
	_build()


func _on_quit_pressed() -> void:
	get_tree().quit()


## 主菜单设置：声音开关（进入单局时应用）。
func _on_settings_pressed() -> void:
	if not is_instance_valid(_settings_panel):
		_settings_panel = (load("res://scenes/ui/settings_panel.tscn") as PackedScene).instantiate() as SettingsPanel
		add_child(_settings_panel)
		_settings_panel.initialize(_menu_muted, false)
		_settings_panel.mute_toggled.connect(_on_menu_mute_toggled)
		_settings_panel.quit_requested.connect(_on_quit_pressed)
	_settings_panel.open()


func _on_menu_mute_toggled(muted: bool) -> void:
	_menu_muted = muted


func get_preferred_muted() -> bool:
	return _menu_muted


## 统一按钮样式；动态生成的按钮都走这里（T34 界面收口）。
func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override(&"normal", BUTTON_NORMAL)
	button.add_theme_stylebox_override(&"hover", BUTTON_HOVER)
	button.add_theme_stylebox_override(&"pressed", BUTTON_PRESSED)
	button.add_theme_stylebox_override(&"disabled", BUTTON_NORMAL)
	button.add_theme_color_override(&"font_color", Color(0.91, 0.96, 1.0))
	button.add_theme_color_override(&"font_hover_color", Color.WHITE)
	button.add_theme_color_override(&"font_pressed_color", Color.WHITE)
	button.add_theme_font_size_override(&"font_size", 17)


## 由入口在入树前或入树后注入目录；会重建选项。
func initialize(new_catalog: ContentCatalog) -> void:
	catalog = new_catalog
	if is_inside_tree():
		_build()


## 注入档案与解锁服务（T29）；会重建选项以显示锁定/可买/已解锁。
func configure_profile(
		new_profile: Profile,
		new_unlock_service: UnlockService,
		new_permanent_catalog: PermanentUpgradeCatalog = null
) -> void:
	profile = new_profile
	unlock_service = new_unlock_service
	permanent_catalog = new_permanent_catalog
	if is_inside_tree():
		_build()


func _is_character_available(character_id: StringName) -> bool:
	return profile == null or profile.is_character_unlocked(character_id)


func _is_weapon_available(weapon_id: StringName) -> bool:
	return profile == null or profile.is_weapon_unlocked(weapon_id)


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
	if not _is_character_available(character_id):
		return false
	_character_id = character_id
	_sync_character_buttons()
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
	if selected and not _is_weapon_available(weapon_id):
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


func get_map_id() -> StringName:
	return _map_id


## 选择本局地图；未知 ID 返回 false。
func select_map(map_id: StringName) -> bool:
	if not is_instance_valid(catalog) or catalog.get_map(map_id) == null:
		return false
	_map_id = map_id
	_sync_map_buttons()
	_update_hint()
	return true


func get_selected_loadout() -> RunLoadout:
	return RunLoadout.new(_character_id, _selected_weapon_ids, _starting_weapon_ids(), _map_id)


## 校验当前选择；有效时锁定按钮并发出 start_requested，无效时只更新提示。
func request_start() -> bool:
	if _start_locked or not is_instance_valid(catalog):
		return false
	if not _selection_unlocked():
		hint_label.text = "所选角色或武器尚未解锁。"
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
	if not _is_character_available(character_id):
		_attempt_purchase(character_id, true)
		return
	select_character(character_id)


func _on_weapon_pressed(weapon_id: StringName) -> void:
	var button: Button = _weapon_buttons.get(weapon_id)
	if button == null:
		return
	if not _is_weapon_available(weapon_id):
		_attempt_purchase(weapon_id, false)
		return
	set_weapon_selected(weapon_id, button.button_pressed)


## 同一交易入口：校验 ID/重复/余额并写档；失败回滚并提示（T29）。
func _attempt_purchase(content_id: StringName, is_character: bool) -> void:
	if unlock_service == null or not is_instance_valid(catalog):
		return
	var result: UnlockService.Result = (
		unlock_service.purchase_character(catalog, content_id)
		if is_character
		else unlock_service.purchase_weapon(catalog, content_id)
	)
	match result:
		UnlockService.Result.SUCCESS:
			_rebuild_preserving_selection(content_id, is_character)
			_status_text = "已解锁：%s" % _display_name_of(content_id, is_character)
		UnlockService.Result.INSUFFICIENT_COINS:
			_status_text = "金币不足，无法解锁 %s。" % _display_name_of(content_id, is_character)
		UnlockService.Result.SAVE_FAILED:
			_status_text = "存档失败，交易已回滚。"
		UnlockService.Result.ALREADY_UNLOCKED:
			_rebuild_preserving_selection(content_id, is_character)
		_:
			_status_text = "无效内容，无法解锁。"
	_sync_character_buttons()
	_sync_weapon_buttons()
	_update_hint()


## 购买后重建按钮并尽量保留原选择，再把新解锁项加入候选（T29）。
func _rebuild_preserving_selection(purchased_id: StringName, is_character: bool) -> void:
	var previous_character: StringName = _character_id
	var previous_weapons: Array[StringName] = _selected_weapon_ids.duplicate()
	_build()
	if previous_character != StringName() and _is_character_available(previous_character):
		select_character(previous_character)
	for weapon_id: StringName in previous_weapons:
		if _is_weapon_available(weapon_id) and not _selected_weapon_ids.has(weapon_id):
			_selected_weapon_ids.append(weapon_id)
	if is_character:
		select_character(purchased_id)
	elif _is_weapon_available(purchased_id) and not _selected_weapon_ids.has(purchased_id):
		_selected_weapon_ids.append(purchased_id)
	_sync_weapon_buttons()
	_update_hint()


func _display_name_of(content_id: StringName, is_character: bool) -> String:
	if not is_instance_valid(catalog):
		return String(content_id)
	if is_character:
		var character: CharacterDefinition = catalog.get_character(content_id)
		return character.display_name if character != null else String(content_id)
	var weapon: WeaponDefinition = catalog.get_weapon(content_id)
	return weapon.display_name if weapon != null else String(content_id)


func _selection_unlocked() -> bool:
	if not _is_character_available(_character_id):
		return false
	for weapon_id: StringName in _selected_weapon_ids:
		if not _is_weapon_available(weapon_id):
			return false
	return true


func _build() -> void:
	_clear_containers()
	_character_buttons.clear()
	_weapon_buttons.clear()
	_character_id = &""
	_selected_weapon_ids.clear()
	_start_locked = false
	start_button.disabled = false
	unlock_all_button.visible = profile != null and unlock_service != null
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
		_style_button(button)
		button.custom_minimum_size.y = 48.0
		if _is_character_available(character.id):
			button.text = character.display_name
		else:
			button.text = "%s（未解锁 %d）" % [character.display_name, character.unlock_cost]
		button.toggle_mode = true
		button.set_meta(&"base_text", button.text)
		button.button_group = group
		button.pressed.connect(_on_character_pressed.bind(character.id))
		character_container.add_child(button)
		_character_buttons[character.id] = button

	for weapon: WeaponDefinition in catalog.weapons:
		var button := Button.new()
		_style_button(button)
		button.custom_minimum_size.y = 48.0
		if _is_weapon_available(weapon.id):
			button.text = weapon.display_name
		else:
			button.text = "%s（未解锁 %d）" % [weapon.display_name, weapon.unlock_cost]
		button.toggle_mode = true
		button.set_meta(&"base_text", button.text)
		button.pressed.connect(_on_weapon_pressed.bind(weapon.id))
		weapon_container.add_child(button)
		_weapon_buttons[weapon.id] = button

	_build_map_buttons(default_loadout.map_id)

	var start_character_id: StringName = default_loadout.character_id
	if start_character_id == StringName() or not _character_buttons.has(start_character_id) \
			or not _is_character_available(start_character_id):
		start_character_id = _first_available_character_id()
	select_character(start_character_id)

	_selected_weapon_ids.clear()
	for weapon_id: StringName in default_loadout.candidate_weapon_ids:
		if _weapon_buttons.has(weapon_id) and _is_weapon_available(weapon_id):
			_selected_weapon_ids.append(weapon_id)
	for weapon_id: StringName in _starting_weapon_ids():
		if not _selected_weapon_ids.has(weapon_id):
			_selected_weapon_ids.append(weapon_id)
	_sync_weapon_buttons()
	_build_permanent_section()
	_update_hint()


## 地图选择：按目录生成按钮，默认选中快照或第一张（T33）。
func _build_map_buttons(preferred_map_id: StringName) -> void:
	_clear_map_buttons()
	_map_id = &""
	if not is_instance_valid(catalog):
		return
	var group := ButtonGroup.new()
	for map: ArenaDefinition in catalog.maps:
		if map == null:
			continue
		var button := Button.new()
		_style_button(button)
		button.custom_minimum_size = Vector2(112, 40)
		button.text = map.display_name
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_on_map_pressed.bind(map.id))
		map_container.add_child(button)
		_map_buttons[map.id] = button
	var start_id: StringName = preferred_map_id
	if start_id == StringName() or not _map_buttons.has(start_id):
		start_id = catalog.maps[0].id if not catalog.maps.is_empty() and catalog.maps[0] != null else StringName()
	if start_id != StringName():
		select_map(start_id)
	else:
		_sync_map_buttons()


func _on_map_pressed(map_id: StringName) -> void:
	select_map(map_id)


func _sync_map_buttons() -> void:
	for map_id: StringName in _map_buttons.keys():
		var button: Button = _map_buttons[map_id]
		var selected: bool = map_id == _map_id
		button.button_pressed = selected
		button.text = ("◆ " if selected else "◇ ") + _map_display_name(map_id)


func _map_display_name(map_id: StringName) -> String:
	if is_instance_valid(catalog):
		var map: ArenaDefinition = catalog.get_map(map_id)
		if map != null:
			return map.display_name
	return String(map_id)


func _clear_map_buttons() -> void:
	for child: Node in map_container.get_children():
		map_container.remove_child(child)
		child.queue_free()
	_map_buttons.clear()


## 永久强化区：跨角色共享，显示等级/价格，点击购买（T30）。
func _build_permanent_section() -> void:
	_clear_children(_permanent_container)
	if permanent_catalog == null or profile == null:
		_permanent_container.visible = false
		return
	_permanent_container.visible = true
	var title := Label.new()
	title.text = "永久强化（跨角色共享）"
	title.custom_minimum_size = Vector2(0.0, 46.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_stylebox_override(&"normal", TAB_STYLE)
	_permanent_container.add_child(title)
	for definition: PermanentUpgradeDefinition in permanent_catalog.upgrades:
		if definition == null:
			continue
		var level: int = profile.get_permanent_level(definition.id)
		var button := Button.new()
		_style_button(button)
		button.custom_minimum_size.y = 42.0
		if level >= definition.max_level:
			button.text = "%s Lv %d/%d（已满）" % [definition.display_name, level, definition.max_level]
			button.disabled = true
		else:
			button.text = "%s Lv %d/%d（%d 金）" % [
				definition.display_name, level, definition.max_level, definition.get_price(level)
			]
		button.pressed.connect(_on_permanent_pressed.bind(definition.id))
		_permanent_container.add_child(button)


func _on_permanent_pressed(upgrade_id: StringName) -> void:
	if unlock_service == null or permanent_catalog == null:
		return
	var result: UnlockService.Result = unlock_service.purchase_permanent_upgrade(
		permanent_catalog, upgrade_id
	)
	match result:
		UnlockService.Result.SUCCESS:
			_rebuild_preserving_selection(StringName(), false)
			_status_text = "永久强化已提升。"
		UnlockService.Result.INSUFFICIENT_COINS:
			_status_text = "金币不足，无法强化。"
		UnlockService.Result.MAX_LEVEL:
			_status_text = "该项永久强化已达上限。"
		UnlockService.Result.SAVE_FAILED:
			_status_text = "存档失败，强化已回滚。"
		_:
			_status_text = "无效的永久强化项。"
	_update_hint()


## 明确的测试按钮：不扣金币，一次解锁当前目录与永久强化，失败保留旧档。
func _on_unlock_all_pressed() -> void:
	if unlock_service == null or catalog == null or permanent_catalog == null:
		_status_text = "测试解锁失败：缺少档案或目录。"
		_update_hint()
		return
	var result: UnlockService.Result = unlock_service.unlock_all_for_testing(
		catalog, permanent_catalog
	)
	if result == UnlockService.Result.SUCCESS:
		var previous_character: StringName = _character_id
		var previous_weapons: Array[StringName] = _selected_weapon_ids.duplicate()
		_build()
		if previous_character != StringName():
			select_character(previous_character)
		for weapon_id: StringName in previous_weapons:
			if _weapon_buttons.has(weapon_id) and not _selected_weapon_ids.has(weapon_id):
				_selected_weapon_ids.append(weapon_id)
		_sync_weapon_buttons()
		_status_text = "测试内容已全部解锁，永久强化已升满。"
	else:
		_status_text = "测试解锁失败，存档未改变。"
	_update_hint()


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _first_available_character_id() -> StringName:
	for character: CharacterDefinition in catalog.characters:
		if _is_character_available(character.id):
			return character.id
	return catalog.characters[0].id if not catalog.characters.is_empty() else StringName()


func _starting_weapon_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if not is_instance_valid(catalog):
		return ids
	var character: CharacterDefinition = catalog.get_character(_character_id)
	if character == null:
		return ids
	for weapon: WeaponDefinition in character.starting_weapons:
		if weapon != null and not ids.has(weapon.id) and _is_weapon_available(weapon.id):
			ids.append(weapon.id)
	return ids


func _is_starting_weapon(weapon_id: StringName) -> bool:
	return _starting_weapon_ids().has(weapon_id)


func _sync_weapon_buttons() -> void:
	for weapon_id: StringName in _weapon_buttons.keys():
		var button: Button = _weapon_buttons[weapon_id]
		var selected: bool = _selected_weapon_ids.has(weapon_id)
		button.button_pressed = selected
		button.text = ("✓  " if selected else "+  ") + String(button.get_meta(&"base_text"))


func _sync_character_buttons() -> void:
	for character_id: StringName in _character_buttons.keys():
		var button: Button = _character_buttons[character_id]
		var selected: bool = character_id == _character_id
		button.button_pressed = selected
		button.text = ("◆  " if selected else "◇  ") + String(button.get_meta(&"base_text"))


func _update_hint() -> void:
	var character: CharacterDefinition = null
	if is_instance_valid(catalog):
		character = catalog.get_character(_character_id)
	var character_name: String = character.display_name if character != null else "未选择"
	var coins_suffix: String = " ｜ 金币 %d" % profile.coins if profile != null else ""
	var map_name: String = _map_display_name(_map_id) if _map_id != StringName() else "未选择"
	hint_label.text = "角色：%s ｜ 地图：%s ｜ 候选武器 %d/%d%s（起始武器自动保留）" % [
		character_name, map_name, _selected_weapon_ids.size(), RunLoadout.MAX_CANDIDATE_WEAPONS, coins_suffix
	]
	if not _status_text.is_empty():
		hint_label.text += "\n%s" % _status_text


func _clear_containers() -> void:
	for container: VBoxContainer in [character_container, weapon_container]:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.queue_free()
