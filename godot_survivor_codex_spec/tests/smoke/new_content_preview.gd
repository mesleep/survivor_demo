## 新内容预览：月蚀荒原、月影投手、石甲兽、铁剑斩击、激光与飞行特效。
##
## 仅图形模式使用，不参与 headless 回归。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const PROJECTILE_SCENE := "res://scenes/combat/projectiles/projectile_base.tscn"
const ENEMY_SCENE := "res://scenes/actors/enemies/enemy_basic.tscn"

var _session: GameSession
var _player: PlayerActor


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var main: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	_session = main.get_node("GameSession") as GameSession
	_session.enemy_spawner.stop()
	_player = _session.player
	_player.position = Vector2.ZERO
	_player.camera.zoom = Vector2.ONE
	_session.arena.configure(load("res://data/maps/eclipse_wasteland.tres") as ArenaDefinition)
	for controller: WeaponController in _player.weapon_controllers:
		controller.set_process(false)

	_spawn_enemy("res://data/enemies/enemy_shooter.tres", Vector2(-240.0, -40.0))
	_spawn_enemy("res://data/enemies/enemy_brute.tres", Vector2(240.0, 60.0))
	_spawn_enemy("res://data/enemies/enemy_basic.tres", Vector2(0.0, -180.0))

	# 铁剑 + 斩击弧光
	var sword: WeaponDefinition = load("res://data/weapons/sword.tres") as WeaponDefinition
	_player.add_weapon(sword)
	var sword_controller: WeaponController = null
	for controller: WeaponController in _player.weapon_controllers:
		controller.set_process(false)
		if controller.definition.id == &"sword":
			sword_controller = controller
	var target: EnemyActor = _spawn_enemy("res://data/enemies/enemy_basic.tres", Vector2(120.0, 0.0))
	if sword_controller != null and target != null:
		sword_controller.request_fire(target)

	# 激光与飞行特效（表现预览）
	_place_projectile("res://data/projectiles/tech_laser.tres", Vector2(-420.0, 160.0))
	_place_projectile("res://data/projectiles/tech_missile.tres", Vector2(-300.0, 160.0))

	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://art_review/v2_new_content_preview.png")
	if result != OK:
		push_error("Could not save new content preview: %s" % result)
	quit(0 if result == OK else 1)


func _spawn_enemy(path: String, position: Vector2) -> EnemyActor:
	var definition: EnemyDefinition = load(path) as EnemyDefinition
	var enemy: EnemyActor = _session.enemy_spawner.spawn_enemy(definition, position, true)
	if enemy != null:
		enemy.set_physics_process(false)
	return enemy


func _place_projectile(path: String, position: Vector2) -> void:
	var definition: ProjectileDefinition = load(path) as ProjectileDefinition
	var projectile: ProjectileBase = (load(PROJECTILE_SCENE) as PackedScene).instantiate()
	_session.projectiles.add_child(projectile)
	var context := ProjectileSpawnContext.new(_player, &"player", position, Vector2.RIGHT)
	projectile.initialize(definition, context)
	projectile.launch(Vector2.RIGHT)
	projectile.set_physics_process(false)
	projectile.monitoring = false
