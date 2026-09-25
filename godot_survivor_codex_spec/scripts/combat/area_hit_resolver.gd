## 一次性范围命中的受控查询工具（T16）。
##
## 输入：物理世界、圆心、半径、碰撞掩码、需要排除的阵营与目标上限。
## 输出：按 Actor 实例去重的存活目标列表；只读查询，不修改任何节点状态。
## 扩展点：后续可加入视线、扇形角度或标签过滤，而不改动爆炸弹体。
class_name AreaHitResolver
extends RefCounted


## 使用圆形形状查询一次物理空间；只查询 Area（Hurtbox），不查询实体避免重复。
##
## 同一次爆炸内以 Actor 实例 ID 去重；已死亡、已释放或同阵营目标会被过滤。
static func collect_actors(
		world: World2D,
		origin: Vector2,
		radius: float,
		collision_mask: int,
		exclude_team: StringName,
		max_targets: int = 64
) -> Array[ActorBase]:
	var actors: Array[ActorBase] = []
	if world == null or radius <= 0.0 or max_targets <= 0:
		return actors
	var space: PhysicsDirectSpaceState2D = world.direct_space_state
	if space == null:
		return actors

	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, origin)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var seen: Dictionary[int, bool] = {}
	for result: Dictionary in space.intersect_shape(query, max_targets):
		var actor: ActorBase = _resolve_actor(result.get("collider"))
		if actor == null:
			continue
		if actor.health_component.is_dead() or actor.is_queued_for_deletion():
			continue
		if exclude_team != StringName() and actor.get_team_id() == exclude_team:
			continue
		var actor_id: int = actor.get_instance_id()
		if seen.has(actor_id):
			continue
		seen[actor_id] = true
		actors.append(actor)
		if actors.size() >= max_targets:
			break
	return actors


static func _resolve_actor(collider: Variant) -> ActorBase:
	if collider is HurtboxComponent:
		return (collider as HurtboxComponent).owner_actor
	if collider is ActorBase:
		return collider as ActorBase
	return null
