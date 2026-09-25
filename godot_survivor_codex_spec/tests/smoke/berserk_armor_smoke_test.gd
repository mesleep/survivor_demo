## T23：狂战盔甲专项回归。
##
## 覆盖固定失血与非致死、半血增吸血与武器结算、一次免死（含 DoT 致命）、失血减免、
## 分支互斥与重新初始化清理。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"
const ARMOR_PATH := "res://data/armor/armor_basic.tres"
const THORN_PATH := "res://data/upgrades/armor_thorns.tres"
const KNIGHT_PATH := "res://data/upgrades/armor_knight.tres"
const BERSERK_PATH := "res://data/upgrades/armor_berserk.tres"
const DRAIN_UP_PATH := "res://data/upgrades/armor_berserk_drain_up.tres"
const LIFESTEAL_UP_PATH := "res://data/upgrades/armor_berserk_lifesteal_up.tres"
const IMMUNITY_PATH := "res://data/upgrades/armor_berserk_immunity.tres"
const ARMOR_BASE_UP_PATH := "res://data/upgrades/armor_basic_up.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_drain_fixed_and_nonlethal()
	await _test_half_health_lifesteal()
	await _test_death_immunity_once()
	await _test_exclusive_branches()
	await _test_drain_reduction()
	await _test_reinitialize_resets()
	if not _failed:
		print("Berserk armor smoke test passed: drain, lifesteal, immunity, limits and cleanup are valid.")
	quit(1 if _failed else 0)


## 每秒固定失血；默认不会把自己扣死。
func _test_drain_fixed_and_nonlethal() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_enable_berserk(player)
	var drain: BerserkDrainComponent = player.get_berserk_drain()
	drain.set_process(false)

	drain.advance_time(1.0)
	_expect(is_equal_approx(player.health_component.current_health, 97.0), "1 秒后应失血 3。")
	drain.advance_time(1.0)
	_expect(is_equal_approx(player.health_component.current_health, 94.0), "2 秒后应累计失血 6。")

	player.health_component.apply_damage(DamageEvent.new(93.0, null, Vector2.ZERO))
	_expect(is_equal_approx(player.health_component.current_health, 1.0), "应先把玩家压到 1 点。")
	drain.advance_time(1.0)
	_expect(is_equal_approx(player.health_component.current_health, 1.0), "失血不应致死。")
	await _free_node(main_node)


## 满血只有基础吸血；半血以下加成，并通过武器结算进入弹体上下文。
func _test_half_health_lifesteal() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(120.0, 0.0))
	_enable_berserk(player)
	var drain: BerserkDrainComponent = player.get_berserk_drain()
	drain.set_process(false)

	_expect(is_equal_approx(player.get_bonus_lifesteal_ratio(), 0.15), "满血额外吸血应为 0.15。")
	player.health_component.apply_damage(DamageEvent.new(60.0, null, Vector2.ZERO))
	_expect(is_equal_approx(player.get_bonus_lifesteal_ratio(), 0.4), "半血以下应为 0.15+0.25=0.4。")

	var lifesteal_up: UpgradeDefinition = load(LIFESTEAL_UP_PATH) as UpgradeDefinition
	for _index: int in range(lifesteal_up.max_stacks):
		player.apply_upgrade(lifesteal_up)
	_expect(
		is_equal_approx(player.get_bonus_lifesteal_ratio(), 0.15 + 0.25 + 0.3),
		"三级嗜血后应为 0.7。"
	)

	var controller: WeaponController = _find_controller(player, &"starter_weapon")
	controller.request_fire(enemy)
	var projectile: ProjectileBase = _first_projectile(session)
	_expect(
		projectile != null and is_equal_approx(projectile.context.lifesteal_ratio, 0.7),
		"武器弹体应继承狂战额外吸血。"
	)
	await _free_node(main_node)


