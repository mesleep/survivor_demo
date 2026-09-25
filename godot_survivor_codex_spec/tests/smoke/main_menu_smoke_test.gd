## T03：主菜单选择、校验、路由与旧直启兼容的专项回归。
extends SceneTree

const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const ENTRY_SCENE_PATH := "res://scenes/bootstrap/game_entry.tscn"
const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const PLAYER_SCENE_PATH := "res://scenes/actors/player/player.tscn"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	await _test_default_menu(catalog)
	await _test_weapon_rules()
	await _test_invalid_and_double_start(catalog)
	await _test_entry_routing()
	await _test_legacy_direct_start()
	if not _failed:
		print("Main menu smoke test passed: selection, validation, routing and legacy start are valid.")
	quit(1 if _failed else 0)


func _test_default_menu(catalog: ContentCatalog) -> void:
	var menu: MainMenu = await _add_menu(catalog)
	_expect(menu != null, "菜单加载失败。")
	if menu == null:
		return
	_expect(menu.get_selected_loadout().is_valid(catalog), "默认选择应有效。")
	_expect(menu.get_selected_weapon_ids().size() == catalog.weapons.size(), "默认应选中全部现有武器。")
	_expect(not menu.start_button.disabled, "默认开始按钮应可用。")
	_expect(not menu.select_character(&"ghost"), "未知角色不应被选中。")
	await _free_node(menu)


func _test_weapon_rules() -> void:
	var weapons: Array[WeaponDefinition] = []
	for index: int in range(11):
		weapons.append(_make_weapon(StringName("w%d" % index), "W%d" % index))
	var character: CharacterDefinition = _make_character(&"hero", [weapons[0]])
	var catalog: ContentCatalog = _make_catalog([character], weapons)
	var menu: MainMenu = await _add_menu(catalog)
	if menu == null:
		return
	_expect(
		menu.get_selected_weapon_ids().size() == RunLoadout.MAX_CANDIDATE_WEAPONS,
		"默认应选满 10 个。"
	)
	_expect(not menu.set_weapon_selected(&"w10", true), "超过候选上限应被拒绝。")
	_expect(menu.set_weapon_selected(&"w1", false), "应能取消非起始武器。")
	_expect(menu.set_weapon_selected(&"w10", true), "腾出位置后应能选中新武器。")
	_expect(not menu.set_weapon_selected(&"w0", false), "起始武器不应被取消。")
	_expect(menu.is_weapon_selected(&"w0"), "起始武器应保持选中。")
	await _free_node(menu)


func _test_invalid_and_double_start(catalog: ContentCatalog) -> void:
	var weapons: Array[WeaponDefinition] = [_make_weapon(&"solo", "Solo")]
	var character: CharacterDefinition = _make_character(&"no_start", [])
	var invalid_catalog: ContentCatalog = _make_catalog([character], weapons)
	var invalid_menu: MainMenu = await _add_menu(invalid_catalog)
	if invalid_menu != null:
		var captured: Array[RunLoadout] = []
		invalid_menu.start_requested.connect(func(loadout: RunLoadout) -> void: captured.append(loadout))
		_expect(not invalid_menu.request_start(), "缺少起始武器时不应开始。")
		_expect(captured.is_empty(), "无效配置不应发出开始信号。")
		_expect(not invalid_menu.hint_label.text.is_empty(), "无效配置应给出提示。")
		await _free_node(invalid_menu)

	var menu: MainMenu = await _add_menu(catalog)
	if menu != null:
		var selections: Array[RunLoadout] = []
		menu.start_requested.connect(func(loadout: RunLoadout) -> void: selections.append(loadout))
		_expect(menu.request_start(), "有效配置应能开始。")
		_expect(not menu.request_start(), "开始后重复请求应被拒绝。")
		_expect(selections.size() == 1, "重复请求不应重复发信号。")
		await _free_node(menu)


func _test_entry_routing() -> void:
	GameEntry.clear_remembered_loadout()
	var entry: GameEntry = (load(ENTRY_SCENE_PATH) as PackedScene).instantiate() as GameEntry
	root.add_child(entry)
	await process_frame
	_expect(entry.get_menu() != null, "入口未显示主菜单。")
	if entry.get_menu() != null:
		_expect(entry.get_menu().request_start(), "入口菜单未能开始。")
	await process_frame
	await process_frame
	var session: GameSession = entry.get_active_session()
	_expect(session != null, "入口未创建单局。")
	if session != null and session.player != null:
		_expect(session.player.has_weapon(&"staff"), "入口单局缺少设计稿起始法杖。")
		session.enemy_spawner.stop()
	entry.show_menu()
	await process_frame
	await process_frame
	_expect(entry.get_active_session() == null, "返回菜单未释放单局。")
	_expect(entry.get_menu() != null, "返回菜单未重建菜单。")
	await _free_node(entry)


func _test_legacy_direct_start() -> void:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	_expect(session != null and session.player != null, "旧直启入口未创建玩家。")
	if session != null and session.player != null:
		_expect(session.player.has_weapon(&"staff"), "旧直启入口缺少设计稿起始法杖。")
		session.enemy_spawner.stop()
	await _free_node(main_node)


func _add_menu(catalog: ContentCatalog) -> MainMenu:
	var menu: MainMenu = (load(MENU_SCENE_PATH) as PackedScene).instantiate() as MainMenu
	menu.catalog = catalog
	root.add_child(menu)
	await process_frame
	return menu


func _make_weapon(id: StringName, display_name: String) -> WeaponDefinition:
	var weapon := WeaponDefinition.new()
	weapon.id = id
	weapon.display_name = display_name
	return weapon


func _make_character(id: StringName, starting: Array[WeaponDefinition]) -> CharacterDefinition:
	var character := CharacterDefinition.new()
	character.id = id
	character.display_name = String(id)
	character.scene = load(PLAYER_SCENE_PATH) as PackedScene
	character.starting_weapons = starting
	return character


func _make_catalog(
		characters: Array[CharacterDefinition], weapons: Array[WeaponDefinition]
) -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.characters = characters
	catalog.weapons = weapons
	return catalog


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
