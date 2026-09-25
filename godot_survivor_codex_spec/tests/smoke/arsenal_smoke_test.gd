## 多弹与穿透隔离、新武器轨迹、专属强化和晚获取继承的专项回归。
extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = (load("res://tests/fixtures/legacy_main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var session: GameSession = main.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var wand: WeaponController = player.weapon_controllers[0]
	wand.set_process(false)
	var enemy: EnemyActor = session.enemy_spawner.spawn_enemy(session.enemy_spawn_settings.enemy_definition, Vector2(240, 0), true)
	enemy.set_physics_process(false)
	check(player.apply_upgrade(load("res://data/upgrades/projectile_count_up.tres")), "弹数升级失败")
	check(wand.request_fire(enemy), "多弹发射失败")
	var first: ProjectileBase = session.projectiles.get_child(0) as ProjectileBase
	var second: ProjectileBase = session.projectiles.get_child(1) as ProjectileBase
	check(session.projectiles.get_child_count() == 2, "弹数 +1 未产生两颗弹")
	check(first.direction.distance_to(second.direction) > 0.1, "多弹仍重叠")
	check(first.get_remaining_pierces() == 0 and second.get_remaining_pierces() == 0, "弹数升级错误增加穿透")
	check(player.apply_upgrade(load("res://data/upgrades/pierce_up.tres")), "穿透升级失败")
	check(wand.get_effective_projectile_count() == 2, "穿透升级错误增加弹数")
	var context := ProjectileSpawnContext.new(player, &"player", Vector2.ZERO, Vector2.RIGHT)
	var pierced: ProjectileBase = wand.spawn_projectile(wand.definition.projectile_definition, context)
	check(pierced.get_remaining_pierces() == 1, "独立穿透未生效")
	check(wand.definition.projectile_definition.pierce_count == 0, "共享穿透数据被修改")
	var special: UpgradeDefinition = load("res://data/upgrades/bell_mastery.tres")
	check(not session.upgrade_system.can_offer(special), "未持有铃铛却提供专属升级")
	for name: String in ["leaf", "bone", "bell"]:
		var acquire: UpgradeDefinition = load("res://data/upgrades/acquire_%s.tres" % name)
		check(player.apply_upgrade(acquire), "获取武器失败：" + name)
		check(not session.upgrade_system.can_offer(acquire), "重复提供已有武器")
		var weapon: WeaponController = player.weapon_controllers.back()
		weapon.set_process(false)
		check(weapon.get_effective_projectile_count() == weapon.definition.projectile_count + 1, "新武器未继承通用弹数")
	check(session.upgrade_system.can_offer(special), "持有铃铛后专属升级未解锁")
	check(player.apply_upgrade(special), "铃铛专属强化失败")
	var bell: WeaponController = player.weapon_controllers[3]
	var orb: ProjectileBase = bell.spawn_projectile(bell.definition.projectile_definition, ProjectileSpawnContext.new(player, &"player", Vector2.ZERO, Vector2.RIGHT))
	orb._physics_process(0.2)
	check(is_equal_approx(orb.global_position.distance_to(player.global_position), 130.0), "环绕半径或专属增幅错误")
	check(is_equal_approx(pierced.context.size_multiplier, 1.0), "专属强化污染魔杖")
	var bone: WeaponController = player.weapon_controllers[2]
	var returning: ProjectileBase = bone.spawn_projectile(bone.definition.projectile_definition, ProjectileSpawnContext.new(player, &"player", Vector2.ZERO, Vector2.RIGHT))
	returning._physics_process(0.5)
	var distance_before: float = returning.position.length()
	returning._physics_process(0.6)
	check(returning.position.length() < distance_before, "骨棒未返回")
	var critical := WeaponRuntimeModifier.new()
	critical.critical_chance = 1.0
	wand.apply_runtime_modifier(critical)
	var target_definition: EnemyDefinition = session.enemy_spawn_settings.enemy_definition.duplicate()
	target_definition.max_health = 100.0
	var durable: EnemyActor = session.enemy_spawner.spawn_enemy(target_definition, Vector2(500, 200), true)
	durable.set_physics_process(false)
	var critical_bolt: ProjectileBase = wand.spawn_projectile(wand.definition.projectile_definition, ProjectileSpawnContext.new(player, &"player", Vector2.ZERO, Vector2.RIGHT))
	critical_bolt.on_hit(durable)
	check(is_equal_approx(durable.health_component.current_health, 100.0 - wand.definition.projectile_definition.damage * 2.0), "暴击没有造成双倍伤害")
	check(player.apply_upgrade(load("res://data/upgrades/regeneration.tres")), "恢复升级失败")
	player.health_component.current_health = 50.0
	player._physics_process(1.0)
	check(player.health_component.current_health == 51.0, "每秒自然恢复未生效")
	check(player.apply_upgrade(load("res://data/upgrades/projectile_speed_up.tres")), "弹速升级失败")
	var quick: ProjectileBase = wand.spawn_projectile(wand.definition.projectile_definition, ProjectileSpawnContext.new(player, &"player", Vector2.ZERO, Vector2.RIGHT))
	quick._physics_process(0.1)
	check(is_equal_approx(quick.position.x, wand.definition.projectile_definition.speed * 0.12), "弹速升级未影响移动距离")
	for name: String in ["huniu", "heibao", "xiaosi", "xiaoqi", "leaf", "bone", "bell"]:
		var frames: SpriteFrames = load("res://data/visuals/%s_frames.tres" % name)
		check(frames.get_frame_count(&"walk") == 4, "缺少动画帧：" + name)
		for index: int in range(4):
			var atlas: AtlasTexture = frames.get_frame_texture(&"walk", index)
			check(atlas.region.end.x <= atlas.atlas.get_width() and atlas.region.end.y <= atlas.atlas.get_height(), "图集越界：" + name)
	if "--capture" in OS.get_cmdline_user_args():
		for child: Node in session.enemies.get_children():
			child.queue_free()
		player.position = Vector2.ZERO
		player.camera.zoom = Vector2.ONE
		for index: int in range(4):
			var name: String = ["enemy_basic", "enemy_fast", "xiaosi", "xiaoqi"][index]
			var pet: EnemyActor = session.enemy_spawner.spawn_enemy(load("res://data/enemies/%s.tres" % name), Vector2(-230 + index * 150, 140), true)
			pet.set_physics_process(false)
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/survivor_four_pets.png")
		session.upgrade_system.request_choices(3)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/survivor_upgrades.png")
	main.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("武器扩展专项：" + ("失败" if failed else "通过"))
	quit(1 if failed else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
