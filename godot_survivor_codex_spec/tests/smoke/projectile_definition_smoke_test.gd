## P2-04 子弹数据烟雾检查。
##
## 验证默认 ProjectileDefinition 参数和 ProjectileSpawnContext 独立运行时数据。
extends SceneTree

const PROJECTILE_DEFINITION_PATH := "res://data/projectiles/basic_projectile.tres"
const FAST_PROJECTILE_DEFINITION_PATH := "res://data/projectiles/fast_projectile.tres"

var _failed: bool = false


func _initialize() -> void:
	var definition: ProjectileDefinition = load(PROJECTILE_DEFINITION_PATH) as ProjectileDefinition
	_expect(definition != null, "无法加载默认子弹 Resource。")
	if definition == null:
		quit(1)
		return

	_expect(definition.id == &"basic_projectile", "默认子弹 ID 不正确。")
	_expect(is_equal_approx(definition.damage, 10.0), "默认子弹伤害不正确。")
	_expect(is_equal_approx(definition.speed, 600.0), "默认子弹速度不正确。")
	_expect(is_equal_approx(definition.lifetime_seconds, 2.0), "默认子弹寿命不正确。")
	_expect(definition.pierce_count == 0, "默认子弹应只命中一次。")
	_expect(is_equal_approx(definition.hit_radius, 8.0), "默认子弹命中半径不正确。")
	_expect(definition.scene != null, "默认子弹未引用 ProjectileBase 场景。")
	var fast_definition: ProjectileDefinition = load(FAST_PROJECTILE_DEFINITION_PATH) as ProjectileDefinition
	_expect(fast_definition != null, "无法通过第二个 Resource 加载快速子弹。")
	if fast_definition != null:
		_expect(fast_definition.id == &"fast_projectile", "快速子弹 ID 不正确。")
		_expect(is_equal_approx(fast_definition.speed, 900.0), "快速子弹未保留独立速度配置。")
		_expect(is_equal_approx(definition.speed, 600.0), "第二种子弹配置修改了默认共享 Resource。")
		var fast_projectile_node: Node = fast_definition.scene.instantiate()
		_expect(fast_projectile_node is ProjectileBase, "快速子弹 Resource 未复用 ProjectileBase。")
		fast_projectile_node.free()

	var context := ProjectileSpawnContext.new(null, &"player", Vector2(12.0, 34.0), Vector2(10.0, 0.0))
	context.damage_multiplier = 1.5
	context.weapon_id = &"starter_weapon"
	_expect(context.team_id == &"player", "ProjectileSpawnContext 阵营未保存。")
	_expect(context.spawn_position == Vector2(12.0, 34.0), "ProjectileSpawnContext 初始位置未保存。")
	_expect(context.initial_direction == Vector2.RIGHT, "ProjectileSpawnContext 初始方向未归一化。")
	_expect(is_equal_approx(context.damage_multiplier, 1.5), "ProjectileSpawnContext 伤害倍率未保存。")
	_expect(context.weapon_id == &"starter_weapon", "ProjectileSpawnContext 武器 ID 未保存。")

	if not _failed:
		print("Projectile definition smoke test passed: configuration and spawn context are valid.")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
