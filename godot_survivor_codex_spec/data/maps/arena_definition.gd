## 地图（竞技场）的共享只读配置（T33）。
##
## 输入：尺寸、背景贴图、网格间距与配色。
## 输出：供 Arena 应用；不改变物理边界节点，地图切换时尺寸需与边界一致。
class_name ArenaDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var size: Vector2 = Vector2(2560.0, 1440.0)
## 背景图；为空时按配色绘制网格（素材未交付前的占位）。
@export var background_texture: Texture2D
@export_range(32.0, 512.0, 1.0) var grid_spacing: float = 128.0
@export var background_color: Color = Color("17233a")
@export var grid_color: Color = Color("263958")
@export var border_color: Color = Color("4f78a8")
