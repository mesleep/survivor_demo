## 玩家用于检测可拾取 Area2D 的范围组件。
##
## 输入：角色配置中的拾取半径和进入范围的 Area2D。
## 输出：pickup_detected 信号；具体物品规则由拥有者处理。
## 扩展点：后续可叠加运行时拾取范围修正，不修改共享角色 Resource。
class_name PickupComponent
extends Area2D

signal pickup_detected(pickup: Area2D)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


## 设置本实例的圆形拾取范围；半径无效时安全停用检测。
func initialize(radius: float) -> void:
	var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
	if circle_shape == null:
		push_error("PickupComponent 初始化失败：CollisionShape2D 必须使用 CircleShape2D。")
		monitoring = false
		return
	circle_shape.radius = maxf(radius, 0.0)
	monitoring = circle_shape.radius > 0.0


func get_pickup_radius() -> float:
	var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
	return circle_shape.radius if circle_shape != null else 0.0


func _on_area_entered(area: Area2D) -> void:
	if not is_instance_valid(area) or area.is_queued_for_deletion():
		return
	pickup_detected.emit(area)
