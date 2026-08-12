## P2-05 经验宝石与玩家拾取范围烟雾检查。
##
## 验证角色配置半径、真实 Area 重叠、经验信号和一次性结算。
extends SceneTree

const PLAYER_DEFINITION_PATH := "res://data/characters/player_default.tres"
const EXPERIENCE_GEM_SCENE_PATH := "res://scenes/pickups/experience_gem.tscn"

var _failed: bool = false
var _signal_count: int = 0
var _last_current_experience: int = 0
var _last_gained_amount: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition: CharacterDefinition = load(PLAYER_DEFINITION_PATH) as CharacterDefinition
	var gem_scene: PackedScene = load(EXPERIENCE_GEM_SCENE_PATH) as PackedScene
	_expect(definition != null and definition.scene != null and gem_scene != null, "无法加载玩家配置或经验宝石场景。")
	if definition == null or definition.scene == null or gem_scene == null:
		quit(1)
		return

	var player: PlayerActor = definition.scene.instantiate() as PlayerActor
	root.add_child(player)
	player.initialize(definition)
	player.set_physics_process(false)
	player.experience_changed.connect(_on_experience_changed)
	_expect(is_equal_approx(player.pickup_component.get_pickup_radius(), definition.pickup_radius), "玩家未使用角色配置的拾取范围。")

	var nearby_gem: ExperienceGem = gem_scene.instantiate() as ExperienceGem
	nearby_gem.position = Vector2(definition.pickup_radius - 20.0, 0.0)
	root.add_child(nearby_gem)
	nearby_gem.initialize(3)
	await physics_frame
	await process_frame
	_expect(player.get_current_experience() == 3, "玩家进入拾取范围后未获得经验。")
	_expect(_signal_count == 1 and _last_current_experience == 3 and _last_gained_amount == 3, "经验变化信号参数不正确。")
	_expect(not is_instance_valid(nearby_gem), "结算后的经验宝石未释放。")

	var direct_gem: ExperienceGem = gem_scene.instantiate() as ExperienceGem
	direct_gem.position = Vector2(500.0, 0.0)
	root.add_child(direct_gem)
	direct_gem.initialize(5)
	_expect(direct_gem.collect(player), "有效经验宝石首次结算失败。")
	_expect(not direct_gem.collect(player), "同一经验宝石被重复结算。")
	_expect(player.get_current_experience() == 8 and _signal_count == 2, "一次性结算后的玩家经验不正确。")
	_expect(definition.pickup_radius == 96.0, "拾取组件运行时状态回写了共享角色 Resource。")

	if not _failed:
		print("Experience gem smoke test passed: radius, overlap, signal, and single collection are valid.")
	quit(1 if _failed else 0)


func _on_experience_changed(current_experience: int, gained_amount: int) -> void:
	_signal_count += 1
	_last_current_experience = current_experience
	_last_gained_amount = gained_amount


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
