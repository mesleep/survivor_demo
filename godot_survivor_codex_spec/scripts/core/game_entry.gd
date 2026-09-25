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

var _menu: MainMenu
var _session: GameSession


func _ready() -> void:
	show_menu()


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
	_menu.start_requested.connect(_on_start_requested)
	if _remembered_loadout != null:
		_menu.preselect(_remembered_loadout)
	add_child(_menu)


## 清空记忆的配置，仅供测试或未来的“重置进度”使用。
static func clear_remembered_loadout() -> void:
	_remembered_loadout = null


func get_active_session() -> GameSession:
	return _session


func get_menu() -> MainMenu:
	return _menu


func _on_start_requested(loadout: RunLoadout) -> void:
	if loadout == null:
		return
	_remembered_loadout = loadout.copy()
	_start_session(loadout)


func _start_session(loadout: RunLoadout) -> void:
	if session_scene == null:
		push_error("GameEntry 缺少单局场景。")
		return
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
	_session.start_run()


func _clear_menu() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null


func _clear_session() -> void:
	if is_instance_valid(_session):
		_session.queue_free()
	_session = null
