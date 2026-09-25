## 管理一把武器的独立运行时冷却和发射请求。
##
## 输入：只读 WeaponDefinition、所属 Actor、子弹容器、目标与运行时修正。
## 输出：实际 ProjectileBase、fire_requested、projectile_spawned 和 weapon_fired 信号。
## 扩展点：同一角色可组合多个实例，每个实例拥有独立冷却与修正状态。
class_name WeaponController
extends Node2D

signal fire_requested(
	definition: WeaponDefinition,
	owner_actor: ActorBase,
	target: Node2D,
	projectile_parent: Node,
	projectile_count: int,
	damage_multiplier: float
)
signal weapon_fired(weapon_id: StringName)
signal projectile_spawned(projectile: ProjectileBase)

const MINIMUM_COOLDOWN_SECONDS := 0.02
const MINIMUM_RUNTIME_MULTIPLIER := 0.05
const REPEAT_SHOT_DELAY_RATIO := 0.35

var definition: WeaponDefinition
var owner_actor: ActorBase
var projectile_parent: Node
var targeting_service: TargetingService

var _cooldown_remaining: float = 0.0
var _runtime_cooldown_multiplier: float = 1.0
var _runtime_projectile_count_bonus: int = 0
var _runtime_damage_multiplier: float = 1.0
var _runtime_bonus_projectile_chance: float = 0.0
var _runtime_projectile_lifesteal_ratio: float = 0.0
var _runtime_repeat_shot_chance: float = 0.0
var _runtime_volley_count_bonus: int = 0
var _charge_remaining: float = -1.0
var _charge_target_position: Vector2 = Vector2.ZERO
var _repeat_shot_generation: int = 0
var _random := RandomNumberGenerator.new()
var weapon_visual: AnimatedSprite2D
var _visual_clock: float = 0.0
var visual_slot: int = 0
var _pierce_bonus: int = 0
var _speed_multiplier: float = 1.0
var _size_multiplier: float = 1.0
var _critical_chance: float = 0.0


func _ready() -> void:
	_random.randomize()


func _process(delta: float) -> void:
	_update_visual(delta)
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if not is_instance_valid(owner_actor) or owner_actor.health_component.is_dead():
		return

	# 蓄力中：即使目标中途消失也继续，按最后一次已知位置释放。
	if _charge_remaining >= 0.0:
		if is_instance_valid(targeting_service) and definition != null:
			var charging_target: ActorBase = targeting_service.get_nearest_target(
				owner_actor.get_aim_position(), get_effective_target_range(), &"enemy"
			)
			if charging_target != null:
				_charge_target_position = charging_target.get_aim_position()
		_charge_remaining -= delta
		if _charge_remaining <= 0.0:
			_release_charge()
		return

	if not can_fire() or not is_instance_valid(targeting_service):
		return
	var target: ActorBase = targeting_service.get_nearest_target(
		owner_actor.get_aim_position(),
		get_effective_target_range(),
		&"enemy"
	)
	if target == null:
		return
	if definition != null and definition.charge_seconds > 0.0:
		_begin_charge(target)
		return
	request_fire(target)


## 注入武器配置及运行时依赖，并完全重置单局状态。
func initialize(
		new_definition: WeaponDefinition,
		new_owner_actor: ActorBase,
		new_projectile_parent: Node
) -> void:
	_disconnect_dependency_signals()
	definition = new_definition
	owner_actor = new_owner_actor
	projectile_parent = new_projectile_parent
	reset_runtime_state()

	if definition == null or not is_instance_valid(owner_actor) or not is_instance_valid(projectile_parent):
		push_error("WeaponController 初始化失败：缺少武器配置、所属 Actor 或子弹容器。")
		set_process(false)
		return

	owner_actor.tree_exiting.connect(_on_owner_actor_tree_exiting)
	projectile_parent.tree_exiting.connect(_on_projectile_parent_tree_exiting)
	_configure_visual()
	set_process(true)


## 注入共享索敌服务；不持有固定 GameSession 路径。
func set_targeting_service(new_targeting_service: TargetingService) -> void:
	if is_instance_valid(targeting_service) and targeting_service.tree_exiting.is_connected(_on_targeting_service_tree_exiting):
		targeting_service.tree_exiting.disconnect(_on_targeting_service_tree_exiting)
	targeting_service = new_targeting_service
	if is_instance_valid(targeting_service):
		targeting_service.tree_exiting.connect(_on_targeting_service_tree_exiting)


func can_fire() -> bool:
	return (
		definition != null
		and definition.projectile_definition != null
		and definition.projectile_definition.scene != null
		and is_instance_valid(owner_actor)
		and is_instance_valid(projectile_parent)
		and not owner_actor.health_component.is_dead()
		and _cooldown_remaining <= 0.0
	)


