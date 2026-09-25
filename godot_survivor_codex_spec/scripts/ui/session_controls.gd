## 暂停与声音快捷键；显式持有单局引用，不让暂停穿透升级或结算。
class_name SessionControls
extends CanvasLayer

var session: GameSession
var audio: GameAudio
var user_paused: bool = false
var _hint: Label
var _settings_panel: SettingsPanel
var _status: Label
var _boss_bar: ProgressBar
var _loadout: Label
var _coin_icon: TextureRect
var _coin_label: Label
var _tech_icon: TextureRect
var _equipment_bar: HBoxContainer


func initialize(game_session: GameSession, game_audio: GameAudio) -> void:
	session = game_session
	audio = game_audio
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_hint = Label.new()
	_hint.position = Vector2(20, 666)
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint.add_theme_constant_override("shadow_offset_x", 2)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_hint)
	_build_settings_panel()
	_status = Label.new()
	_status.position = Vector2(880, 20)
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_shadow_color", Color.BLACK)
	_status.add_theme_constant_override("shadow_offset_x", 2)
	_status.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_status)
	_boss_bar = ProgressBar.new()
	_boss_bar.position = Vector2(880, 110)
	_boss_bar.size = Vector2(360, 16)
	_boss_bar.show_percentage = false
	_boss_bar.visible = false
	add_child(_boss_bar)
	_equipment_bar = HBoxContainer.new()
	_equipment_bar.position = Vector2(20, 556)
	_equipment_bar.add_theme_constant_override("separation", 14)
	_equipment_bar.visible = false
	add_child(_equipment_bar)
	_loadout = Label.new()
	_loadout.position = Vector2(20, 622)
	_loadout.add_theme_font_size_override("font_size", 18)
	_loadout.add_theme_color_override("font_shadow_color", Color.BLACK)
	_loadout.add_theme_constant_override("shadow_offset_x", 2)
	_loadout.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_loadout)
	_build_coin_display()
	_connect_player()
	if not session.run_started.is_connected(_on_run_started):
		session.run_started.connect(_on_run_started)
	_update_loadout()
	_update_hint()


## 暂停/设置面板（T33）：Esc 打开，含声音开关与返回主菜单。
func _build_settings_panel() -> void:
	_settings_panel = (load("res://scenes/ui/settings_panel.tscn") as PackedScene).instantiate() as SettingsPanel
	add_child(_settings_panel)
	_settings_panel.initialize(audio.muted, true)
	_settings_panel.closed.connect(_on_settings_closed)
	_settings_panel.return_to_menu_requested.connect(_on_settings_return_to_menu)
	_settings_panel.mute_toggled.connect(_on_settings_mute_toggled)


## 金币图标 + 数字，使用新增 D03 图标（T34）。
func _build_coin_display() -> void:
	_coin_icon = TextureRect.new()
	_coin_icon.texture = load("res://assets/v2_dark_comic/ui/icon_coin.png") as Texture2D
	_coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_coin_icon.position = Vector2(20, 592)
	_coin_icon.size = Vector2(24, 24)
	_coin_icon.visible = false
	add_child(_coin_icon)
	_coin_label = Label.new()
	_coin_label.position = Vector2(48, 592)
	_coin_label.add_theme_font_size_override("font_size", 18)
	_coin_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_coin_label.add_theme_constant_override("shadow_offset_x", 2)
	_coin_label.add_theme_constant_override("shadow_offset_y", 2)
	_coin_label.visible = false
	add_child(_coin_label)
	_tech_icon = TextureRect.new()
	_tech_icon.texture = load("res://assets/v2_dark_comic/ui/icon_tech_set.png") as Texture2D
	_tech_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tech_icon.position = Vector2(838, 22)
	_tech_icon.size = Vector2(26, 26)
	_tech_icon.visible = false
	add_child(_tech_icon)


## 在 start_run 之前创建时，玩家尚不存在；改由 run_started 信号延迟连接。
func _on_run_started(_player: PlayerActor) -> void:
	_connect_player()
	_update_loadout()


func _connect_player() -> void:
	if not is_instance_valid(session):
		return
	var player: PlayerActor = session.player
	if not is_instance_valid(player):
		return
	if not player.upgrade_state_changed.is_connected(_update_loadout):
		player.upgrade_state_changed.connect(_update_loadout)
	if not player.weapon_added.is_connected(_on_weapon_added):
		player.weapon_added.connect(_on_weapon_added)
	if not player.equipment_changed.is_connected(_on_equipment_changed):
		player.equipment_changed.connect(_on_equipment_changed)
	if not player.armor_acquired.is_connected(_on_armor_acquired):
		player.armor_acquired.connect(_on_armor_acquired)
	if not player.coins_changed.is_connected(_on_coins_changed):
		player.coins_changed.connect(_on_coins_changed)


