## 通用敌人的直线追踪行为。
##
## 输入：EnemyDefinition 和由组合根注入的 PlayerActor 引用。
## 输出：指向玩家的 CharacterBody2D 速度与物理移动。
## 扩展点：后续敌人类型优先更换 Resource；特殊决策再抽取独立行为。
class_name EnemyActor
extends ActorBase

var definition: EnemyDefinition
var target_player: PlayerActor
## 远程敌人发射弹体的容器（由 EnemySpawner 注入）；近战敌人可为空。
var projectile_parent: Node
var _move_speed: float = 0.0
var _health_multiplier: float = 1.0
var _move_speed_multiplier: float = 1.0
var _damage_multiplier: float = 1.0
var _attack_cooldown_remaining: float = 0.0

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
	_attack_cooldown_remaining = 0.0
	apply_difficulty_multipliers(1.0, 1.0, 1.0)


## 注入远程弹体容器（T33）；近战敌人可忽略。
func set_projectile_parent(parent: Node) -> void:
	projectile_parent = parent


## 将难度倍率应用到当前敌人实例，不修改共享 EnemyDefinition。
func apply_difficulty_multipliers(
		health_multiplier: float,
		move_speed_multiplier: float,
		damage_multiplier: float
) -> void:
	if definition == null:
		return
	_health_multiplier = maxf(health_multiplier, 0.05)
	_move_speed_multiplier = maxf(move_speed_multiplier, 0.05)
	_damage_multiplier = maxf(damage_multiplier, 0.0)
	health_component.initialize(definition.max_health * _health_multiplier)
	_move_speed = maxf(definition.move_speed * _move_speed_multiplier, 0.0)
	contact_hitbox.initialize(self, definition.contact_damage * _damage_multiplier, [&"contact"])


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


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target_player):
		_stop_tracking()
		return

	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	var to_player: Vector2 = target_player.global_position - global_position
	var distance: float = to_player.length()
	var move_multiplier: float = get_status_move_speed_multiplier()

	# 远程敌人：靠近到攻击范围、过近则后退，否则停下射击（T33）。
	if definition != null and definition.attack_type == EnemyDefinition.AttackType.RANGED \
			and definition.projectile_definition != null:
		if distance > definition.attack_range:
			velocity = to_player.normalized() * _move_speed * move_multiplier
		elif distance < definition.preferred_distance and distance > 0.0:
			velocity = -to_player.normalized() * _move_speed * move_multiplier
		else:
			velocity = Vector2.ZERO
			if _attack_cooldown_remaining <= 0.0:
				_fire_projectile(to_player.normalized())
				_attack_cooldown_remaining = definition.attack_cooldown_seconds
		move_and_slide()
		return
	# 混合型 Boss 持续逼近，同时在射程内发射扇形弹幕；接触伤害仍有效。
	if definition != null and definition.attack_type == EnemyDefinition.AttackType.HYBRID \
			and definition.projectile_definition != null and distance <= definition.attack_range \
			and _attack_cooldown_remaining <= 0.0 and distance > 0.0:
		_fire_projectile(to_player.normalized())
		_attack_cooldown_remaining = definition.attack_cooldown_seconds

	var direction: Vector2 = global_position.direction_to(target_player.global_position)
	velocity = direction * _move_speed * move_multiplier
	move_and_slide()


## 朝玩家方向发射一枚敌人弹体；弹体命中层由 ProjectileDefinition.collision_mask 决定。
func _fire_projectile(direction: Vector2) -> void:
	if definition == null or definition.projectile_definition == null:
		return
	if definition.projectile_definition.scene == null or not is_instance_valid(projectile_parent):
		return
	var count: int = maxi(definition.projectiles_per_attack, 1)
	var spread: float = deg_to_rad(definition.projectile_spread_degrees)
	for index: int in range(count):
		var projectile_node: Node = definition.projectile_definition.scene.instantiate()
		if projectile_node is not ProjectileBase:
			projectile_node.queue_free()
			return
		var angle: float = spread * (float(index) / float(count - 1) - 0.5) if count > 1 else 0.0
		var shot_direction: Vector2 = direction.rotated(angle)
		var projectile: ProjectileBase = projectile_node as ProjectileBase
		projectile_parent.add_child(projectile)
		var context := ProjectileSpawnContext.new(self, get_team_id(), global_position, shot_direction)
		context.weapon_id = definition.id
		projectile.initialize(definition.projectile_definition, context)
		projectile.launch(context.initial_direction)


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


## Boss 等由 Resource 标记 control_immune 的敌人免疫减速/冻结。
func is_control_immune() -> bool:
	return definition != null and definition.control_immune


func _get_base_max_health() -> float:
	return definition.max_health if definition != null else 1.0


func get_effective_move_speed() -> float:
	return _move_speed * get_status_move_speed_multiplier()
