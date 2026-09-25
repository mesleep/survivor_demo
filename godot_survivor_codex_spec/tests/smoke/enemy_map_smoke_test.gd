## T33：新敌人（远程/近战精英）与新地图专项回归。
##
## 覆盖远程敌人保持距离并发射敌我区分弹体、弹体命中玩家、
## 精英近战数值、难度池包含新敌人、地图定义可切换。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const SHOOTER_PATH := "res://data/enemies/enemy_shooter.tres"
const BRUTE_PATH := "res://data/enemies/enemy_brute.tres"
const BASIC_PATH := "res://data/enemies/enemy_basic.tres"
const RUN_PATH := "res://data/waves/default_run.tres"
const MAP_PATH := "res://data/maps/eclipse_wasteland.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_ranged_enemy_fires_and_hits()
	_test_brute_stats()
	_test_difficulty_pools()
	await _test_arena_configure()
	if not _failed:
		print("Enemy/map smoke test passed: ranged fire, brute stats, pools and arena are valid.")
	quit(1 if _failed else 0)


## 远程敌人停在攻击距离并发射命中层为玩家的弹体，弹体可命中玩家。
func _test_ranged_enemy_fires_and_hits() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var shooter_definition: EnemyDefinition = load(SHOOTER_PATH) as EnemyDefinition
	var shooter: EnemyActor = session.enemy_spawner.spawn_enemy(shooter_definition, Vector2(300.0, 0.0), true)
	_expect(shooter != null, "应能生成远程敌人。")

	await physics_frame
	await physics_frame
	var bolt: ProjectileBase = _first_projectile(session, &"enemy_bolt")
	_expect(bolt != null, "远程敌人应发射弹体。")
	if bolt != null:
		_expect(bolt.context.team_id == &"enemy", "敌人弹体阵营应为 enemy。")
		_expect(bolt.collision_mask == 2, "敌人弹体命中层应为玩家层 2。")

	await create_timer(1.6).timeout
	_expect(player.health_component.current_health < 100.0, "敌人弹体应能命中并伤害玩家。")
	await _free_node(main_node)


## 精英近战比基础敌人更肉更快，且为接触伤害。
func _test_brute_stats() -> void:
	var basic: EnemyDefinition = load(BASIC_PATH) as EnemyDefinition
	var brute: EnemyDefinition = load(BRUTE_PATH) as EnemyDefinition
	_expect(brute.max_health > basic.max_health, "精英血量应高于基础敌人。")
	_expect(brute.move_speed > basic.move_speed, "精英移速应高于基础敌人。")
	_expect(brute.contact_damage > 0.0, "精英应有接触伤害。")
	_expect(brute.attack_type == EnemyDefinition.AttackType.MELEE, "精英应为近战。")


## 难度阶段应逐步混入远程与精英。
func _test_difficulty_pools() -> void:
	var run: RunDefinition = load(RUN_PATH) as RunDefinition
	var shooter: EnemyDefinition = load(SHOOTER_PATH) as EnemyDefinition
	var brute: EnemyDefinition = load(BRUTE_PATH) as EnemyDefinition
	_expect(run.stages.size() >= 4, "应至少有四段难度。")
	_expect(run.stages[1].enemy_pool.has(shooter), "第二段应出现远程敌人。")
	_expect(run.stages[2].enemy_pool.has(brute), "第三段应出现精英近战。")
	_expect(run.stages[3].enemy_pool.has(shooter) and run.stages[3].enemy_pool.has(brute), "末段应混入两类新敌。")


## 地图定义可切换并影响范围与配色。
func _test_arena_configure() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var map: ArenaDefinition = load(MAP_PATH) as ArenaDefinition
	session.arena.configure(map)
	_expect(session.arena.get_definition() == map, "地图定义应已应用。")
	_expect(session.arena.get_bounds() == Rect2(-1280.0, -720.0, 2560.0, 1440.0), "地图范围应为 2560×1440。")
	_expect(map.background_texture == null, "新地图背景素材待交付，当前为配色占位。")
	await _free_node(main_node)


func _prepare(session: GameSession) -> PlayerActor:
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	for controller: WeaponController in player.weapon_controllers:
		controller.set_process(false)
	_clear_container(session.enemies)
	_clear_container(session.projectiles)
	return player


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _first_projectile(session: GameSession, definition_id: StringName) -> ProjectileBase:
	for child: Node in session.projectiles.get_children():
		if child is ProjectileBase and (child as ProjectileBase).definition.id == definition_id:
			return child as ProjectileBase
	return null


func _spawn_main() -> Node:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	await process_frame
	return main_node


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
