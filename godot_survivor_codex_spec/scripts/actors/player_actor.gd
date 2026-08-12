## 玩家角色的移动行为。
##
## 输入：CharacterDefinition 和 InputMap 中的四个移动动作。
## 输出：经过归一化的 CharacterBody2D 速度与物理移动。
## 扩展点：后续将把运行时移速和攻击范围修正叠加到基础值上，不修改共享 Resource。
class_name PlayerActor
extends ActorBase

signal experience_changed(current_experience: int, gained_amount: int)
signal level_progress_changed(current_level: int, current_experience: int, required_experience: int)
signal leveled_up(new_level: int, pending_upgrade_count: int)
signal upgrade_state_changed(upgrade_id: StringName, stack_count: int)

var definition: CharacterDefinition
var weapon_controllers: Array[WeaponController] = []
var _move_speed: float = 0.0
var _base_attack_range: float = 0.0
var _current_experience: int = 0
var _current_level_experience: int = 0
var _current_level: int = 1
var _pending_upgrade_count: int = 0
var _upgrade_stacks: Dictionary[StringName, int] = {}
var _move_speed_multiplier: float = 1.0
var _maximum_health_bonus: float = 0.0

@onready var camera: Camera2D = %Camera2D
@onready var pickup_component: PickupComponent = %PickupComponent
@onready var weapon_controller_parent: Node = %WeaponControllers


func _ready() -> void:
	super._ready()
	if not pickup_component.pickup_detected.is_connected(_on_pickup_detected):
		pickup_component.pickup_detected.connect(_on_pickup_detected)


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
	_base_attack_range = maxf(definition.base_attack_range, 0.0)
	var camera_zoom_value: float = clampf(definition.camera_zoom, 0.25, 2.0)
	camera.zoom = Vector2.ONE * camera_zoom_value
	_current_experience = 0
	_current_level_experience = 0
	_current_level = 1
	_pending_upgrade_count = 0
	_upgrade_stacks.clear()
	_move_speed_multiplier = 1.0
	_maximum_health_bonus = 0.0
	pickup_component.initialize(definition.pickup_radius)
	set_physics_process(true)
	level_progress_changed.emit(_current_level, _current_level_experience, get_required_experience())


## 使摄像机与场地边界使用同一份范围。
##
## Camera2D 的 limit 使用整数，因此在边界处向外取整，避免露出场地外的背景。
func configure_camera_bounds(bounds: Rect2) -> void:
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)


## 根据角色配置创建独立的武器控制器，并注入本局服务与容器。
##
## 重复配置会安全停用旧实例；每个起始武器对应一个控制器，支持未来多武器角色。
func configure_weapons(
		weapon_definitions: Array[WeaponDefinition],
		projectile_parent: Node,
		targeting_service: TargetingService
) -> void:
	clear_weapons()
	if not is_instance_valid(projectile_parent) or not is_instance_valid(targeting_service):
		push_error("PlayerActor 武器配置失败：缺少子弹容器或索敌服务。")
		return

	for weapon_definition: WeaponDefinition in weapon_definitions:
		if weapon_definition == null:
			continue
		var controller := WeaponController.new()
		controller.name = "WeaponController_%s" % weapon_definition.id
		weapon_controller_parent.add_child(controller)
		controller.initialize(weapon_definition, self, projectile_parent)
		controller.set_targeting_service(targeting_service)
		weapon_controllers.append(controller)


func clear_weapons() -> void:
	for controller: WeaponController in weapon_controllers:
		if not is_instance_valid(controller):
			continue
		controller.set_process(false)
		controller.queue_free()
	weapon_controllers.clear()


## 增加本局经验，并将跨越的每个等级转化为一项待选择升级。
##
## `_current_experience` 保留本局累计值供统计；HUD 使用独立的等级内经验。
func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	_current_experience += amount
	_current_level_experience += amount
	while _current_level_experience >= get_required_experience():
		_current_level_experience -= get_required_experience()
		_current_level += 1
		_pending_upgrade_count += 1
		leveled_up.emit(_current_level, _pending_upgrade_count)
	experience_changed.emit(_current_experience, amount)
	level_progress_changed.emit(_current_level, _current_level_experience, get_required_experience())


func get_current_experience() -> int:
	return _current_experience


func get_current_level_experience() -> int:
	return _current_level_experience


func get_current_level() -> int:
	return _current_level


## 返回当前等级升至下一级所需经验，经验曲线只在此处维护。
func get_required_experience(level: int = _current_level) -> int:
	return 5 + maxi(level, 1) * 3


func get_pending_upgrade_count() -> int:
	return _pending_upgrade_count


func consume_pending_upgrade() -> bool:
	if _pending_upgrade_count <= 0:
		return false
	_pending_upgrade_count -= 1
	return true


func get_upgrade_stack(upgrade_id: StringName) -> int:
	return _upgrade_stacks.get(upgrade_id, 0)


## 将一个升级效果写入玩家和武器的单局状态，不回写任何共享 Resource。
func apply_upgrade(upgrade: UpgradeDefinition) -> bool:
	if upgrade == null or upgrade.id == StringName():
		return false
	match upgrade.type:
		UpgradeDefinition.UpgradeType.DAMAGE_MULTIPLIER:
			_apply_weapon_modifier(WeaponRuntimeModifier.new(1.0, 0, 1.0 + upgrade.value))
		UpgradeDefinition.UpgradeType.FIRE_RATE_MULTIPLIER:
			_apply_weapon_modifier(WeaponRuntimeModifier.new(maxf(1.0 - upgrade.value, 0.05), 0, 1.0))
		UpgradeDefinition.UpgradeType.PROJECTILE_COUNT:
			_apply_weapon_modifier(WeaponRuntimeModifier.new(1.0, roundi(upgrade.value), 1.0))
		UpgradeDefinition.UpgradeType.MOVE_SPEED_MULTIPLIER:
			_move_speed_multiplier *= maxf(1.0 + upgrade.value, 0.0)
		UpgradeDefinition.UpgradeType.MAX_HEALTH:
			_maximum_health_bonus += upgrade.value
			health_component.set_maximum_health(get_effective_maximum_health(), true)
		UpgradeDefinition.UpgradeType.HEAL:
			health_component.heal(upgrade.value)
		_:
			return false

	var new_stack_count: int = get_upgrade_stack(upgrade.id) + 1
	_upgrade_stacks[upgrade.id] = new_stack_count
	upgrade_state_changed.emit(upgrade.id, new_stack_count)
	return true


func get_effective_move_speed() -> float:
	return _move_speed * _move_speed_multiplier


func get_effective_maximum_health() -> float:
	var base_health: float = definition.max_health if definition != null else 0.0
	return maxf(base_health + _maximum_health_bonus, 0.0)


func _physics_process(_delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down"
	)
	velocity = input_direction * get_effective_move_speed()
	move_and_slide()


func get_team_id() -> StringName:
	return &"player"


func get_attack_range() -> float:
	return _base_attack_range


func _on_pickup_detected(pickup: Area2D) -> void:
	if pickup is ExperienceGem:
		(pickup as ExperienceGem).collect(self)


func _get_base_max_health() -> float:
	return definition.max_health if definition != null else 1.0


func _apply_weapon_modifier(modifier: WeaponRuntimeModifier) -> void:
	for controller: WeaponController in weapon_controllers:
		if is_instance_valid(controller):
			controller.apply_runtime_modifier(modifier)
