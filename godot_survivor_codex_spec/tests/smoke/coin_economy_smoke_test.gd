## T26：金币掉落与一次性结算专项回归。
##
## 覆盖金币原子拾取、敌人死亡掉落、结算区分拾取与击退奖励、胜负/重复结算只发一次、
## 零击杀以及重开清空地面金币。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_coin_pickup_atomic()
	await _test_drop_on_kill_and_settlement()
	await _test_settlement_only_once_and_restart_reset()
	await _test_zero_kills()
	if not _failed:
		print("Coin economy smoke test passed: drop, atomic pickup, one-time settlement and reset are valid.")
	quit(1 if _failed else 0)


## 同一枚金币只结算一次，并触发一次金币变化信号。
func _test_coin_pickup_atomic() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var coin: CoinPickup = session.spawn_coin_pickup(3, Vector2(40.0, 0.0))
	await process_frame
	_expect(coin != null, "应能生成金币。")
	var signal_count: Array[int] = [0]
	player.coins_changed.connect(func(_value: int) -> void: signal_count[0] += 1)

	_expect(coin.collect(player), "首次拾取应成功。")
	_expect(not coin.collect(player), "重复拾取应失败。")
	_expect(player.get_run_coins() == 3, "金币余额应为 3。")
	_expect(signal_count[0] == 1, "金币变化信号应只发一次。")
	await _free_node(main_node)


## 敌人死亡按配置掉落金币；结算区分已拾取与击退奖励。
func _test_drop_on_kill_and_settlement() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	session.economy_rules = _make_rules(1.0, 2, 5)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(200.0, 0.0))
	await physics_frame

	enemy.health_component.apply_damage(DamageEvent.new(9999.0, null, Vector2.ZERO))
	_expect(session.kill_count == 1, "击杀数应为 1。")
	enemy.health_component.apply_damage(DamageEvent.new(9999.0, null, Vector2.ZERO))
	_expect(session.kill_count == 1, "同一敌人重复死亡不应重复计数。")

	await process_frame
	await process_frame
	var coin: CoinPickup = _first_coin(session)
	_expect(coin != null, "必定掉金时死亡应生成金币。")
	if coin != null:
		coin.collect(player)

	var results: Array[GameResult] = []
	session.run_ended.connect(func(result: GameResult) -> void: results.append(result))
	session.end_run(GameResult.Outcome.DEFEAT)
	_expect(results.size() == 1, "结算应只发一次。")
	var result: GameResult = results[0]
	_expect(result.coins_collected == 2, "已拾取金币应为 2。")
	_expect(result.coins_from_kills == 5, "击退奖励应为 1×5=5。")
	_expect(result.total_coins == 7, "总奖励应为 7。")
	session.end_run(GameResult.Outcome.VICTORY)
	_expect(results.size() == 1, "重复结算不应再次发奖。")
	await _free_node(main_node)


## 重开后新一局金币归零、地面金币清空。
func _test_settlement_only_once_and_restart_reset() -> void:
	var first_node: Node = await _spawn_main()
	var first_session: GameSession = first_node.get_node("GameSession") as GameSession
	var first_player: PlayerActor = _prepare(first_session)
	first_session.spawn_coin_pickup(5, Vector2(60.0, 0.0))
	first_player.add_coins(4)
	first_session.end_run(GameResult.Outcome.DEFEAT)
	_expect(first_player.get_run_coins() == 4, "结算前余额应为 4。")
	await _free_node(first_node)

	var second_node: Node = await _spawn_main()
	var second_session: GameSession = second_node.get_node("GameSession") as GameSession
	_expect(second_session.player.get_run_coins() == 0, "重开后金币应归零。")
	_expect(second_session.pickups.get_child_count() == 0, "重开后地面金币应清空。")
	await _free_node(second_node)


## 零击杀时结算奖励为 0。
func _test_zero_kills() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	_prepare(session)
	session.economy_rules = _make_rules(0.0, 1, 3)
	var results: Array[GameResult] = []
	session.run_ended.connect(func(result: GameResult) -> void: results.append(result))
	session.end_run(GameResult.Outcome.DEFEAT)
	_expect(results.size() == 1 and results[0].total_coins == 0, "零击杀结算金币应为 0。")
	await _free_node(main_node)


func _make_rules(drop_chance: float, per_drop: int, per_kill: int) -> EconomyRules:
	var rules := EconomyRules.new()
	rules.coin_drop_chance = drop_chance
	rules.coins_per_drop = per_drop
	rules.coins_per_kill = per_kill
	return rules


func _first_coin(session: GameSession) -> CoinPickup:
	for child: Node in session.pickups.get_children():
		if child is CoinPickup:
			return child as CoinPickup
	return null


func _prepare(session: GameSession) -> PlayerActor:
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller):
			controller.set_process(false)
	_clear_container(session.enemies)
	_clear_container(session.projectiles)
	_clear_container(session.pickups)
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
	definition.experience_value = 1
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
