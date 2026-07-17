## 单局场景的组合根节点。
##
## P1-04 负责通过 Resource 创建玩家，并初始化持续生成敌人的 EnemySpawner。
## 战斗、计时和结算系统将在后续阶段通过该组合根注入。
class_name GameSession
extends Node2D

@export var player_definition: CharacterDefinition
@export var enemy_spawn_settings: EnemySpawnSettings

var player: PlayerActor

@onready var arena: Arena = $Arena
@onready var actors: Node2D = $Actors
@onready var enemies: Node2D = $Actors/Enemies
@onready var enemy_spawner: EnemySpawner = $Systems/EnemySpawner


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
	enemy_spawner.initialize(enemy_spawn_settings, player, enemies, arena.get_bounds())
