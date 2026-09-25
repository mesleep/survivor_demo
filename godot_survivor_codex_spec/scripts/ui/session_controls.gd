## 暂停与声音快捷键；显式持有单局引用，不让暂停穿透升级或结算。
class_name SessionControls
extends CanvasLayer

var session: GameSession
var audio: GameAudio
var user_paused: bool = false
var _hint: Label
var _pause_label: Label
var _status: Label
var _boss_bar: ProgressBar
var _loadout: Label
var _coin_icon: TextureRect
var _coin_label: Label
var _tech_icon: TextureRect


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
	_pause_label = Label.new()
	_pause_label.position = Vector2(440, 300)
	_pause_label.add_theme_font_size_override("font_size", 36)
	_pause_label.text = "已暂停\n按 Esc 继续庭院冒险"
	_pause_label.visible = false
	add_child(_pause_label)
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
	_hint.visible = session.is_run_active and not session.level_up_panel.visible
	_loadout.visible = _hint.visible
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
	if get_tree().paused and not user_paused:
		return
	user_paused = not user_paused
	get_tree().paused = user_paused
	_pause_label.visible = user_paused


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
		return
	var weapon_names: PackedStringArray = []
	for weapon: WeaponController in session.player.weapon_controllers:
		weapon_names.append("%s ×%d" % [weapon.definition.display_name, weapon.get_effective_projectile_count()])
	var armor_names: PackedStringArray = []
	for armor_id: StringName in session.player.get_equipped_armor_ids():
		var armor: ArmorDefinition = session.player.get_armor_definition(armor_id)
		if armor != null:
			armor_names.append("%s(%s)" % [armor.display_name, armor.get_category_name()])
	var parts: PackedStringArray = []
	if not weapon_names.is_empty():
		parts.append("武器：" + " · ".join(weapon_names))
	if not armor_names.is_empty():
		parts.append("防具：" + " · ".join(armor_names))
	_loadout.text = "装备 %d/%d ｜ 防御 %d ｜ 移速 %d ｜ 金币 %d ｜ %s" % [
		session.player.get_equipped_count(),
		PlayerActor.MAX_EQUIPMENT_SLOTS,
		roundi(session.player.get_defense()),
		roundi(session.player.get_effective_move_speed()),
		session.player.get_run_coins(),
		" ｜ ".join(parts)
	]


func _update_hint() -> void:
	_hint.text = "WASD / 方向键移动 · 自动攻击 · 拾取宝石升级 · Esc 暂停 · M 声音：%s" % ("关" if audio.muted else "开")
