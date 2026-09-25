## 地面持续伤害区域（T17 火坑）。
##
## 输入：GroundDamageAreaDefinition、来源、阵营、伤害倍率与持续时间倍率。
## 输出：按固定 tick 间隔对范围内敌人结算带 dot/ground 标签的伤害。
## 与“火舌命中挂 DoT”分开实现，避免一次碰撞每帧无上限扣血。
class_name GroundDamageArea
extends Node2D

signal tick_damage(center: Vector2, hit_count: int)

var _definition: GroundDamageAreaDefinition
var _source: Node
var _team_id: StringName = &"neutral"
var _damage_multiplier: float = 1.0
var _duration: float = 0.0
var _elapsed: float = 0.0
var _ticks_done: int = 0
var _visual: AnimatedSprite2D


## 配置区域；来源离树后区域继续存在到时长结束，但不再持有来源引用。
func setup(
		definition: GroundDamageAreaDefinition,
		source: Node,
		team_id: StringName,
		damage_multiplier: float = 1.0,
		duration_multiplier: float = 1.0
) -> void:
	_definition = definition
	_source = source
	_team_id = team_id
	_damage_multiplier = maxf(damage_multiplier, 0.0)
	_duration = maxf(definition.duration_seconds * maxf(duration_multiplier, 0.0), 0.1) \
		if definition != null else 0.1
	if is_instance_valid(_source):
		_source.tree_exiting.connect(_on_source_tree_exiting)
	_configure_visual()
	queue_redraw()


func _process(delta: float) -> void:
	advance_time(delta)


## 推进指定时间；测试传入固定步长即可精确断言 tick 数与进出范围。
func advance_time(delta: float) -> void:
	if _definition == null:
		finish()
		return
	_elapsed += maxf(delta, 0.0)
	var interval: float = maxf(_definition.tick_interval_seconds, 0.05)
	var maximum_ticks: int = int(floor(_duration / interval + 0.0001))
	while _ticks_done < maximum_ticks \
			and _elapsed + 0.0001 >= float(_ticks_done + 1) * interval:
		_apply_tick()
		_ticks_done += 1
	if _elapsed >= _duration - 0.0001:
		finish()


func finish() -> void:
	queue_free()


func get_elapsed_seconds() -> float:
	return _elapsed


func get_duration_seconds() -> float:
	return _duration


func _apply_tick() -> void:
	var targets: Array[ActorBase] = AreaHitResolver.collect_actors(
		get_world_2d(),
		global_position,
		_definition.radius,
		_definition.collision_mask,
		_team_id,
		_definition.max_targets
	)
	var damage: float = maxf(_definition.damage_per_tick * _damage_multiplier, 0.0)
	var source_node: Node = _source if is_instance_valid(_source) else null
	for actor: ActorBase in targets:
		var event := DamageEvent.new(damage, source_node, global_position)
		event.tags = [&"dot", &"ground"]
		if _definition.id != StringName():
			event.tags.append(_definition.id)
		actor.apply_damage(event)
	tick_damage.emit(global_position, targets.size())
	queue_redraw()


func _on_source_tree_exiting() -> void:
	_source = null


## 有 E02 火坑素材时用序列帧，否则保留代码绘制的地面圆环。
func _configure_visual() -> void:
	if _definition == null or _definition.visual_frames == null:
		return
	if not is_instance_valid(_visual):
		_visual = AnimatedSprite2D.new()
		_visual.name = "GroundAreaVisual"
		_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_visual)
	_visual.sprite_frames = _definition.visual_frames
	if _definition.visual_frames.has_animation(&"default"):
		_visual.play(&"default")
	var texture: Texture2D = _definition.visual_frames.get_frame_texture(&"default", 0)
	if texture != null:
		var texture_width: float = maxf(float(texture.get_width()), 1.0)
		_visual.scale = Vector2.ONE * (_definition.radius * 2.0 / texture_width) * maxf(_definition.visual_scale, 0.01)


func _draw() -> void:
	if _definition == null:
		return
	if is_instance_valid(_visual) and _definition.visual_frames != null:
		return
	var progress: float = clampf(_elapsed / _duration, 0.0, 1.0) if _duration > 0.0 else 1.0
	var faded: Color = _definition.visual_color
	faded.a *= clampf(0.35 + 0.65 * (1.0 - progress), 0.0, 1.0)
	draw_circle(Vector2.ZERO, _definition.radius * _definition.visual_scale, faded)
	draw_arc(
		Vector2.ZERO,
		_definition.radius * _definition.visual_scale,
		0.0,
		TAU,
		40,
		faded,
		2.0,
		true
	)
