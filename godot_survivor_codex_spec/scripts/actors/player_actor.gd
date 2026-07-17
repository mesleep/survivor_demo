## 玩家角色的移动行为。
##
## 输入：CharacterDefinition 和 InputMap 中的四个移动动作。
## 输出：经过归一化的 CharacterBody2D 速度与物理移动。
## 扩展点：后续将把运行时移速修正叠加到基础速度上，不修改共享 Resource。
class_name PlayerActor
extends ActorBase

var definition: CharacterDefinition
var _move_speed: float = 0.0

@onready var camera: Camera2D = %Camera2D


## 从共享配置初始化玩家的基础运行时数据。
##
## 该方法只读取 Resource；单局修正不得回写配置。
func initialize(new_definition: Resource) -> void:
	if new_definition is not CharacterDefinition:
		push_error("PlayerActor 初始化失败：Resource 必须是 CharacterDefinition。")
		set_physics_process(false)
		return

	definition = new_definition as CharacterDefinition
	super.initialize(new_definition)
	_move_speed = maxf(definition.move_speed, 0.0)
	set_physics_process(true)


## 使摄像机与场地边界使用同一份范围。
##
## Camera2D 的 limit 使用整数，因此在边界处向外取整，避免露出场地外的背景。
func configure_camera_bounds(bounds: Rect2) -> void:
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)


func _physics_process(_delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down"
	)
	velocity = input_direction * _move_speed
	move_and_slide()


func get_team_id() -> StringName:
	return &"player"


func _get_base_max_health() -> float:
	return definition.max_health if definition != null else 1.0
