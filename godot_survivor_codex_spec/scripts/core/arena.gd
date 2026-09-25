## 基础游戏场地的可视化与范围数据。
##
## 输入：场地尺寸、背景贴图、网格间距与配色（可由 ArenaDefinition 注入）。
## 输出：用于 Camera2D 限制的 Rect2，以及可观察摄像机移动的网格/背景。
## 物理边界由 arena.tscn 中的 World 碰撞体提供；换图时尺寸需与边界一致（T33）。
class_name Arena
extends Node2D

@export var definition: ArenaDefinition
@export var size: Vector2 = Vector2(2560.0, 1440.0)
## 背景仅负责装饰，不改变已有边界和碰撞。
@export var background_texture: Texture2D
@export_range(32.0, 512.0, 1.0) var grid_spacing: float = 128.0

var _background_color: Color = Color("17233a")
var _grid_color: Color = Color("263958")
var _border_color: Color = Color("4f78a8")


## 应用地图定义（T33）；为空时保持场景当前配置。
func configure(new_definition: ArenaDefinition) -> void:
	if new_definition == null:
		return
	definition = new_definition
	size = new_definition.size
	background_texture = new_definition.background_texture
	grid_spacing = new_definition.grid_spacing
	_background_color = new_definition.background_color
	_grid_color = new_definition.grid_color
	_border_color = new_definition.border_color
	queue_redraw()


func get_definition() -> ArenaDefinition:
	return definition


func get_bounds() -> Rect2:
	return Rect2(-size * 0.5, size)


func _draw() -> void:
	var bounds: Rect2 = get_bounds()
	if background_texture != null:
		draw_texture_rect(background_texture, bounds, false)
		draw_rect(bounds, _border_color, false, 8.0)
		return
	draw_rect(bounds, _background_color)

	var spacing: int = maxi(roundi(grid_spacing), 1)
	for x: int in range(floori(bounds.position.x), ceili(bounds.end.x) + 1, spacing):
		draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), _grid_color, 1.0)
	for y: int in range(floori(bounds.position.y), ceili(bounds.end.y) + 1, spacing):
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), _grid_color, 1.0)

	draw_rect(bounds, _border_color, false, 8.0)
