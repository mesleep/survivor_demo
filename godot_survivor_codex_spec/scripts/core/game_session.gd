## 单局场景的组合根节点。
##
## 通过 Resource 创建玩家，并为刷怪、索敌、武器和经验掉落注入本局依赖。
## 计时和结算系统将在后续阶段通过该组合根继续组合。
class_name GameSession
extends Node2D

@export var player_definition: CharacterDefinition
@export var enemy_spawn_settings: EnemySpawnSettings
@export var experience_gem_scene: PackedScene

var player: PlayerActor

@onready var arena: Arena = $Arena
@onready var actors: Node2D = $Actors
@onready var enemies: Node2D = $Actors/Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var pickups: Node2D = $Pickups
@onready var enemy_spawner: EnemySpawner = $Systems/EnemySpawner
@onready var targeting_service: TargetingService = $Systems/TargetingService


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
