## 反伤刺甲的持续刺圈组件（T21）。
##
## 输入：ThornArmorDefinition、所属玩家与半径倍率。
## 输出：按固定周期对周围敌人结算带 reflect 标签的伤害，并发布 tick 信号。
## 与“受击返还”分开：刺圈是周期区域能力，返还由 ActorBase 统一伤害管线处理。
class_name ThornAuraComponent
extends Node2D

signal aura_ticked(hit_count: int)

var _owner_actor: ActorBase
var _definition: ThornArmorDefinition
var _radius_multiplier: float = 1.0
var _elapsed: float = 0.0
var _tick_count: int = 0
var _visual: AnimatedSprite2D


func initialize(owner_actor: ActorBase, definition: ThornArmorDefinition) -> void:
	_owner_actor = owner_actor
	_definition = definition
	_elapsed = 0.0
	_tick_count = 0
	_configure_visual()
	queue_redraw()


## 调整刺圈半径倍率（专属升级）；只改运行时，不回写资源。
func set_radius_multiplier(multiplier: float) -> void:
	_radius_multiplier = maxf(multiplier, 0.0)
	_update_visual_scale()
	queue_redraw()


## 有 E04 素材时用序列帧，否则保留代码绘制的占位圆环。
func _configure_visual() -> void:
	if _definition == null or _definition.visual_frames == null or not is_instance_valid(_owner_actor):
		return
	if not is_instance_valid(_visual):
		_visual = AnimatedSprite2D.new()
		_visual.name = "ThornAuraVisual"
		_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_owner_actor.add_child(_visual)
	_visual.sprite_frames = _definition.visual_frames
	if _definition.visual_frames.has_animation(&"default"):
		_visual.play(&"default")
	_update_visual_scale()


func _update_visual_scale() -> void:
	if not is_instance_valid(_visual) or _definition == null or _definition.visual_frames == null:
		return
	var texture: Texture2D = _definition.visual_frames.get_frame_texture(&"default", 0)
	if texture == null:
		return
	var texture_width: float = maxf(float(texture.get_width()), 1.0)
	var desired_width: float = get_effective_radius() * 2.0
	_visual.scale = Vector2.ONE * (desired_width / texture_width) * maxf(_definition.visual_scale, 0.01)


func get_effective_radius() -> float:
	if _definition == null:
		return 0.0
	return maxf(_definition.aura_radius * _radius_multiplier, 0.0)


func get_tick_count() -> int:
	return _tick_count


func _process(delta: float) -> void:
	advance_time(delta)


## 推进指定时间；测试传入固定步长即可精确断言刺圈 tick 数。
func advance_time(delta: float) -> void:
	if _definition == null or delta <= 0.0:
		return
	if not is_instance_valid(_owner_actor) or _owner_actor.health_component.is_dead():
		return
	_elapsed += delta
	var interval: float = maxf(_definition.aura_tick_interval_seconds, 0.05)
	while _elapsed + 0.0001 >= float(_tick_count + 1) * interval:
		_apply_tick()
		_tick_count += 1


func _apply_tick() -> void:
	var targets: Array[ActorBase] = AreaHitResolver.collect_actors(
		get_world_2d(),
		_owner_actor.global_position,
		get_effective_radius(),
		_definition.collision_mask,
		_owner_actor.get_team_id(),
		_definition.max_targets
	)
	for actor: ActorBase in targets:
		var event := DamageEvent.new(_definition.aura_damage_per_tick, _owner_actor, _owner_actor.global_position)
		# reflect 标签按 D07 阻止递归，刺圈不会反过来触发敌人反伤。
		event.tags = [&"reflect", &"thorns"]
		actor.apply_damage(event)
	aura_ticked.emit(targets.size())
	queue_redraw()


func _draw() -> void:
	if _definition == null or not is_instance_valid(_owner_actor):
		return
	if is_instance_valid(_visual) and _definition.visual_frames != null:
		return
	var radius: float = get_effective_radius()
	var color: Color = _definition.visual_color
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.6), 2.0, true)
