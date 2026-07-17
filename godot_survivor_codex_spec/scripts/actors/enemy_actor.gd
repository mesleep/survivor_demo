## 通用敌人的直线追踪行为。
##
## 输入：EnemyDefinition 和由组合根注入的 PlayerActor 引用。
## 输出：指向玩家的 CharacterBody2D 速度与物理移动。
## 扩展点：后续敌人类型优先更换 Resource；特殊决策再抽取独立行为。
class_name EnemyActor
extends ActorBase

var definition: EnemyDefinition
var target_player: PlayerActor
var _move_speed: float = 0.0

@onready var contact_hitbox: HitboxComponent = %ContactHitbox


func _ready() -> void:
	super._ready()
	if definition == null or not is_instance_valid(target_player):
		_stop_tracking()


## 从共享配置初始化敌人，并缓存本局玩家引用。
##
## 该方法不修改 Resource，且不从场景树中主动搜索玩家。
func initialize(new_definition: Resource) -> void:
	if new_definition is not EnemyDefinition:
		push_error("EnemyActor 初始化失败：Resource 必须是 EnemyDefinition。")
		_stop_tracking()
		return

	definition = new_definition as EnemyDefinition
	super.initialize(new_definition)
	_move_speed = maxf(definition.move_speed, 0.0)
	contact_hitbox.initialize(self, definition.contact_damage, [&"contact"])


## 更换追踪目标，可用于后续重启或玩家重生。
func set_target_player(player: PlayerActor) -> void:
	_disconnect_target_signal()
	target_player = player
	if not is_instance_valid(target_player):
		_stop_tracking()
		return
	if not target_player.tree_exiting.is_connected(_on_target_player_tree_exiting):
		target_player.tree_exiting.connect(_on_target_player_tree_exiting)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target_player):
		_stop_tracking()
		return

	var direction: Vector2 = global_position.direction_to(target_player.global_position)
	velocity = direction * _move_speed
	move_and_slide()


## 目标失效后只执行一次停止，避免空引用错误每帧刷屏。
func _stop_tracking() -> void:
	velocity = Vector2.ZERO
	set_physics_process(false)


func _on_target_player_tree_exiting() -> void:
	target_player = null
	_stop_tracking()


func _disconnect_target_signal() -> void:
	if not is_instance_valid(target_player):
		return
	if target_player.tree_exiting.is_connected(_on_target_player_tree_exiting):
		target_player.tree_exiting.disconnect(_on_target_player_tree_exiting)


func get_team_id() -> StringName:
	return &"enemy"


func _get_base_max_health() -> float:
	return definition.max_health if definition != null else 1.0
