## 基础游戏场地的可视化与范围数据。
##
## 输入：场地尺寸和网格间距。
## 输出：用于 Camera2D 限制的 Rect2，以及可观察摄像机移动的简单网格。
## 物理边界由 arena.tscn 中的 World 碰撞体提供。
class_name Arena
extends Node2D

const BACKGROUND_COLOR := Color("17233a")
const GRID_COLOR := Color("263958")
const BORDER_COLOR := Color("4f78a8")

@export var size: Vector2 = Vector2(2560.0, 1440.0)
## 背景仅负责装饰，不改变已有边界和碰撞。
@export var background_texture: Texture2D
@export_range(32.0, 512.0, 1.0) var grid_spacing: float = 128.0


func get_bounds() -> Rect2:
	return Rect2(-size * 0.5, size)


func _draw() -> void:
	var bounds: Rect2 = get_bounds()
	if background_texture != null:
		draw_texture_rect(background_texture, bounds, false)
		draw_rect(bounds, BORDER_COLOR, false, 8.0)
		return
	draw_rect(bounds, BACKGROUND_COLOR)

	var spacing: int = maxi(roundi(grid_spacing), 1)
	for x: int in range(floori(bounds.position.x), ceili(bounds.end.x) + 1, spacing):
		draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), GRID_COLOR, 1.0)
	for y: int in range(floori(bounds.position.y), ceili(bounds.end.y) + 1, spacing):
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), GRID_COLOR, 1.0)

	draw_rect(bounds, BORDER_COLOR, false, 8.0)
