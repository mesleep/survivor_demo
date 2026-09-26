## 顶层入口与场景路由：主菜单 ↔ 单局。
##
## 输入：内容目录、菜单场景、单局场景。
## 输出：选中并开始一局，或在结束后回到菜单；单局配置在 start_run 前注入。
## 只持有稳定 ID 生成的 RunLoadout，不把玩家节点交给 UI。
class_name GameEntry
extends Node

## 跨场景重载记住最近一次选择，便于结算后回到菜单继续。
static var _remembered_loadout: RunLoadout

@export var catalog: ContentCatalog
@export var menu_scene: PackedScene
@export var session_scene: PackedScene

## 跨局档案存储；测试可在入树前注入临时路径（T27）。
var profile_store: ProfileStore
var profile: Profile
## 解锁交易入口（T29）。
var unlock_service: UnlockService
## 永久强化目录（T30）；为空时用默认路径加载。
var permanent_catalog: PermanentUpgradeCatalog

var _menu: MainMenu
var _session: GameSession
var _workbench: Node
var _status_text: String = ""


func _ready() -> void:
	_ensure_profile_store()
	if permanent_catalog == null:
		permanent_catalog = load("res://data/progression/permanent_catalog.tres") as PermanentUpgradeCatalog
	profile = profile_store.load_profile()
	unlock_service = UnlockService.new(profile, profile_store)
	if not profile_store.last_error.is_empty():
		_status_text = "存档提示：%s" % profile_store.last_error
	show_menu()


## 若未注入则创建默认存储，并从目录填充已知/默认解锁 ID。
func _ensure_profile_store() -> void:
	if profile_store == null:
		profile_store = ProfileStore.new()
	if is_instance_valid(catalog):
		profile_store.known_character_ids = catalog.get_character_ids()
		profile_store.known_weapon_ids = catalog.get_weapon_ids()
		# 默认只解锁价格为 0 的内容（T29）；其余需购买。
		profile_store.default_character_ids = _free_character_ids()
		profile_store.default_weapon_ids = _free_weapon_ids()


func _free_character_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if not is_instance_valid(catalog):
		return ids
	for character: CharacterDefinition in catalog.characters:
		if character != null and character.unlock_cost == 0:
			ids.append(character.id)
	return ids


## 默认解锁：价格为 0 的武器，以及免费角色的起始武器（保证新档可开局）。
func _free_weapon_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if not is_instance_valid(catalog):
		return ids
	for weapon: WeaponDefinition in catalog.weapons:
		if weapon != null and weapon.unlock_cost == 0:
			ids.append(weapon.id)
	for character: CharacterDefinition in catalog.characters:
		if character == null or character.unlock_cost != 0:
			continue
		for weapon: WeaponDefinition in character.starting_weapons:
			if weapon != null and not ids.has(weapon.id):
				ids.append(weapon.id)
	return ids


func get_profile() -> Profile:
	return profile


func get_profile_store() -> ProfileStore:
	return profile_store


## 释放当前单局并显示主菜单；可重复调用。
func show_menu() -> void:
	_clear_session()
	if is_instance_valid(_menu):
		return
	if menu_scene == null:
		push_error("GameEntry 缺少主菜单场景。")
		return
	var menu_node: Node = menu_scene.instantiate()
	if menu_node is not MainMenu:
		push_error("GameEntry 主菜单场景必须生成 MainMenu。")
		menu_node.queue_free()
		return
	_menu = menu_node as MainMenu
	_menu.catalog = catalog
	_menu.configure_profile(profile, unlock_service, permanent_catalog)
	_menu.start_requested.connect(_on_start_requested)
	_menu.reset_requested.connect(_on_menu_reset_requested)
	_menu.tools_requested.connect(_on_menu_tools_requested)
	if _remembered_loadout != null:
		_menu.preselect(_remembered_loadout)
	add_child(_menu)
	if not _status_text.is_empty():
		_menu.set_status(_status_text)


## 清空记忆的配置，仅供测试或“重置进度”使用。
static func clear_remembered_loadout() -> void:
	_remembered_loadout = null


