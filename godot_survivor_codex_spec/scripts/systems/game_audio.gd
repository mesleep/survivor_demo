## 单局声音组合：使用本地原创音频，限制同类短音频触发频率。
## 音量开关只控制本组件，不修改用户的全局主音量。
class_name GameAudio
extends Node

const SOUND_FILES: Dictionary = {
	&"shot": "星光发射", &"pickup": "宝石拾取", &"defeat_enemy": "轻巧击退",
	&"upgrade": "升级铃声", &"victory": "守护成功", &"defeat": "休息时刻",
	&"boss": "领主出现"
}
var muted: bool = false
var music: AudioStreamPlayer
var _players: Dictionary = {}
var _last_played: Dictionary = {}
var _audio_enabled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 无声测试环境仍加载资源，但不创建无法及时回收的虚拟音频播放流。
	_audio_enabled = DisplayServer.get_name() != "headless"
	music = AudioStreamPlayer.new()
	add_child(music)
	var stream: AudioStreamWAV = load("res://assets/audio/月光散步.wav").duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	music.stream = stream
	music.volume_db = -20.0
	if _audio_enabled:
		music.play()
	for key: StringName in SOUND_FILES:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://assets/audio/%s.wav" % SOUND_FILES[key]) as AudioStream
		player.volume_db = -15.0
		player.max_polyphony = 2
		add_child(player)
		_players[key] = player


func play_cue(cue: StringName) -> void:
	if muted or not _audio_enabled or not _players.has(cue):
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_played.get(cue, -1000)) < 90:
		return
	_last_played[cue] = now
	(_players[cue] as AudioStreamPlayer).play()


func set_muted(value: bool) -> void:
	muted = value
	music.volume_db = -80.0 if muted else -20.0
	if muted:
		for player: AudioStreamPlayer in _players.values():
			player.stop()


func finish_run(won: bool) -> void:
	music.stop()
	play_cue(&"victory" if won else &"defeat")


func _exit_tree() -> void:
	# 显式释放播放流，避免快速重开时旧局声音与新局叠加。
	music.stop()
	music.stream = null
	for player: AudioStreamPlayer in _players.values():
		player.stop()
		player.stream = null
	_players.clear()
