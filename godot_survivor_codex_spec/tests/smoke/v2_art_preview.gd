## 固定角色与敌人位置，截取新版美术的局内和界面画面。
extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var main: Node = (load("res://scenes/bootstrap/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var session: GameSession = main.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	player.position = Vector2.ZERO
	player.camera.zoom = Vector2.ONE
	var placements := [
		["enemy_basic", Vector2(185, -110)],
		["enemy_fast", Vector2(325, -110)],
		["xiaosi", Vector2(185, 110)],
		["xiaoqi", Vector2(325, 110)],
		["boss_default", Vector2(475, 0)],
	]
	var boss_actor: EnemyActor
	for placement: Array in placements:
		var definition: EnemyDefinition = load("res://data/enemies/%s.tres" % placement[0]) as EnemyDefinition
		var actor: EnemyActor = session.enemy_spawner.spawn_enemy(definition, placement[1], true)
		actor.set_physics_process(false)
		if placement[0] == "boss_default":
			boss_actor = actor
	session.spawn_experience_gem(1, Vector2(-135, 85))
	var output_name := "v2_ingame_preview.png"
	if "--end" in OS.get_cmdline_user_args():
		session.end_panel.show_result(GameResult.new(GameResult.Outcome.VICTORY, 300.0, 8, 120))
		output_name = "v2_end_panel_preview.png"
	elif "--upgrade" in OS.get_cmdline_user_args():
		var choices: Array[UpgradeDefinition] = []
		for name: String in ["acquire_leaf", "acquire_bone", "acquire_bell"]:
			choices.append(load("res://data/upgrades/%s.tres" % name) as UpgradeDefinition)
		session.level_up_panel.show_choices(choices)
		output_name = "v2_upgrade_panel_preview.png"
	await create_timer(0.35).timeout
	if "--hit" in OS.get_cmdline_user_args():
		boss_actor.get_node("DamageFeedbackComponent").call("_spawn_hit_spark")
		output_name = "v2_hit_preview.png"
		await create_timer(0.05).timeout
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://art_review/" + output_name)
	if result != OK:
		push_error("Could not save v2 art preview: %s" % result)
	quit(0 if result == OK else 1)
