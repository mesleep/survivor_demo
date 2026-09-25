## 单局场景的组合根节点。
##
## 通过 Resource 创建玩家并统一管理计时、生成、成长、Boss、结算和重开。
class_name GameSession
extends Node2D

signal time_changed(remaining_seconds: float, elapsed_seconds: float)
signal run_ended(result: GameResult)
signal boss_spawned(boss: EnemyActor)
## 玩家创建并完成依赖注入后发出；供在 start_run 之前已存在的 UI 延迟连接。
signal run_started(player: PlayerActor)

@export var player_definition: CharacterDefinition
@export var content_catalog: ContentCatalog
@export var combat_rules: CombatRules
## 科技三件套配置（T25）；为空则不启用套装。
@export var tech_set_definition: TechSetDefinition
## 永久强化目录（T30）；为空则不开局快照。
@export var permanent_catalog: PermanentUpgradeCatalog
## 单局经济规则（T26）；为空时按 0 奖励处理。
@export var economy_rules: EconomyRules
## 金币拾取物场景（T26）。
@export var coin_pickup_scene: PackedScene
@export var enemy_spawn_settings: EnemySpawnSettings
@export var run_definition: RunDefinition
## 地图定义（T33）；为空时使用 arena 场景自带配置。
@export var arena_definition: ArenaDefinition
@export var experience_gem_scene: PackedScene
## HUD 和升级面板的统一尺寸倍率，不影响游戏世界或摄像机。
@export_range(0.75, 2.0, 0.05) var ui_scale: float = 1.3
## 为 false 时等待外部先注入 RunLoadout 再调用 start_run()，供主菜单流程使用。
@export var auto_start: bool = true
## 每局基础升级刷新次数（T28）；永久加成由入口叠加。
@export var base_refresh_count: int = 1

var player: PlayerActor
var elapsed_seconds: float = 0.0
var kill_count: int = 0
var is_run_active: bool = false
var boss_has_spawned: bool = false
var boss: EnemyActor
var game_audio: GameAudio
var session_controls: SessionControls
## 单局开局配置快照；为空时沿用导出 player_definition 的旧直启行为。
var run_loadout: RunLoadout
var _economy_random := RandomNumberGenerator.new()
## 入口注入的本局刷新次数；-1 表示使用导出默认值。
var _initial_refresh_count: int = -1
## 入口注入的永久强化等级快照（T30）；运行中不再读取档案。
var _permanent_upgrades: Dictionary[StringName, int] = {}

@onready var arena: Arena = $Arena
@onready var actors: Node2D = $Actors
@onready var enemies: Node2D = $Actors/Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var pickups: Node2D = $Pickups
@onready var enemy_spawner: EnemySpawner = $Systems/EnemySpawner
@onready var targeting_service: TargetingService = $Systems/TargetingService
@onready var difficulty_director: DifficultyDirector = $Systems/DifficultyDirector
@onready var upgrade_system: UpgradeSystem = $Systems/UpgradeSystem
@onready var hud: HUD = $CanvasLayer/HUD
@onready var level_up_panel: LevelUpPanel = $CanvasLayer/LevelUpPanel
@onready var end_panel: EndPanel = $CanvasLayer/EndPanel


func _ready() -> void:
	_economy_random.randomize()
	game_audio = GameAudio.new()
	add_child(game_audio)
	if auto_start:
		start_run()
	session_controls = SessionControls.new()
	add_child(session_controls)
	session_controls.initialize(self, game_audio)


## 注入单局配置快照；必须在 start_run() 前调用。
##
## 保存副本，菜单或调用方之后再改动原对象不会影响本局；已开始则拒绝替换。
func set_run_loadout(loadout: RunLoadout) -> void:
	if is_instance_valid(player):
		push_error("GameSession 已开始，无法替换单局配置。")
		return
	run_loadout = loadout.copy() if loadout != null else null


## 注入本局升级刷新次数（T28）；入口按“基础 + 永久加成”计算后传入。
func set_initial_refresh_count(count: int) -> void:
	_initial_refresh_count = maxi(count, 0)


## 注入永久强化等级快照（T30）；只复制，运行中不读取档案。
func set_permanent_upgrades(levels: Dictionary[StringName, int]) -> void:
	_permanent_upgrades = levels.duplicate()


func _process(delta: float) -> void:
	advance_time(delta)


