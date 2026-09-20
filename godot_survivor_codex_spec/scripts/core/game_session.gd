## 单局场景的组合根节点。
##
## 通过 Resource 创建玩家并统一管理计时、生成、成长、Boss、结算和重开。
class_name GameSession
extends Node2D

signal time_changed(remaining_seconds: float, elapsed_seconds: float)
signal run_ended(result: GameResult)
signal boss_spawned(boss: EnemyActor)

@export var player_definition: CharacterDefinition
@export var enemy_spawn_settings: EnemySpawnSettings
@export var run_definition: RunDefinition
@export var experience_gem_scene: PackedScene
## HUD 和升级面板的统一尺寸倍率，不影响游戏世界或摄像机。
@export_range(0.75, 2.0, 0.05) var ui_scale: float = 1.3

var player: PlayerActor
var elapsed_seconds: float = 0.0
var kill_count: int = 0
var is_run_active: bool = false
var boss_has_spawned: bool = false
var boss: EnemyActor
var game_audio: GameAudio
var session_controls: SessionControls

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
	game_audio = GameAudio.new()
	add_child(game_audio)
	start_run()
	session_controls = SessionControls.new()
	add_child(session_controls)
	session_controls.initialize(self, game_audio)


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
	if player_definition == null or player_definition.scene == null:
		push_error("GameSession 启动失败：缺少玩家配置或玩家场景。")
		return
	if run_definition == null or run_definition.stages.is_empty():
		push_error("GameSession 启动失败：缺少 RunDefinition 或难度阶段。")
		return
	get_tree().paused = false
	elapsed_seconds = 0.0
	kill_count = 0
	is_run_active = true
	boss_has_spawned = false
	boss = null

	var player_node: Node = player_definition.scene.instantiate()
	if player_node is not PlayerActor:
		push_error("GameSession 启动失败：CharacterDefinition.scene 必须生成 PlayerActor。")
		player_node.queue_free()
		return

	var new_player: PlayerActor = player_node as PlayerActor
	actors.add_child(new_player)
	new_player.global_position = Vector2.ZERO
	new_player.initialize(player_definition)
	new_player.configure_camera_bounds(arena.get_bounds())
	player = new_player
	if not enemy_spawner.enemy_spawned.is_connected(_on_enemy_spawned):
		enemy_spawner.enemy_spawned.connect(_on_enemy_spawned)
	enemy_spawner.initialize(enemy_spawn_settings, player, enemies, arena.get_bounds())
	difficulty_director.initialize(run_definition, enemy_spawner)
	targeting_service.initialize(enemies)
	new_player.configure_weapons(player_definition.starting_weapons, projectiles, targeting_service)
	new_player.weapon_added.connect(_on_weapon_added)
	for controller: WeaponController in new_player.weapon_controllers:
		controller.weapon_fired.connect(_on_weapon_fired)
	new_player.experience_changed.connect(_on_experience_changed)
	upgrade_system.initialize(new_player)
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
	var result := GameResult.new(outcome, elapsed_seconds, player.get_current_level(), kill_count)
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
