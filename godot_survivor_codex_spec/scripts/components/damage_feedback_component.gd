## 为 Actor 提供可复用的受伤视觉和声音反馈。
##
## 输入：HealthComponent.damaged 与独立 Visual 节点。
## 输出：短促闪色、缩放抖动和可配置的运行时合成音效；不修改碰撞体或共享资源。
class_name DamageFeedbackComponent
extends Node

signal feedback_started(event: DamageEvent)

@export var play_sound: bool = true

const FEEDBACK_DURATION_SECONDS := 0.14
const HIT_SOUND_DURATION_SECONDS := 0.09
const HIT_SOUND_MIX_RATE := 22050
const FLASH_COLOR := Color(1.0, 0.28, 0.28, 1.0)

static var _cached_hit_stream: AudioStreamWAV
static var _live_component_count: int = 0

var _visual: Node2D
var _health_component: HealthComponent
var _base_position: Vector2
var _base_scale: Vector2
var _base_modulate: Color
var _feedback_tween: Tween

@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D


func _enter_tree() -> void:
	_live_component_count += 1


func _exit_tree() -> void:
	_disconnect_health()
	if is_instance_valid(_feedback_tween):
		_feedback_tween.kill()
	if is_instance_valid(audio_player):
		audio_player.stop()
		audio_player.stream = null
	_live_component_count = maxi(_live_component_count - 1, 0)
	if _live_component_count == 0:
		_cached_hit_stream = null


func initialize(health_component: HealthComponent, visual: Node2D) -> void:
	_disconnect_health()
	_health_component = health_component
	_visual = visual
	if not is_instance_valid(_health_component) or not is_instance_valid(_visual):
		push_error("DamageFeedbackComponent 初始化失败：缺少生命组件或 Visual 节点。")
		return
	_base_position = _visual.position
	_base_scale = _visual.scale
	_base_modulate = _visual.modulate
	_health_component.damaged.connect(_on_damaged)
	if play_sound:
		if _cached_hit_stream == null:
			_cached_hit_stream = _create_hit_stream()
		audio_player.stream = _cached_hit_stream
	else:
		audio_player.stop()
		audio_player.stream = null


## 立即播放一次反馈；重复受伤会重启效果并先恢复基础变换。
func play_feedback(event: DamageEvent) -> void:
	if not is_instance_valid(_visual):
		return
	_reset_visual()
	_visual.modulate = FLASH_COLOR
	_visual.scale = _base_scale * 1.14
	_visual.position = _base_position + Vector2(3.0, -2.0)
	_feedback_tween = create_tween()
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(_visual, "modulate", _base_modulate, FEEDBACK_DURATION_SECONDS)
	_feedback_tween.tween_property(_visual, "scale", _base_scale, FEEDBACK_DURATION_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(_visual, "position", _base_position, FEEDBACK_DURATION_SECONDS).set_trans(Tween.TRANS_SINE)
	if play_sound and audio_player.stream != null:
		audio_player.play()
	feedback_started.emit(event)


func _on_damaged(event: DamageEvent) -> void:
	play_feedback(event)


func _reset_visual() -> void:
	if is_instance_valid(_feedback_tween):
		_feedback_tween.kill()
	if not is_instance_valid(_visual):
		return
	_visual.position = _base_position
	_visual.scale = _base_scale
	_visual.modulate = _base_modulate


func _disconnect_health() -> void:
	if is_instance_valid(_health_component) and _health_component.damaged.is_connected(_on_damaged):
		_health_component.damaged.disconnect(_on_damaged)


## 生成带快速衰减的低频碰撞音，所有实例共享同一只读音频流。
func _create_hit_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = HIT_SOUND_MIX_RATE
	stream.stereo = false
	var sample_count: int = roundi(HIT_SOUND_DURATION_SECONDS * HIT_SOUND_MIX_RATE)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for index: int in range(sample_count):
		var progress: float = float(index) / float(sample_count)
		var envelope: float = (1.0 - progress) * (1.0 - progress)
		var frequency: float = lerpf(180.0, 80.0, progress)
		var sample: float = sin(TAU * frequency * float(index) / float(HIT_SOUND_MIX_RATE)) * envelope * 0.38
		samples.encode_s16(index * 2, clampi(roundi(sample * 32767.0), -32768, 32767))
	stream.data = samples
	return stream