## 重置存档：删除正式/临时/备份档并恢复默认档案（只解锁免费内容、金币清零）。
func reset_profile() -> void:
	if profile_store == null:
		return
	profile_store.delete_save()
	profile = profile_store.load_profile()
	unlock_service = UnlockService.new(profile, profile_store)
	clear_remembered_loadout()
	_status_text = "存档已重置：金币、解锁与永久强化已恢复初始状态。"
	if is_instance_valid(_menu):
		_menu.configure_profile(profile, unlock_service, permanent_catalog)
		_menu.set_status(_status_text)
	else:
		show_menu()


func _on_menu_reset_requested() -> void:
	reset_profile()


func _on_menu_tools_requested() -> void:
	_open_config_workbench()


## 打开数值/素材工作台；工作台以覆盖层形式挂在入口下，关闭后回到主菜单。
func _open_config_workbench() -> void:
	if is_instance_valid(_workbench):
		_workbench.visible = true
		return
	var scene: PackedScene = load("res://scenes/tools/config_workbench.tscn") as PackedScene
	if scene == null:
		_status_text = "工作台场景缺失。"
		if is_instance_valid(_menu):
			_menu.set_status(_status_text)
		return
	_workbench = scene.instantiate()
	if _workbench is CanvasLayer:
		(_workbench as CanvasLayer).layer = 20
	elif _workbench is Control:
		(_workbench as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_workbench)
	if _workbench.has_signal("closed"):
		_workbench.connect("closed", _on_workbench_closed)


func _on_workbench_closed() -> void:
	if is_instance_valid(_workbench):
		_workbench.queue_free()
	_workbench = null


func get_active_session() -> GameSession:
	return _session


func get_menu() -> MainMenu:
	return _menu


func _on_start_requested(loadout: RunLoadout) -> void:
	if loadout == null:
		return
	if not is_loadout_unlocked(loadout):
		_status_text = "所选角色或武器尚未解锁。"
		if is_instance_valid(_menu):
			_menu.set_status(_status_text)
		return
	_remembered_loadout = loadout.copy()
	_start_session(loadout)


## 开局配置只接受已解锁内容（T29）；无档案时视为全部可用（旧直启兼容）。
func is_loadout_unlocked(loadout: RunLoadout) -> bool:
	if loadout == null or profile == null:
		return true
	if not profile.is_character_unlocked(loadout.character_id):
		return false
	for weapon_id: StringName in loadout.candidate_weapon_ids:
		if not profile.is_weapon_unlocked(weapon_id):
			return false
	for weapon_id: StringName in loadout.starting_weapon_ids:
		if not profile.is_weapon_unlocked(weapon_id):
			return false
	return true


func _start_session(loadout: RunLoadout) -> void:
	if session_scene == null:
		push_error("GameEntry 缺少单局场景。")
		return
	var menu_muted: bool = _menu.get_preferred_muted() if is_instance_valid(_menu) else false
	_clear_menu()
	var session_node: Node = session_scene.instantiate()
	if session_node is not GameSession:
		push_error("GameEntry 单局场景必须生成 GameSession。")
		session_node.queue_free()
		return
	_session = session_node as GameSession
	_session.auto_start = false
	add_child(_session)
	_session.set_run_loadout(loadout)
	# 开局刷新次数 = 基础 + 档案永久加成（T28；永久加成由 T30 购买）。
	var bonus: int = profile.refresh_bonus if profile != null else 0
	_session.set_initial_refresh_count(_session.base_refresh_count + bonus)
	if profile != null:
		_session.set_permanent_upgrades(profile.permanent_upgrades.duplicate())
	if not _session.run_ended.is_connected(_on_run_ended):
		_session.run_ended.connect(_on_run_ended)
	if not _session.return_to_menu_requested.is_connected(show_menu):
		_session.return_to_menu_requested.connect(show_menu)
	_session.start_run()
	_session.game_audio.set_muted(menu_muted)


## 结算后把本局金币累加到档案并保存；失败时保留内存余额并提示（T27）。
func apply_run_result(result: GameResult) -> bool:
	if result == null or profile == null:
		return false
	profile.add_coins(result.total_coins)
	var saved: bool = profile_store.save_profile(profile)
	_status_text = "" if saved else "存档写入失败：%s" % profile_store.last_error
	if not saved and is_instance_valid(_menu):
		_menu.set_status(_status_text)
	return saved


func _on_run_ended(result: GameResult) -> void:
	apply_run_result(result)


func _clear_menu() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null


func _clear_session() -> void:
	if is_instance_valid(_session):
		_session.queue_free()
	_session = null
