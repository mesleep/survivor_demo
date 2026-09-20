## 直线子弹运行时基础类。
##
## 输入：只读 ProjectileDefinition、ProjectileSpawnContext 和发射方向。
## 输出：直线移动、DamageEvent、projectile_hit 与 deactivated 信号。
## 扩展点：子类可覆盖命中行为，但应保留同帧去重、穿透和生命周期边界。
class_name ProjectileBase
extends Area2D

signal projectile_hit(target: ActorBase, event: DamageEvent)
signal deactivated(projectile: ProjectileBase)

@export var free_on_deactivate: bool = true

var definition: ProjectileDefinition
var context: ProjectileSpawnContext
var direction: Vector2 = Vector2.ZERO
var is_active: bool = false

var _remaining_pierces: int = 0
var _last_hit_frame_by_instance_id: Dictionary[int, int] = {}
var _age: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var lifetime_timer: Timer = $LifetimeTimer


func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not lifetime_timer.timeout.is_connected(_on_lifetime_timer_timeout):
		lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)


## 从共享配置和独立上下文初始化子弹，不修改场景或 `.tres` 中的 Shape。
func initialize(new_definition: ProjectileDefinition, new_context: ProjectileSpawnContext) -> void:
	reset_runtime_state()
	if new_definition == null or new_context == null or not is_instance_valid(new_context.shooter):
		push_error("ProjectileBase 初始化失败：缺少子弹配置、生成上下文或发射者。")
		return

	definition = new_definition
	context = new_context
	if not context.shooter.tree_exiting.is_connected(_on_shooter_tree_exiting):
		context.shooter.tree_exiting.connect(_on_shooter_tree_exiting)
	global_position = context.spawn_position
	_remaining_pierces = maxi(definition.pierce_count + context.pierce_bonus, 0)
	var visual: AnimatedSprite2D = get_node("Visual") as AnimatedSprite2D
	if definition.visual_frames != null:
		visual.sprite_frames = definition.visual_frames
		visual.play(&"default")
	visual.scale = Vector2.ONE * definition.visual_scale * context.size_multiplier

	var source_shape: Shape2D = collision_shape.shape
	if source_shape is CircleShape2D:
		var runtime_shape: CircleShape2D = source_shape.duplicate() as CircleShape2D
		runtime_shape.radius = definition.hit_radius * context.size_multiplier
		collision_shape.shape = runtime_shape


## 启动直线运动和寿命计时；零方向不会激活子弹。
func launch(new_direction: Vector2) -> void:
	if definition == null or context == null or new_direction.is_zero_approx():
		return
	direction = new_direction.normalized()
	rotation = direction.angle()
	is_active = true
	monitoring = true
	set_physics_process(true)
	lifetime_timer.start(definition.lifetime_seconds)


func _physics_process(delta: float) -> void:
	if not is_active or definition == null:
		return
	_age += delta
	if definition.motion_type == ProjectileDefinition.MotionType.ORBIT:
		if not is_instance_valid(context.shooter):
			deactivate()
			return
		var angle: float = context.initial_direction.angle() + _age * definition.orbit_speed * context.speed_multiplier
		global_position = context.shooter.global_position + Vector2.RIGHT.rotated(angle) * definition.orbit_radius * context.size_multiplier
		rotation = angle
		return
	if definition.motion_type == ProjectileDefinition.MotionType.RETURNING and _age > definition.lifetime_seconds * 0.45:
		if not is_instance_valid(context.shooter):
			deactivate()
			return
		direction = global_position.direction_to(context.shooter.global_position)
		if global_position.distance_to(context.shooter.global_position) < 16.0:
			deactivate()
			return
	global_position += direction * definition.speed * context.speed_multiplier * delta


## 对 Actor 或 Hurtbox 应用一次伤害，并处理同帧去重与穿透。
##
## `pierce_count` 表示首个命中后还能额外穿透的目标数，因此默认 0 命中一次即停用。
func on_hit(target: Node) -> bool:
	if not is_active or not is_instance_valid(target) or context == null or definition == null:
		return false

	var hurtbox: HurtboxComponent
	if target is HurtboxComponent:
		hurtbox = target as HurtboxComponent
	elif target is ActorBase:
		hurtbox = (target as ActorBase).hurtbox_component
	if not is_instance_valid(hurtbox) or not is_instance_valid(hurtbox.owner_actor):
		return false

	var target_actor: ActorBase = hurtbox.owner_actor
	if target_actor == context.shooter or target_actor.get_team_id() == context.team_id:
		return false
	if target_actor.health_component.is_dead() or target_actor.is_queued_for_deletion():
		return false

	var target_id: int = target_actor.get_instance_id()
	var physics_frame: int = Engine.get_physics_frames()
	if _last_hit_frame_by_instance_id.get(target_id, -1) == physics_frame:
		return false
	_last_hit_frame_by_instance_id[target_id] = physics_frame

	var event := DamageEvent.new(
		definition.damage * maxf(context.damage_multiplier, 0.0),
		context.shooter,
		global_position
	)
	if randf() < context.critical_chance:
		event.amount *= 2.0
	event.tags = [&"projectile"]
	if context.weapon_id != StringName():
		event.tags.append(context.weapon_id)
	event.knockback_strength = definition.knockback_strength
	var health_before: float = target_actor.health_component.current_health
	hurtbox.receive_damage(event)
	if context.lifesteal_ratio > 0.0 and context.shooter is ActorBase:
		var shooter: ActorBase = context.shooter as ActorBase
		if not shooter.health_component.is_dead():
			var damage_dealt := maxf(
				health_before - target_actor.health_component.current_health,
				0.0
			)
			shooter.health_component.heal(
				damage_dealt * clampf(context.lifesteal_ratio, 0.0, 1.0)
			)
	projectile_hit.emit(target_actor, event)

	if _remaining_pierces <= 0:
		deactivate()
	else:
		_remaining_pierces -= 1
	return true


## 停用碰撞、运动和 Timer；默认释放节点，也可供测试或未来对象复用保留。
func deactivate() -> void:
	if not is_active:
		return
	is_active = false
	direction = Vector2.ZERO
	# 命中可能来自 Area 查询回调，碰撞状态必须延迟修改以避免物理服务器报错。
	set_deferred("monitoring", false)
	set_physics_process(false)
	lifetime_timer.stop()
	deactivated.emit(self)
	if free_on_deactivate:
		queue_free()


## 清除全部单次运行状态，复用前必须再次 initialize() 和 launch()。
func reset_runtime_state() -> void:
	_age = 0.0
	if context != null and is_instance_valid(context.shooter) and context.shooter.tree_exiting.is_connected(_on_shooter_tree_exiting):
		context.shooter.tree_exiting.disconnect(_on_shooter_tree_exiting)
	is_active = false
	direction = Vector2.ZERO
	_remaining_pierces = 0
	_last_hit_frame_by_instance_id.clear()
	definition = null
	context = null
	if is_instance_valid(lifetime_timer):
		lifetime_timer.stop()
	monitoring = false
	set_physics_process(false)
	visible = true


func get_remaining_pierces() -> int:
	return _remaining_pierces


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		on_hit(area)


func _on_lifetime_timer_timeout() -> void:
	deactivate()


## 发射者离树后保留飞行与阵营信息，但清空来源引用以避免后续命中访问失效对象。
func _on_shooter_tree_exiting() -> void:
	if context != null:
		context.shooter = null