## 推进唯一权威单局时间；暂停、结束或无配置时不会推进。
##
## 独立入口允许烟雾测试快速模拟五分钟流程，而不绕过正式状态转换。
func advance_time(delta: float) -> void:
	if not is_run_active or get_tree().paused or run_definition == null:
		return
	elapsed_seconds = minf(elapsed_seconds + maxf(delta, 0.0), run_definition.run_duration_seconds)
	difficulty_director.update_elapsed_time(elapsed_seconds)
	_publish_time()
	if elapsed_seconds >= run_definition.run_duration_seconds and not boss_has_spawned:
		_spawn_boss()


## 根据配置创建本局玩家。
##
## 防止重复调用时创建多个玩家；配置或场景类型无效时只报错一次并终止启动。
func start_run() -> void:
	if is_instance_valid(player):
		return
	var effective_character: CharacterDefinition = _resolve_run_character()
	if effective_character == null or effective_character.scene == null:
		push_error("GameSession 启动失败：缺少玩家配置或玩家场景。")
		return
	if run_definition == null or run_definition.stages.is_empty():
		push_error("GameSession 启动失败：缺少 RunDefinition 或难度阶段。")
		return
	var starting_weapons: Array[WeaponDefinition] = _resolve_run_starting_weapons(effective_character)
	get_tree().paused = false
	elapsed_seconds = 0.0
	kill_count = 0
	is_run_active = true
	boss_has_spawned = false
	boss = null

	arena.configure(arena_definition)
	var player_node: Node = effective_character.scene.instantiate()
	if player_node is not PlayerActor:
		push_error("GameSession 启动失败：CharacterDefinition.scene 必须生成 PlayerActor。")
		player_node.queue_free()
		return

	var new_player: PlayerActor = player_node as PlayerActor
	actors.add_child(new_player)
	new_player.global_position = Vector2.ZERO
	new_player.initialize(effective_character)
	new_player.set_combat_rules(combat_rules)
	new_player.configure_camera_bounds(arena.get_bounds())
	player = new_player
	if not enemy_spawner.enemy_spawned.is_connected(_on_enemy_spawned):
		enemy_spawner.enemy_spawned.connect(_on_enemy_spawned)
	enemy_spawner.initialize(enemy_spawn_settings, player, enemies, arena.get_bounds(), projectiles)
	difficulty_director.initialize(run_definition, enemy_spawner)
	targeting_service.initialize(enemies)
	new_player.configure_equipment(_resolve_candidate_weapon_ids())
	new_player.configure_weapons(starting_weapons, projectiles, targeting_service)
	new_player.configure_tech_set(tech_set_definition)
	new_player.apply_permanent_upgrades(_permanent_upgrades, permanent_catalog)
	new_player.weapon_added.connect(_on_weapon_added)
	for controller: WeaponController in new_player.weapon_controllers:
		controller.weapon_fired.connect(_on_weapon_fired)
	new_player.experience_changed.connect(_on_experience_changed)
	upgrade_system.initialize(new_player)
	upgrade_system.set_refresh_count(
		_initial_refresh_count if _initial_refresh_count >= 0 else base_refresh_count
	)
	hud.set_ui_scale(ui_scale)
	level_up_panel.set_ui_scale(ui_scale)
	end_panel.set_ui_scale(ui_scale)
	hud.initialize(new_player)
	level_up_panel.initialize(upgrade_system)
	end_panel.hide_panel()
	if not new_player.leveled_up.is_connected(_on_player_leveled_up):
		new_player.leveled_up.connect(_on_player_leveled_up)
	if not upgrade_system.upgrade_applied.is_connected(_on_upgrade_applied):
		upgrade_system.upgrade_applied.connect(_on_upgrade_applied)
	if not upgrade_system.choices_ready.is_connected(_on_upgrade_choices_ready):
		upgrade_system.choices_ready.connect(_on_upgrade_choices_ready)
	if not new_player.actor_died.is_connected(_on_player_died):
		new_player.actor_died.connect(_on_player_died)
	if not end_panel.restart_requested.is_connected(restart_run):
		end_panel.restart_requested.connect(restart_run)
	_publish_time()
	run_started.emit(new_player)


## 解析本局角色：优先使用单局配置快照，缺失或无效时回退到导出 player_definition。
##
## 配置无效只报错并回退，保证旧直启入口仍然可启动；不修改任何共享 Resource。
func _resolve_run_character() -> CharacterDefinition:
	if run_loadout == null:
		return player_definition
	if not is_instance_valid(content_catalog):
		push_error("GameSession 单局配置缺少内容目录，回退默认角色。")
		return player_definition
	var errors: Array[String] = run_loadout.validate(content_catalog)
	if not errors.is_empty():
		push_error("GameSession 单局配置无效，回退默认角色：%s" % "; ".join(errors))
		return player_definition
	return run_loadout.resolve_character(content_catalog)


