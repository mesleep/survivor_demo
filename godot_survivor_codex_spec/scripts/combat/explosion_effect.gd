## 一次性范围爆炸的表现节点（T16）。
##
## 只负责播放/绘制透明爆炸特效并在时长结束后自清理；
## 伤害查询与结算由 AreaHitResolver 和 ProjectileBase 完成，表现层不承担规则。
## 未提供 E02 正式素材时绘制占位圆环，提供 visual_frames 后自动改用序列帧。
class_name ExplosionEffect
extends Node2D

var _duration: float = 0.3
var _remaining: float = 0.3
var _radius: float = 90.0
var _color: Color = Color(1.0, 0.62, 0.24, 0.55)
var _frames: SpriteFrames
var _sprite: AnimatedSprite2D


## 按 ExplosionDefinition 配置特效；半径只影响占位绘制，不改变伤害判定。
func setup(
		radius: float,
		duration_seconds: float,
		color: Color,
		frames: SpriteFrames,
		visual_scale: float
) -> void:
	_radius = maxf(radius, 0.0)
	_duration = maxf(duration_seconds, 0.05)
	_remaining = _duration
	_color = color
	_frames = frames
	if _frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = _frames
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_sprite.scale = Vector2.ONE * maxf(visual_scale, 0.01)
		add_child(_sprite)
		if _sprite.sprite_frames.has_animation(&"default"):
			_sprite.play(&"default")
	queue_redraw()


func _process(delta: float) -> void:
	_remaining = maxf(_remaining - delta, 0.0)
	queue_redraw()
	if _remaining <= 0.0:
		finish()


## 立即结束表现并释放节点；供结算清理与测试调用。
func finish() -> void:
	queue_free()


func _draw() -> void:
	if _frames != null:
		return
	var progress: float = 1.0 - (_remaining / _duration) if _duration > 0.0 else 1.0
	var faded: Color = _color
	faded.a *= clampf(1.0 - progress, 0.0, 1.0)
	draw_circle(Vector2.ZERO, _radius * (0.55 + 0.45 * progress), faded)
	draw_arc(Vector2.ZERO, _radius * progress, 0.0, TAU, 48, faded, 3.0, true)
