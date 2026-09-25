## 新战斗素材整体预览：武器、弹体、爆炸、火坑、金币、冻结与刺圈。
##
## 仅用于图形模式截图人工验收，不参与 headless 回归。
extends SceneTree

const PROJECTILE_SCENE := "res://scenes/combat/projectiles/projectile_base.tscn"
const ENEMY_SCENE := "res://scenes/actors/enemies/enemy_basic.tscn"
const COIN_SCENE := "res://scenes/pickups/coin_pickup.tscn"

var _player: PlayerActor
var _session: GameSession


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var main: Node = (load("res://scenes/bootstrap/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	_session = main.get_node("GameSession") as GameSession
	_session.enemy_spawner.stop()
	_player = _session.player
	_player.position = Vector2.ZERO
	_player.camera.zoom = Vector2.ONE
	for controller: WeaponController in _player.weapon_controllers:
		controller.set_process(false)
		controller.queue_free()
	_player.weapon_controllers.clear()

	_player.add_weapon(load("res://data/weapons/bow.tres") as WeaponDefinition)
	_player.add_weapon(load("res://data/weapons/staff.tres") as WeaponDefinition)
	_player.add_weapon(load("res://data/weapons/tech_launcher.tres") as WeaponDefinition)
	for controller: WeaponController in _player.weapon_controllers:
		controller.set_process(false)

	_place_projectile("arrow_projectile", Vector2(-420, -230))
	_place_projectile("arrow_explosion", Vector2(-300, -230))
	_place_projectile("arrow_flame", Vector2(-180, -230))
	_place_projectile("arrow_ice", Vector2(-60, -230))
	_place_projectile("arrow_power", Vector2(60, -230))
	_place_projectile("staff_orb", Vector2(-420, -120))
	_place_projectile("staff_orb_explosion", Vector2(-300, -120))
	_place_projectile("staff_flame_bolt", Vector2(-180, -120))
	_place_projectile("staff_ice_spear", Vector2(-60, -120))
	_place_projectile("staff_ice_split", Vector2(60, -120))
	_place_projectile("tech_missile", Vector2(180, -120))

	var explosion := ExplosionEffect.new()
	_session.projectiles.add_child(explosion)
	explosion.global_position = Vector2(-300, 150)
	var profile: ExplosionDefinition = load("res://data/combat/staff_orb_explosion_profile.tres") as ExplosionDefinition
	explosion.setup(profile.radius, 10.0, profile.visual_color, profile.visual_frames, profile.visual_scale)

	var fire_patch := GroundDamageArea.new()
	_session.projectiles.add_child(fire_patch)
	fire_patch.global_position = Vector2(-60, 150)
	var patch_definition: GroundDamageAreaDefinition = load("res://data/combat/fire_patch.tres") as GroundDamageAreaDefinition
	fire_patch.setup(patch_definition, _player, &"player", 1.0, 1.0)
	fire_patch.set_process(false)

	var coin: CoinPickup = (load(COIN_SCENE) as PackedScene).instantiate()
	_session.pickups.add_child(coin)
	coin.global_position = Vector2(140, 150)
	coin.initialize(1)

	var frozen: EnemyActor = _spawn_enemy(Vector2(340, 150))
	frozen.apply_freeze(load("res://data/combat/ice_freeze.tres") as FreezeEffect)

	_spawn_enemy(Vector2(420, 0))

	var thorn := ThornAuraComponent.new()
	_player.add_child(thorn)
	thorn.initialize(_player, load("res://data/armor/armor_thorns.tres") as ThornArmorDefinition)

	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://art_review/v2_new_combat_art_preview.png")
	if result != OK:
		push_error("Could not save new combat art preview: %s" % result)
	quit(0 if result == OK else 1)


func _place_projectile(definition_name: String, position: Vector2) -> void:
	var definition: ProjectileDefinition = load("res://data/projectiles/%s.tres" % definition_name) as ProjectileDefinition
	var projectile: ProjectileBase = (load(PROJECTILE_SCENE) as PackedScene).instantiate()
	_session.projectiles.add_child(projectile)
	var context := ProjectileSpawnContext.new(_player, &"player", position, Vector2.RIGHT)
	projectile.initialize(definition, context)
	projectile.launch(Vector2.RIGHT)
	projectile.set_physics_process(false)
	projectile.monitoring = false


func _spawn_enemy(position: Vector2) -> EnemyActor:
	var definition := EnemyDefinition.new()
	definition.id = &"preview_dummy"
	definition.display_name = "Preview"
	definition.scene = load(ENEMY_SCENE) as PackedScene
	definition.max_health = 500.0
	definition.contact_damage = 0.0
	var enemy: EnemyActor = _session.enemy_spawner.spawn_enemy(definition, position, true)
	if enemy != null:
		enemy.set_physics_process(false)
		if enemy.status_effect_component != null:
			enemy.status_effect_component.set_process(false)
	return enemy
