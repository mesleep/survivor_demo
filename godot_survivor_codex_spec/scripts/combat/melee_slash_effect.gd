## 近战扇形斩击的表现节点（T32）。
##
## 只绘制一段随时间淡出的弧光；伤害与命中由 WeaponController._perform_melee 负责。
## 未提供 C05 斩击素材时使用占位弧光，提供素材后可替换为序列帧。
class_name MeleeSlashEffect
extends Node2D

var _radius: float = 100.0
var _arc_degrees: float = 110.0
var _duration: float = 0.18
var _remaining: float = 0.18
var _color: Color = Color(0.95, 0.95, 1.0, 0.55)


## direction 决定弧光朝向；半径与角度来自武器配置。
func setup(radius: float, arc_degrees: float, direction: Vector2, duration: float) -> void:
	_radius = maxf(radius, 0.0)
	_arc_degrees = clampf(arc_degrees, 1.0, 360.0)
	_duration = maxf(duration, 0.05)
	_remaining = _duration
	rotation = direction.angle()
	queue_redraw()


func _process(delta: float) -> void:
	_remaining = maxf(_remaining - delta, 0.0)
	queue_redraw()
	if _remaining <= 0.0:
		queue_free()


func _draw() -> void:
	var progress: float = 1.0 - (_remaining / _duration) if _duration > 0.0 else 1.0
	var faded: Color = _color
	faded.a *= clampf(1.0 - progress, 0.0, 1.0)
	var half_arc: float = deg_to_rad(_arc_degrees * 0.5)
	draw_arc(Vector2.ZERO, _radius * (0.7 + 0.3 * progress), -half_arc, half_arc, 32, faded, 6.0, true)
