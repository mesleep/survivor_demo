## P2-01 生命值与伤害烟雾检查。
##
## 验证 HealthComponent 边界、DamageEvent 传递、Hitbox/Hurtbox 组合、
## 玩家和敌人复用以及死亡信号只触发一次。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"

var _failed: bool = false
var _health_died_count: int = 0
var _health_damaged_count: int = 0
var _actor_died_count: int = 0
var _hit_landed_count: int = 0
var _last_hit_event: DamageEvent


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	_expect(main_scene != null, "无法加载主场景。")
	if main_scene == null:
		quit(1)
		return

	var main_node: Node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame

	var game_session: GameSession = main_node.get_node_or_null("GameSession") as GameSession
	_expect(game_session != null, "主场景缺少 GameSession。")
	if game_session == null:
		quit(1)
		return
	game_session.enemy_spawner.stop()

	var player: PlayerActor = game_session.player
	var enemy: EnemyActor = game_session.enemies.get_child(0) as EnemyActor
	_expect(is_instance_valid(player), "GameSession 未创建 PlayerActor。")
	_expect(is_instance_valid(enemy), "GameSession 未创建 EnemyActor。")
	if not is_instance_valid(player) or not is_instance_valid(enemy):
		quit(1)
		return

	_expect(player is ActorBase and enemy is ActorBase, "玩家和敌人未复用 ActorBase。")
	_expect(player.health_component is HealthComponent, "玩家缺少 HealthComponent。")
	_expect(enemy.health_component is HealthComponent, "敌人缺少 HealthComponent。")
	_expect(player.hurtbox_component is HurtboxComponent, "玩家缺少 HurtboxComponent。")
	_expect(enemy.hurtbox_component is HurtboxComponent, "敌人缺少 HurtboxComponent。")
	_expect(enemy.contact_hitbox is HitboxComponent, "敌人缺少 ContactHitbox。")
	_expect(is_equal_approx(player.health_component.maximum_health, player.definition.max_health), "玩家最大生命未从 Resource 初始化。")
	_expect(is_equal_approx(enemy.health_component.maximum_health, enemy.definition.max_health), "敌人最大生命未从 Resource 初始化。")

	var player_resource_health: float = player.definition.max_health
	var enemy_resource_health: float = enemy.definition.max_health
	enemy.contact_hitbox.hit_landed.connect(_on_hit_landed)
	player.global_position = Vector2.ZERO
	enemy.global_position = Vector2(80.0, 0.0)
	enemy.force_update_transform()
	for _frame: int in range(60):
		await physics_frame
	_expect(_hit_landed_count == 1, "ContactHitbox 在一次持续接触中重复造成伤害。")
	_expect(
		is_equal_approx(player.health_component.current_health, player_resource_health - enemy.definition.contact_damage),
		"ContactHitbox 物理重叠未造成一次接触伤害。"
	)
	player.health_component.reset()
	enemy.global_position = Vector2(400.0, 0.0)
	enemy.force_update_transform()
	await physics_frame

	var hit_applied: bool = enemy.contact_hitbox.apply_to(player.hurtbox_component)
	_expect(hit_applied, "ContactHitbox 未向玩家 Hurtbox 应用伤害。")
	_expect(
		is_equal_approx(player.health_component.current_health, player_resource_health - enemy.definition.contact_damage),
		"玩家未扣除 EnemyDefinition.contact_damage。"
	)
	_expect(_last_hit_event != null and _last_hit_event.source == enemy, "DamageEvent 未保留正确伤害来源。")
	_expect(_last_hit_event != null and _last_hit_event.tags.has(&"contact"), "DamageEvent 缺少接触伤害标签。")

	var isolated_health := HealthComponent.new()
	root.add_child(isolated_health)
	isolated_health.died.connect(_on_isolated_health_died)
	isolated_health.damaged.connect(_on_isolated_health_damaged)
	isolated_health.initialize(10.0)
	isolated_health.apply_damage(DamageEvent.new(6.0, enemy, enemy.global_position))
	_expect(is_equal_approx(isolated_health.current_health, 4.0), "HealthComponent 扣血结果不正确。")
	isolated_health.heal(100.0)
	_expect(is_equal_approx(isolated_health.current_health, 10.0), "HealthComponent 治疗超过最大生命。")
	isolated_health.apply_damage(DamageEvent.new(10.0, enemy, enemy.global_position))
	isolated_health.apply_damage(DamageEvent.new(10.0, enemy, enemy.global_position))
	isolated_health.heal(5.0)
	_expect(isolated_health.is_dead(), "HealthComponent 生命归零后未记录死亡。")
	_expect(is_equal_approx(isolated_health.current_health, 0.0), "HealthComponent 生命值低于零或死亡后被治疗。")
	_expect(_health_died_count == 1, "HealthComponent.died 触发次数不是一次。")
	_expect(_health_damaged_count == 2, "死亡后仍接受了普通伤害。")
	isolated_health.reset()
	_expect(not isolated_health.is_dead() and is_equal_approx(isolated_health.current_health, 10.0), "HealthComponent.reset() 未重置死亡状态。")

	enemy.free_on_death = false
	enemy.actor_died.connect(_on_actor_died)
	var lethal_event := DamageEvent.new(enemy.health_component.maximum_health, player, player.global_position)
	enemy.apply_damage(lethal_event)
	enemy.apply_damage(lethal_event)
	_expect(enemy.health_component.is_dead(), "EnemyActor 未通过 HealthComponent 死亡。")
	_expect(_actor_died_count == 1, "ActorBase.actor_died 触发次数不是一次。")

	_expect(is_equal_approx(player.definition.max_health, player_resource_health), "玩家运行时生命回写了共享 Resource。")
	_expect(is_equal_approx(enemy.definition.max_health, enemy_resource_health), "敌人运行时生命回写了共享 Resource。")

	if not _failed:
		print("Health and damage smoke test passed: components, bounds, events, and single death are valid.")
	quit(1 if _failed else 0)


func _on_isolated_health_died(_event: DamageEvent) -> void:
	_health_died_count += 1


func _on_isolated_health_damaged(_event: DamageEvent) -> void:
	_health_damaged_count += 1


func _on_actor_died(_actor: ActorBase, _event: DamageEvent) -> void:
	_actor_died_count += 1


func _on_hit_landed(_hurtbox: HurtboxComponent, event: DamageEvent) -> void:
	_hit_landed_count += 1
	_last_hit_event = event


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