## 一次免死只生效一次；DoT 致命也由统一管线拦截。
func _test_death_immunity_once() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	player.free_on_death = false
	_enable_berserk(player)
	player.get_berserk_drain().set_process(false)
	_expect(player.apply_upgrade(load(IMMUNITY_PATH) as UpgradeDefinition), "应能获得一次免死。")
	_expect(player.has_death_immunity(), "免死标记应可用。")

	var first: DamageResult = player.apply_damage(DamageEvent.new(999.0, null, Vector2.ZERO))
	_expect(first.death_immunity_triggered, "首次致命伤害应触发免死。")
	_expect(is_equal_approx(player.health_component.current_health, 1.0), "免死后应剩 1 点生命。")
	_expect(not player.has_death_immunity(), "免死标记应被消耗。")

	var dot_event := DamageEvent.new(999.0, null, Vector2.ZERO)
	dot_event.tags = [&"dot"]
	player.apply_damage(dot_event)
	_expect(player.health_component.current_health <= 0.0, "第二次致命伤害（DoT）应死亡。")
	await _free_node(main_node)


## 狂战与反伤刺甲、骑士盔甲互斥。
func _test_exclusive_branches() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_enable_berserk(player)
	_expect(
		not session.upgrade_system.can_offer(load(THORN_PATH) as UpgradeDefinition),
		"已选狂战不应再出现反伤刺甲。"
	)
	_expect(
		not session.upgrade_system.can_offer(load(KNIGHT_PATH) as UpgradeDefinition),
		"已选狂战不应再出现骑士盔甲。"
	)
	await _free_node(main_node)


## 忍痛升级把每秒失血降到 0。
func _test_drain_reduction() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_enable_berserk(player)
	var drain: BerserkDrainComponent = player.get_berserk_drain()
	drain.set_process(false)
	var upgrade: UpgradeDefinition = load(DRAIN_UP_PATH) as UpgradeDefinition
	for _index: int in range(upgrade.max_stacks):
		player.apply_upgrade(upgrade)
	_expect(is_equal_approx(drain.get_effective_drain(), 0.0), "三级忍痛后每秒失血应为 0。")
	var before: float = player.health_component.current_health
	drain.advance_time(2.0)
	_expect(is_equal_approx(player.health_component.current_health, before), "失血为 0 时不应扣血。")
	await _free_node(main_node)


## 重新初始化应清空失血、吸血加成与免死标记。
func _test_reinitialize_resets() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_enable_berserk(player)
	player.apply_upgrade(load(IMMUNITY_PATH) as UpgradeDefinition)
	player.initialize(player.definition)
	_expect(player.get_berserk_drain() == null, "重新初始化应移除失血组件。")
	_expect(is_equal_approx(player.get_bonus_lifesteal_ratio(), 0.0), "重新初始化应清空狂战吸血。")
	_expect(not player.has_death_immunity(), "重新初始化应清空免死标记。")
	await _free_node(main_node)


func _enable_berserk(player: PlayerActor) -> void:
	_expect(player.try_acquire_armor(load(ARMOR_PATH) as ArmorDefinition), "应能装备基础盔甲。")
	var base_up: UpgradeDefinition = load(ARMOR_BASE_UP_PATH) as UpgradeDefinition
	for _index: int in range(4):
		_expect(player.apply_upgrade(base_up), "基础盔甲强化应成功。")
	_expect(player.apply_upgrade(load(BERSERK_PATH) as UpgradeDefinition), "应能选择狂战盔甲。")


func _first_projectile(session: GameSession) -> ProjectileBase:
	for child: Node in session.projectiles.get_children():
		if child is ProjectileBase:
			return child as ProjectileBase
	return null


func _find_controller(player: PlayerActor, weapon_id: StringName) -> WeaponController:
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller) and controller.definition.id == weapon_id:
			return controller
	return null


func _prepare(session: GameSession) -> PlayerActor:
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller):
			controller.set_process(false)
	_clear_container(session.enemies)
	_clear_container(session.projectiles)
	return player


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _spawn_main() -> Node:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	await process_frame
	return main_node


func _spawn_dummy(session: GameSession, position: Vector2) -> EnemyActor:
	var definition := EnemyDefinition.new()
	definition.id = &"test_dummy"
	definition.display_name = "Dummy"
	definition.scene = load(ENEMY_SCENE_PATH) as PackedScene
	definition.max_health = 500.0
	definition.contact_damage = 0.0
	var enemy: EnemyActor = session.enemy_spawner.spawn_enemy(definition, position, true)
	if enemy != null:
		enemy.set_physics_process(false)
		if enemy.status_effect_component != null:
			enemy.status_effect_component.set_process(false)
	return enemy


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