## 解析起始武器：配置有效时用快照，否则用角色自身配置；结果复制，不共享数组。
func _resolve_run_starting_weapons(character: CharacterDefinition) -> Array[WeaponDefinition]:
	if run_loadout != null and is_instance_valid(content_catalog):
		var errors: Array[String] = run_loadout.validate(content_catalog)
		if errors.is_empty():
			var resolved: Array[WeaponDefinition] = run_loadout.resolve_starting_weapons(content_catalog)
			if not resolved.is_empty():
				return resolved
	if character == null:
		return []
	return character.starting_weapons.duplicate()


## 解析本局候选武器 ID；配置无效或旧直启时返回空数组表示“不限制”。
func _resolve_candidate_weapon_ids() -> Array[StringName]:
	if run_loadout != null and is_instance_valid(content_catalog):
		if run_loadout.is_valid(content_catalog):
			return run_loadout.candidate_weapon_ids.duplicate()
	return []


## 在指定世界位置创建一颗携带独立经验值的宝石。
##
## 入树前设置位置和数值，避免 Area2D 短暂出现在原点并被错误拾取。
func spawn_experience_gem(experience_value: int, world_position: Vector2) -> ExperienceGem:
	if experience_value <= 0 or experience_gem_scene == null or not is_instance_valid(pickups):
		return null
	var gem_node: Node = experience_gem_scene.instantiate()
	if gem_node is not ExperienceGem:
		push_error("GameSession 生成经验失败：experience_gem_scene 必须生成 ExperienceGem。")
		gem_node.queue_free()
		return null
	var gem: ExperienceGem = gem_node as ExperienceGem
	gem.position = pickups.to_local(world_position)
	gem.initialize(experience_value)
	# 敌人可能在 Area2D 查询回调内死亡；延迟入树，避免物理服务器刷新期间启用新形状。
	pickups.call_deferred("add_child", gem)
	return gem


## 在指定世界位置创建一枚携带独立数量的金币拾取物（T26）。
##
## 与经验宝石一样延迟入树，避免在 Area 查询回调内启用新碰撞形状。
func spawn_coin_pickup(amount: int, world_position: Vector2) -> CoinPickup:
	if amount <= 0 or coin_pickup_scene == null or not is_instance_valid(pickups):
		return null
	var coin_node: Node = coin_pickup_scene.instantiate()
	if coin_node is not CoinPickup:
		push_error("GameSession 生成金币失败：coin_pickup_scene 必须生成 CoinPickup。")
		coin_node.queue_free()
		return null
	var coin: CoinPickup = coin_node as CoinPickup
	coin.position = pickups.to_local(world_position)
	coin.initialize(amount)
	pickups.call_deferred("add_child", coin)
	return coin


func _spawn_coin_drop(world_position: Vector2) -> void:
	if economy_rules == null or coin_pickup_scene == null:
		return
	if not economy_rules.roll_drop(_economy_random):
		return
	spawn_coin_pickup(economy_rules.coins_per_drop, world_position)


## 固定本局掉落随机种子，供测试确定掉金结果。
func set_economy_random_seed(seed_value: int) -> void:
	_economy_random.seed = seed_value


func get_run_coins() -> int:
	return player.get_run_coins() if is_instance_valid(player) else 0


func _on_enemy_spawned(enemy: EnemyActor) -> void:
	if not is_instance_valid(enemy):
		return
	if not enemy.actor_died.is_connected(_on_enemy_died):
		enemy.actor_died.connect(_on_enemy_died)


func _on_enemy_died(actor: ActorBase, _event: DamageEvent) -> void:
	if actor is not EnemyActor:
		return
	var enemy: EnemyActor = actor as EnemyActor
	if enemy.definition == null:
		return
	kill_count += 1
	game_audio.play_cue(&"defeat_enemy")
	if enemy.definition.is_boss:
		if is_run_active:
			end_run(GameResult.Outcome.VICTORY)
		return
	spawn_experience_gem(enemy.definition.experience_value, enemy.global_position)
	_spawn_coin_drop(enemy.global_position)


