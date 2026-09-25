## 优化项实拍：装备栏图标/质变名、设置面板。
##
## 仅图形模式使用，不参与 headless 回归。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const STAFF_PATH := "res://data/weapons/staff.tres"
const EXPLOSION_PATH := "res://data/upgrades/staff_explosion.tres"
const ARMOR_PATH := "res://data/armor/armor_basic.tres"

var _session: GameSession


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var main: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	_session = main.get_node("GameSession") as GameSession
	_session.enemy_spawner.stop()
	var player: PlayerActor = _session.player
	player.position = Vector2.ZERO
	player.camera.zoom = Vector2.ONE
	for controller: WeaponController in player.weapon_controllers:
		controller.set_process(false)

	player.add_weapon(load(STAFF_PATH) as WeaponDefinition)
	for _index: int in range(4):
		player.add_equipment_base_level(&"staff")
	player.apply_upgrade(load(EXPLOSION_PATH) as UpgradeDefinition)
	player.try_acquire_armor(load(ARMOR_PATH) as ArmorDefinition)

	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_review/v2_equipment_bar_preview.png")

	# 打开设置面板再截一张。
	_session.session_controls.toggle_pause()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_review/v2_settings_preview.png")
	quit(0)
