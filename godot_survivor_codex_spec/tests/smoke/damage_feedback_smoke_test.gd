## 通用受伤视觉与合成音效反馈烟雾检查。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"

var _failed: bool = false
var _feedback_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var feedback: DamageFeedbackComponent = player.damage_feedback_component
	_expect(feedback != null and feedback.audio_player.stream is AudioStreamWAV, "玩家未组合受伤反馈或合成音效流。")
	feedback.feedback_started.connect(_on_feedback_started)
	var base_modulate: Color = player.visual.modulate
	var base_scale: Vector2 = player.visual.scale
	player.apply_damage(DamageEvent.new(5.0, null, player.global_position))
	_expect(_feedback_count == 1, "有效伤害未触发一次反馈信号。")
	_expect(player.visual.modulate != base_modulate and player.visual.scale != base_scale, "受伤时视觉没有立即闪色和缩放。")
	_expect(feedback.audio_player.playing, "受伤时合成音效没有播放。")
	await create_timer(0.2).timeout
	_expect(player.visual.modulate.is_equal_approx(base_modulate), "受伤闪色没有恢复。")
	_expect(player.visual.scale.is_equal_approx(base_scale), "受伤缩放没有恢复。")

	var enemy: EnemyActor = session.enemy_spawner.spawn_enemy(session.enemy_spawn_settings.enemy_definition, Vector2(300.0, 0.0), true)
	_expect(enemy != null and enemy.damage_feedback_component != null, "敌人未复用受伤反馈组件。")
	if enemy != null:
		var enemy_base_modulate: Color = enemy.visual.modulate
		enemy.apply_damage(DamageEvent.new(5.0, player, enemy.global_position))
		_expect(enemy.visual.modulate != enemy_base_modulate, "敌人受伤时没有保留视觉反馈。")
		_expect(not enemy.damage_feedback_component.play_sound, "敌人的受伤声音开关没有关闭。")
		_expect(enemy.damage_feedback_component.audio_player.stream == null, "敌人仍持有受伤音效流。")
		_expect(not enemy.damage_feedback_component.audio_player.playing, "攻击敌人时错误播放了受伤音效。")

	if not _failed:
		print("Damage feedback smoke test passed: player audio and silent enemy visual feedback are valid.")
	quit(1 if _failed else 0)


func _on_feedback_started(_event: DamageEvent) -> void:
	_feedback_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