## 验证目标并按弹数和扩散创建子弹；未成功生成时不消耗冷却。
func request_fire(target: Node2D) -> bool:
	if not can_fire() or not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():
		return false
	if target is ActorBase and (target as ActorBase).health_component.is_dead():
		return false

	var target_position: Vector2 = (target as ActorBase).get_aim_position() if target is ActorBase else target.global_position
	var base_direction: Vector2 = owner_actor.get_aim_position().direction_to(target_position)
	if base_direction.is_zero_approx():
		base_direction = Vector2.RIGHT
	var requested_count: int = get_effective_projectile_count()
	if _random.randf() < _runtime_bonus_projectile_chance:
		requested_count += 1
	var spawned_count: int = _fire_volley(base_direction, requested_count, target, _runtime_damage_multiplier)
	if spawned_count == 0:
		return false

	var cooldown_seconds := get_effective_cooldown_seconds()
	_cooldown_remaining = cooldown_seconds
	fire_requested.emit(
		definition,
		owner_actor,
		target,
		projectile_parent,
		spawned_count,
		_runtime_damage_multiplier
	)
	weapon_fired.emit(definition.id)
	if _random.randf() < _runtime_repeat_shot_chance:
		_fire_repeat_shot_after_delay(
			target_position,
			cooldown_seconds * REPEAT_SHOT_DELAY_RATIO,
			_repeat_shot_generation
		)
	var volley_count: int = get_effective_volley_count()
	if volley_count > 1:
		_fire_extra_volleys(target_position, volley_count, _repeat_shot_generation)
	return true


## 生成一轮弹幕（可能多颗），方向与扩散规则集中在此。
func _fire_volley(
		base_direction: Vector2, requested_count: int, target: Node2D, damage_multiplier: float
) -> int:
	var spawned_count: int = 0
	for index: int in range(requested_count):
		var direction: Vector2 = base_direction.rotated(_get_spread_offset_radians(index, requested_count))
		if definition.projectile_definition.motion_type == ProjectileDefinition.MotionType.ORBIT:
			direction = Vector2.RIGHT.rotated(TAU * float(index) / requested_count)
		var context := ProjectileSpawnContext.new(
			owner_actor,
			owner_actor.get_team_id(),
			owner_actor.get_aim_position(),
			direction
		)
		context.damage_multiplier = damage_multiplier
		context.lifesteal_ratio = _runtime_projectile_lifesteal_ratio
		context.target = target
		context.weapon_id = definition.id
		if spawn_projectile(definition.projectile_definition, context) != null:
			spawned_count += 1
	return spawned_count


## 开始蓄力；重复调用不会刷新或叠加蓄力进度。
func begin_charge(target: Node2D) -> bool:
	if definition == null or definition.charge_seconds <= 0.0 or _charge_remaining >= 0.0:
		return false
	if not is_instance_valid(target):
		return false
	_charge_remaining = definition.charge_seconds
	_charge_target_position = (target as ActorBase).get_aim_position() if target is ActorBase else target.global_position
	return true


func _begin_charge(target: Node2D) -> void:
	begin_charge(target)


func is_charging() -> bool:
	return _charge_remaining >= 0.0


func get_charge_remaining() -> float:
	return _charge_remaining