func _on_player_leveled_up(_new_level: int, _pending_upgrade_count: int) -> void:
	if not is_run_active:
		return
	if upgrade_system.is_awaiting_choice():
		return
	_request_next_upgrade()


## 串行消费待升级次数；一次获得大量经验时不会覆盖当前选择。
func _request_next_upgrade() -> void:
	if not is_instance_valid(player) or player.get_pending_upgrade_count() <= 0:
		_resume_after_upgrades()
		return
	if not player.consume_pending_upgrade():
		_resume_after_upgrades()
		return
	get_tree().paused = true
	game_audio.play_cue(&"upgrade")
	upgrade_system.request_choices(3)


func _on_upgrade_applied(_definition: UpgradeDefinition) -> void:
	level_up_panel.hide_panel()
	if player.get_pending_upgrade_count() > 0:
		call_deferred("_request_next_upgrade")
	else:
		_resume_after_upgrades()


func _on_upgrade_choices_ready(choices: Array[UpgradeDefinition]) -> void:
	if not choices.is_empty():
		return
	if player.get_pending_upgrade_count() > 0:
		call_deferred("_request_next_upgrade")
	else:
		_resume_after_upgrades()


func _resume_after_upgrades() -> void:
	level_up_panel.hide_panel()
	if is_run_active:
		get_tree().paused = false


## 停止本局全部运行行为并发布不可变结算快照。
func end_run(outcome: GameResult.Outcome) -> void:
	if not is_run_active:
		return
	is_run_active = false
	enemy_spawner.stop()
	targeting_service.stop()
	level_up_panel.hide_panel()
	_stop_combat_nodes()
	var coins_from_kills: int = kill_count * (economy_rules.coins_per_kill if economy_rules != null else 0)
	var result := GameResult.new(
		outcome,
		elapsed_seconds,
		player.get_current_level(),
		kill_count,
		player.get_run_coins(),
		coins_from_kills
	)
	get_tree().paused = true
	end_panel.show_result(result)
	game_audio.finish_run(outcome == GameResult.Outcome.VICTORY)
	run_ended.emit(result)


## 通过重新加载当前场景清除全部单局节点、状态和信号连接。
func restart_run() -> void:
	get_tree().paused = false
	var error: Error = get_tree().reload_current_scene()
	if error != OK:
		push_error("GameSession 重开失败：无法重新加载当前场景，错误码 %d。" % error)


func get_remaining_seconds() -> float:
	if run_definition == null:
		return 0.0
	return maxf(run_definition.run_duration_seconds - elapsed_seconds, 0.0)


func _publish_time() -> void:
	var remaining: float = get_remaining_seconds()
	hud.update_remaining_time(remaining)
	time_changed.emit(remaining, elapsed_seconds)


func _spawn_boss() -> EnemyActor:
	if boss_has_spawned or run_definition == null or run_definition.boss_definition == null:
		return boss
	boss_has_spawned = true
	enemy_spawner.stop()
	var spawn_position: Vector2 = enemy_spawner.get_offscreen_spawn_position()
	boss = enemy_spawner.spawn_enemy(run_definition.boss_definition, spawn_position, true)
	if is_instance_valid(boss):
		game_audio.play_cue(&"boss")
		boss_spawned.emit(boss)
	else:
		push_error("GameSession Boss 生成失败。")
	return boss


func _on_player_died(_actor: ActorBase, _event: DamageEvent) -> void:
	end_run(GameResult.Outcome.DEFEAT)


func _on_weapon_fired(_weapon_id: StringName) -> void:
	game_audio.play_cue(&"shot")


func _on_weapon_added(controller: WeaponController) -> void:
	controller.weapon_fired.connect(_on_weapon_fired)


func _on_experience_changed(_current: int, gained: int) -> void:
	if gained > 0:
		game_audio.play_cue(&"pickup")


func _stop_combat_nodes() -> void:
	if is_instance_valid(player):
		player.velocity = Vector2.ZERO
		player.set_physics_process(false)
		player.clear_weapons()
	for child: Node in enemies.get_children():
		if child is EnemyActor:
			(child as EnemyActor).velocity = Vector2.ZERO
			(child as EnemyActor).set_physics_process(false)
	for child: Node in projectiles.get_children():
		if child is ProjectileBase:
			(child as ProjectileBase).deactivate()
		elif child is ExplosionEffect:
			(child as ExplosionEffect).finish()
		elif child is GroundDamageArea:
			(child as GroundDamageArea).finish()
