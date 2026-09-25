## P3-02/P3-04 升级池、最大层数及全部运行时属性修正烟雾检查。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"

var _failed: bool = false
var _applied_signal_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	var main_node: Node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var system: UpgradeSystem = session.upgrade_system
	var controller: WeaponController = player.weapon_controllers[0]
	system.upgrade_applied.connect(_on_upgrade_applied)

	system.request_choices(3)
	var choices: Array[UpgradeDefinition] = system.get_current_choices()
	_expect(choices.size() == 3, "升级系统未返回三个选项。")
	var ids: Dictionary[StringName, bool] = {}
	for choice: UpgradeDefinition in choices:
		ids[choice.id] = true
	_expect(ids.size() == choices.size(), "同一次升级选择出现重复项。")
	_expect(system.apply_choice(choices[0]), "当前列表中的有效升级无法应用。")
	_expect(not system.apply_choice(choices[0]), "同一次选择被重复提交。")
	# 随机选择可能是任意属性；重新初始化玩家与武器，隔离后续精确数值断言。
	player.initialize(player.definition)
	player.configure_weapons(player.definition.starting_weapons, session.projectiles, session.targeting_service)
	system.initialize(player)

	var base_move_speed: float = player.definition.move_speed
	var base_max_health: float = player.definition.max_health
	controller = player.weapon_controllers[0]
	var base_cooldown: float = controller.definition.cooldown_seconds
	var base_projectile_count: int = controller.definition.projectile_count
	var upgrades := _index_upgrades(system.upgrade_pool)
	_apply_direct(player, upgrades[&"damage_up"])
	_apply_direct(player, upgrades[&"fire_rate_up"])
	_apply_direct(player, upgrades[&"projectile_count_up"])
	_apply_direct(player, upgrades[&"move_speed_up"])
	player.apply_damage(DamageEvent.new(40.0, null, Vector2.ZERO))
	_apply_direct(player, upgrades[&"max_health_up"])
	_apply_direct(player, upgrades[&"heal"])

	_expect(is_equal_approx(controller.get_runtime_damage_multiplier(), 1.2), "伤害升级未生效。")
	_expect(is_equal_approx(controller.get_effective_cooldown_seconds(), base_cooldown * 0.9), "攻速升级未生效。")
	_expect(controller.get_effective_projectile_count() == base_projectile_count + 1, "弹数升级未生效。")
	_expect(is_equal_approx(player.get_effective_move_speed(), base_move_speed * 1.1), "移速升级未生效。")
	_expect(is_equal_approx(player.health_component.maximum_health, base_max_health + 20.0), "最大生命升级未生效。")
	_expect(is_equal_approx(player.health_component.current_health, base_max_health + 10.0), "最大生命和治疗的当前生命结果不正确。")
	_expect(is_equal_approx(player.definition.move_speed, base_move_speed), "移速升级回写了 CharacterDefinition。")
	_expect(is_equal_approx(player.definition.max_health, base_max_health), "生命升级回写了 CharacterDefinition。")
	_expect(is_equal_approx(controller.definition.cooldown_seconds, base_cooldown), "攻速升级回写了 WeaponDefinition。")
	_expect(controller.definition.projectile_count == base_projectile_count, "弹数升级回写了 WeaponDefinition。")

	var capped := UpgradeDefinition.new()
	capped.id = &"capped_test"
	capped.display_name = "Capped"
	capped.type = UpgradeDefinition.UpgradeType.HEAL
	capped.value = 1.0
	capped.max_stacks = 1
	player.apply_upgrade(capped)
	system.upgrade_pool = [capped]
	# 本用例验证“满级不再提供”；关闭金币兜底以隔离该行为。
	system.fallback_upgrades = []
	system.request_choices(3)
	_expect(system.get_current_choices().is_empty(), "达到最大层数的升级仍被提供。")
	_expect(_applied_signal_count == 1, "UpgradeSystem 成功选择未恰好发送一次应用信号。")

	paused = false
	if not _failed:
		print("Upgrade system smoke test passed: choices, caps, effects, and resource isolation are valid.")
	quit(1 if _failed else 0)


func _index_upgrades(pool: Array[UpgradeDefinition]) -> Dictionary[StringName, UpgradeDefinition]:
	var indexed: Dictionary[StringName, UpgradeDefinition] = {}
	for definition: UpgradeDefinition in pool:
		indexed[definition.id] = definition
	return indexed


func _apply_direct(player: PlayerActor, definition: UpgradeDefinition) -> void:
	_expect(definition != null and player.apply_upgrade(definition), "无法应用升级 %s。" % definition.id)


func _on_upgrade_applied(_definition: UpgradeDefinition) -> void:
	_applied_signal_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