## 蓄力完成：按最后已知位置释放高伤法球，冷却从释放时开始计算。
func _release_charge() -> void:
	_charge_remaining = -1.0
	if not can_fire():
		return
	var direction: Vector2 = owner_actor.get_aim_position().direction_to(_charge_target_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var charge_multiplier: float = _runtime_damage_multiplier * maxf(definition.charge_damage_multiplier, 0.0)
	var requested_count: int = get_effective_projectile_count()
	var spawned_count: int = _fire_volley(direction, requested_count, null, charge_multiplier)
	if spawned_count == 0:
		return
	var cooldown_seconds := get_effective_cooldown_seconds()
	_cooldown_remaining = cooldown_seconds
	fire_requested.emit(
		definition, owner_actor, null, projectile_parent, spawned_count, charge_multiplier
	)
	weapon_fired.emit(definition.id)


## 在同一次攻击周期内追加射击轮次；冷却只计算一次，轮间使用约定方向。
##
## 目标可能在轮间死亡，因此使用首次记录的目标位置；generation 变化（重置/重开）会取消后续轮次。
func _fire_extra_volleys(target_position: Vector2, volleys: int, generation: int) -> void:
	for _index: int in range(1, volleys):
		var interval: float = maxf(definition.volley_interval_seconds, 0.01)
		await get_tree().create_timer(interval, false).timeout
		if generation != _repeat_shot_generation or not is_instance_valid(owner_actor):
			return
		if not is_instance_valid(projectile_parent) or owner_actor.health_component.is_dead():
			return
		var direction: Vector2 = owner_actor.get_aim_position().direction_to(target_position)
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		var requested_count: int = get_effective_projectile_count()
		if _random.randf() < _runtime_bonus_projectile_chance:
			requested_count += 1
		var spawned_count: int = _fire_volley(direction, requested_count, null, _runtime_damage_multiplier)
		if spawned_count > 0:
			fire_requested.emit(
				definition, owner_actor, null, projectile_parent, spawned_count, _runtime_damage_multiplier
			)
			weapon_fired.emit(definition.id)


## 通过注入的容器实例化并启动一个 ProjectileBase。
func spawn_projectile(
		projectile_definition: ProjectileDefinition,
		context: ProjectileSpawnContext
) -> ProjectileBase:
	if projectile_definition == null or projectile_definition.scene == null or context == null:
		return null
	if not is_instance_valid(projectile_parent):
		return null

	var projectile_node: Node = projectile_definition.scene.instantiate()
	if projectile_node is not ProjectileBase:
		push_error("WeaponController 发射失败：ProjectileDefinition.scene 必须生成 ProjectileBase。")
		projectile_node.queue_free()
		return null
	var projectile: ProjectileBase = projectile_node as ProjectileBase
	context.pierce_bonus = _pierce_bonus
	context.speed_multiplier = _speed_multiplier
	context.size_multiplier = _size_multiplier
	context.critical_chance = _critical_chance
	projectile_parent.add_child(projectile)
	projectile.initialize(projectile_definition, context)
	projectile.launch(context.initial_direction)
	if not projectile.is_active:
		projectile.queue_free()
		return null
	projectile_spawned.emit(projectile)
	if is_instance_valid(weapon_visual):
		weapon_visual.rotation = context.initial_direction.angle()
		weapon_visual.flip_v = context.initial_direction.x < 0.0
		weapon_visual.play(&"fire")
		weapon_visual.set_frame_and_progress(0, 0.0)
	return projectile


## 武器作为控制器子节点自动随其清理，多武器各持有独立动画实例。
func _configure_visual() -> void:
	if is_instance_valid(weapon_visual):
		remove_child(weapon_visual)
		weapon_visual.queue_free()
	weapon_visual = null
	if definition.visual_frames == null:
		return
	weapon_visual = AnimatedSprite2D.new()
	weapon_visual.name = "WeaponVisual"
	weapon_visual.sprite_frames = definition.visual_frames
	weapon_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	weapon_visual.scale = Vector2.ONE * 0.22
	add_child(weapon_visual)
	weapon_visual.animation_finished.connect(_on_visual_animation_finished)
	weapon_visual.play(&"idle")
	_update_visual(0.0)


func _update_visual(delta: float) -> void:
	if not is_instance_valid(weapon_visual) or not is_instance_valid(owner_actor):
		return
	_visual_clock += delta
	var moving: bool = owner_actor.velocity.length_squared() > 1.0
	var bob: float = sin(_visual_clock * 12.0) * 2.0 if moving else 0.0
	global_position = owner_actor.global_position + Vector2(44.0, 0).rotated(visual_slot * 1.8) + Vector2(0, 10.0 + bob)


func _on_visual_animation_finished() -> void:
	weapon_visual.play(&"idle")


## 将单局修正合并到控制器，不回写 WeaponDefinition。
func apply_runtime_modifier(modifier: WeaponRuntimeModifier) -> void:
	if modifier == null:
		return
	_pierce_bonus += modifier.pierce_bonus
	_speed_multiplier *= modifier.speed_multiplier
	_size_multiplier *= modifier.size_multiplier
	_critical_chance = clampf(_critical_chance + modifier.critical_chance, 0.0, 1.0)
	_runtime_cooldown_multiplier *= maxf(modifier.cooldown_multiplier, MINIMUM_RUNTIME_MULTIPLIER)
	_runtime_projectile_count_bonus += modifier.projectile_count_bonus
	_runtime_damage_multiplier *= maxf(modifier.damage_multiplier, 0.0)
	_runtime_bonus_projectile_chance = clampf(
		_runtime_bonus_projectile_chance + modifier.bonus_projectile_chance,
		0.0,
		1.0
	)
	_runtime_projectile_lifesteal_ratio = clampf(
		_runtime_projectile_lifesteal_ratio + modifier.projectile_lifesteal_ratio,
		0.0,
		1.0
	)
	_runtime_repeat_shot_chance = clampf(
		_runtime_repeat_shot_chance + modifier.repeat_shot_chance,
		0.0,
		1.0
	)
	_runtime_volley_count_bonus += modifier.volley_count_bonus


func reset_runtime_state() -> void:
	_pierce_bonus = 0
	_speed_multiplier = 1.0
	_size_multiplier = 1.0
	_critical_chance = 0.0
	_repeat_shot_generation += 1
	_cooldown_remaining = 0.0
	_runtime_cooldown_multiplier = 1.0
	_runtime_projectile_count_bonus = 0
	_runtime_damage_multiplier = 1.0
	_runtime_bonus_projectile_chance = 0.0
	_runtime_projectile_lifesteal_ratio = 0.0
	_runtime_repeat_shot_chance = 0.0
	_runtime_volley_count_bonus = 0
	_charge_remaining = -1.0
	_charge_target_position = Vector2.ZERO


func get_effective_cooldown_seconds() -> float:
	if definition == null:
		return MINIMUM_COOLDOWN_SECONDS
	return maxf(definition.cooldown_seconds * _runtime_cooldown_multiplier, MINIMUM_COOLDOWN_SECONDS)


func get_effective_projectile_count() -> int:
	if definition == null:
		return 0
	return maxi(definition.projectile_count + _runtime_projectile_count_bonus, 1)


## 同一次攻击周期内的射击轮数，默认 1；与弹数、穿透相互独立。
func get_effective_volley_count() -> int:
	if definition == null:
		return 1
	return maxi(1 + _runtime_volley_count_bonus, 1)


func get_runtime_damage_multiplier() -> float:
	return _runtime_damage_multiplier


func get_runtime_bonus_projectile_chance() -> float:
	return _runtime_bonus_projectile_chance


func get_runtime_projectile_lifesteal_ratio() -> float:
	return _runtime_projectile_lifesteal_ratio


func get_runtime_repeat_shot_chance() -> float:
	return _runtime_repeat_shot_chance


## 测试可注入固定种子；正式运行仍使用独立随机源。
func set_random_seed(seed: int) -> void:
	_random.seed = seed


## 合并角色攻击范围上限、武器自身射程与全武器射程倍率（D06）。
##
## 索敌范围取“角色上限与武器射程的较小值”，再乘以角色级全武器射程倍率；
## 弹体实际可达距离仍由弹速与寿命决定，两者互不替代。
func get_effective_target_range() -> float:
	if definition == null or not is_instance_valid(owner_actor):
		return 0.0
	var base_range: float = minf(
		maxf(owner_actor.get_attack_range(), 0.0),
		maxf(definition.target_range, 0.0)
	)
	return base_range * maxf(owner_actor.get_weapon_range_multiplier(), 0.0)


func _get_spread_offset_radians(index: int, projectile_count: int) -> float:
	if projectile_count <= 1 or is_zero_approx(definition.spread_degrees):
		return 0.0
	var ratio: float = float(index) / float(projectile_count - 1)
	return deg_to_rad(lerpf(-definition.spread_degrees * 0.5, definition.spread_degrees * 0.5, ratio))


## 在同一冷却周期中追加一颗弹药；只复用当前伤害效果，不递归判定额外射击。
func _fire_repeat_shot_after_delay(
		target_position: Vector2,
		delay_seconds: float,
		generation: int
) -> void:
	await get_tree().create_timer(maxf(delay_seconds, 0.001), false).timeout
	if generation != _repeat_shot_generation or not is_instance_valid(owner_actor):
		return
	if not is_instance_valid(projectile_parent) or owner_actor.health_component.is_dead():
		return
	var direction := owner_actor.get_aim_position().direction_to(target_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var context := ProjectileSpawnContext.new(
		owner_actor,
		owner_actor.get_team_id(),
		owner_actor.get_aim_position(),
		direction
	)
	context.damage_multiplier = _runtime_damage_multiplier
	context.lifesteal_ratio = _runtime_projectile_lifesteal_ratio
	context.weapon_id = definition.id
	if spawn_projectile(definition.projectile_definition, context) == null:
		return
	fire_requested.emit(
		definition,
		owner_actor,
		null,
		projectile_parent,
		1,
		_runtime_damage_multiplier
	)
	weapon_fired.emit(definition.id)


func _disconnect_dependency_signals() -> void:
	if is_instance_valid(owner_actor) and owner_actor.tree_exiting.is_connected(_on_owner_actor_tree_exiting):
		owner_actor.tree_exiting.disconnect(_on_owner_actor_tree_exiting)
	if is_instance_valid(projectile_parent) and projectile_parent.tree_exiting.is_connected(_on_projectile_parent_tree_exiting):
		projectile_parent.tree_exiting.disconnect(_on_projectile_parent_tree_exiting)


func _on_owner_actor_tree_exiting() -> void:
	owner_actor = null
	set_process(false)


func _on_projectile_parent_tree_exiting() -> void:
	projectile_parent = null
	set_process(false)


func _on_targeting_service_tree_exiting() -> void:
	targeting_service = null