func _process(_delta: float) -> void:
	if not is_instance_valid(session):
		return
	if is_instance_valid(_settings_panel) and _settings_panel.visible and not session.is_run_active:
		_settings_panel.visible = false
		user_paused = false
	_hint.visible = session.is_run_active and not session.level_up_panel.visible
	_loadout.visible = _hint.visible
	if is_instance_valid(_equipment_bar):
		_equipment_bar.visible = _hint.visible
	if is_instance_valid(_coin_icon):
		_coin_icon.visible = _hint.visible
		_coin_label.visible = _hint.visible
		_coin_label.text = str(session.get_run_coins())
	if is_instance_valid(_tech_icon):
		_tech_icon.visible = _status.visible and is_instance_valid(session.player) \
			and session.player.is_tech_set_active()
	_status.visible = session.is_run_active and not session.level_up_panel.visible
	_boss_bar.visible = _status.visible and is_instance_valid(session.boss)
	var map_name: String = "月光庭院"
	if is_instance_valid(session.arena) and session.arena.get_definition() != null:
		map_name = session.arena.get_definition().display_name
	var boss_goal: String = "击退月夜领主，守护庭院！"
	if not session.boss_has_spawned and session.run_definition != null:
		var arrival_seconds: int = roundi(session.run_definition.run_duration_seconds)
		boss_goal = "坚持到 %d:%02d，迎接月夜领主" % [arrival_seconds / 60, arrival_seconds % 60]
	_status.text = "%s\n击退 %d · 场上 %d\n%s" % [
		map_name, session.kill_count, session.enemies.get_child_count(), boss_goal
	]
	if _boss_bar.visible:
		_boss_bar.max_value = session.boss.health_component.maximum_health
		_boss_bar.value = session.boss.health_component.current_health


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var key: InputEventKey = event as InputEventKey
	if key.physical_keycode == KEY_M:
		audio.set_muted(not audio.muted)
		if is_instance_valid(session.player):
			session.player.damage_feedback_component.play_sound = not audio.muted
		_update_hint()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_ESCAPE:
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if not session.is_run_active or session.upgrade_system.is_awaiting_choice():
		return
	if user_paused:
		_settings_panel.close()
		return
	if get_tree().paused:
		return
	user_paused = true
	get_tree().paused = true
	_settings_panel.open()


func _on_settings_closed() -> void:
	user_paused = false
	if session.is_run_active:
		get_tree().paused = false


func _on_settings_return_to_menu() -> void:
	user_paused = false
	if is_instance_valid(session):
		session.request_return_to_menu()


func _on_settings_mute_toggled(muted: bool) -> void:
	audio.set_muted(muted)
	if is_instance_valid(session.player):
		session.player.damage_feedback_component.play_sound = not muted
	_update_hint()


func _on_weapon_added(_weapon: WeaponController) -> void:
	_update_loadout()


func _on_equipment_changed(_equipped_ids: Array[StringName]) -> void:
	_update_loadout()


func _on_armor_acquired(_definition: ArmorDefinition) -> void:
	_update_loadout()


func _on_coins_changed(current_coins: int) -> void:
	if is_instance_valid(_coin_label):
		_coin_label.text = str(current_coins)
	_update_loadout()


func _update_loadout(_upgrade_id: StringName = &"", _count: int = 0) -> void:
	if not is_instance_valid(session) or not is_instance_valid(session.player):
		_loadout.text = ""
		_clear_equipment_bar()
		return
	_rebuild_equipment_bar()
	_loadout.text = "装备 %d/%d ｜ 防御 %d ｜ 移速 %d ｜ 金币 %d" % [
		session.player.get_equipped_count(),
		PlayerActor.MAX_EQUIPMENT_SLOTS,
		roundi(session.player.get_defense()),
		roundi(session.player.get_effective_move_speed()),
		session.player.get_run_coins(),
	]


## 装备栏：每件装备显示图标与名称，质变后显示质变名（T33）。
func _rebuild_equipment_bar() -> void:
	if not is_instance_valid(_equipment_bar):
		return
	_clear_equipment_bar()
	for equipment_id: StringName in session.player.get_equipped_ids():
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 6)
		var icon_rect := TextureRect.new()
		icon_rect.texture = session.player.get_equipment_icon(equipment_id)
		icon_rect.custom_minimum_size = Vector2(26, 26)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		entry.add_child(icon_rect)
		var label := Label.new()
		var display_name: String = session.player.get_equipment_display_name(equipment_id)
		if session.player.get_equipped_category(equipment_id) == &"weapon":
			var controller: WeaponController = _find_weapon_controller(equipment_id)
			if controller != null:
				display_name += " ×%d" % controller.get_effective_projectile_count()
		label.text = display_name
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		entry.add_child(label)
		_equipment_bar.add_child(entry)


func _clear_equipment_bar() -> void:
	if not is_instance_valid(_equipment_bar):
		return
	for child: Node in _equipment_bar.get_children():
		_equipment_bar.remove_child(child)
		child.queue_free()


func _find_weapon_controller(weapon_id: StringName) -> WeaponController:
	for controller: WeaponController in session.player.weapon_controllers:
		if is_instance_valid(controller) and controller.definition.id == weapon_id:
			return controller
	return null


func _update_hint() -> void:
	_hint.text = "WASD / 方向键移动 · 自动攻击 · 拾取宝石升级 · Esc 设置 · M 声音：%s" % ("关" if audio.muted else "开")
