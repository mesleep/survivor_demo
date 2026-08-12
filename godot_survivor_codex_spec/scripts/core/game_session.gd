## 单局场景的组合根节点。
##
## 通过 Resource 创建玩家，并为刷怪、索敌、武器和经验掉落注入本局依赖。
## 计时和结算系统将在后续阶段通过该组合根继续组合。
class_name GameSession
extends Node2D

@export var player_definition: CharacterDefinition
@export var enemy_spawn_settings: EnemySpawnSettings
@export var experience_gem_scene: PackedScene
## HUD 和升级面板的统一尺寸倍率，不影响游戏世界或摄像机。
@export_range(0.75, 2.0, 0.05) var ui_scale: float = 1.3

var player: PlayerActor

@onready var arena: Arena = $Arena
@onready var actors: Node2D = $Actors
@onready var enemies: Node2D = $Actors/Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var pickups: Node2D = $Pickups
@onready var enemy_spawner: EnemySpawner = $Systems/EnemySpawner
@onready var targeting_service: TargetingService = $Systems/TargetingService
@onready var upgrade_system: UpgradeSystem = $Systems/UpgradeSystem
@onready var hud: HUD = $CanvasLayer/HUD
@onready var level_up_panel: LevelUpPanel = $CanvasLayer/LevelUpPanel


func _ready() -> void:
	start_run()


## 根据配置创建本局玩家。
##
## 防止重复调用时创建多个玩家；配置或场景类型无效时只报错一次并终止启动。
func start_run() -> void:
	if is_instance_valid(player):
		return
	if player_definition == null or player_definition.scene == null:
		push_error("GameSession 启动失败：缺少玩家配置或玩家场景。")
		return

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
	targeting_service.initialize(enemies)
	new_player.configure_weapons(player_definition.starting_weapons, projectiles, targeting_service)
	upgrade_system.initialize(new_player)
	hud.set_ui_scale(ui_scale)
	level_up_panel.set_ui_scale(ui_scale)
	hud.initialize(new_player)
	level_up_panel.initialize(upgrade_system)
	if not new_player.leveled_up.is_connected(_on_player_leveled_up):
		new_player.leveled_up.connect(_on_player_leveled_up)
	if not upgrade_system.upgrade_applied.is_connected(_on_upgrade_applied):
		upgrade_system.upgrade_applied.connect(_on_upgrade_applied)
	if not upgrade_system.choices_ready.is_connected(_on_upgrade_choices_ready):
		upgrade_system.choices_ready.connect(_on_upgrade_choices_ready)


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
	spawn_experience_gem(enemy.definition.experience_value, enemy.global_position)


func _on_player_leveled_up(_new_level: int, _pending_upgrade_count: int) -> void:
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
	get_tree().paused = false
