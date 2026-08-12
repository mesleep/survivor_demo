## 概率额外弹、子弹吸血和拾取范围升级烟雾检查。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"

var _failed: bool = false
var _spawned_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var controller: WeaponController = player.weapon_controllers[0]
	controller.set_process(false)
	var upgrades := _index_upgrades(session.upgrade_system.upgrade_pool)
	_expect(upgrades.has(&"bonus_projectile_chance_up") and upgrades.has(&"projectile_lifesteal_up") and upgrades.has(&"pickup_range_up"), "升级池缺少新增的三类升级。")

	var base_radius: float = player.definition.pickup_radius
	_expect(player.apply_upgrade(upgrades[&"pickup_range_up"]), "拾取范围升级应用失败。")
	_expect(is_equal_approx(player.get_effective_pickup_radius(), base_radius * 1.25), "拾取范围运行时结果不正确。")
	_expect(is_equal_approx(player.pickup_component.get_pickup_radius(), base_radius * 1.25), "拾取碰撞 Shape 未同步扩大。")
	_expect(is_equal_approx(player.definition.pickup_radius, base_radius), "拾取范围升级回写了 CharacterDefinition。")

	controller.apply_runtime_modifier(WeaponRuntimeModifier.new(1.0, 0, 1.0, 1.0, 0.0))
	_expect(is_equal_approx(controller.get_runtime_bonus_projectile_chance(), 1.0), "额外弹概率未写入武器运行时状态。")
	var enemy: EnemyActor = session.enemy_spawner.spawn_enemy(session.enemy_spawn_settings.enemy_definition, Vector2(400.0, 0.0), true)
	enemy.set_physics_process(false)
	controller.projectile_spawned.connect(_on_projectile_spawned)
	_expect(controller.request_fire(enemy), "100% 额外弹概率下发射失败。")
	_expect(_spawned_count == controller.definition.projectile_count + 1, "100% 概率未多生成一颗子弹。")
	controller.reset_runtime_state()
	_expect(is_zero_approx(controller.get_runtime_bonus_projectile_chance()), "重置后额外弹概率未清空。")

	player.apply_damage(DamageEvent.new(50.0, null, Vector2.ZERO))
	var health_before: float = player.health_component.current_health
	enemy.free_on_death = false
	var remaining_enemy_health := minf(
		controller.definition.projectile_definition.damage * 0.5,
		enemy.health_component.maximum_health
	)
	enemy.apply_damage(DamageEvent.new(
		enemy.health_component.maximum_health - remaining_enemy_health,
		player,
		enemy.global_position
	))
	var context := ProjectileSpawnContext.new(player, &"player", player.global_position, Vector2.RIGHT)
	context.lifesteal_ratio = 0.1
	var projectile: ProjectileBase = controller.spawn_projectile(controller.definition.projectile_definition, context)
	projectile.free_on_deactivate = false
	_expect(projectile.on_hit(enemy), "吸血子弹未命中有效敌人。")
	var expected_heal: float = remaining_enemy_health * 0.1
	_expect(is_equal_approx(player.health_component.current_health, health_before + expected_heal), "子弹吸血治疗量不正确。")

	controller.reset_runtime_state()
	_expect(player.apply_upgrade(upgrades[&"bonus_projectile_chance_up"]), "概率升级 Resource 无法应用。")
	_expect(player.apply_upgrade(upgrades[&"projectile_lifesteal_up"]), "吸血升级 Resource 无法应用。")
	_expect(is_equal_approx(controller.get_runtime_bonus_projectile_chance(), 0.15), "概率升级数值不正确。")
	_expect(is_equal_approx(controller.get_runtime_projectile_lifesteal_ratio(), 0.03), "吸血升级数值不正确。")

	if not _failed:
		print("Advanced upgrade smoke test passed: bonus projectile chance, lifesteal, and pickup range are valid.")
	quit(1 if _failed else 0)


func _index_upgrades(pool: Array[UpgradeDefinition]) -> Dictionary[StringName, UpgradeDefinition]:
	var indexed: Dictionary[StringName, UpgradeDefinition] = {}
	for definition: UpgradeDefinition in pool:
		indexed[definition.id] = definition
	return indexed


func _on_projectile_spawned(_projectile: ProjectileBase) -> void:
	_spawned_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
