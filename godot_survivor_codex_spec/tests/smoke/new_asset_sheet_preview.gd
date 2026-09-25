## 新素材总览网格：逐个放大展示 SpriteFrames 与图标，供人工核对。
##
## 仅图形模式使用，不参与 headless 回归。
extends SceneTree

const FRAMES := [
	"bow", "staff_weapon", "tech_launcher", "arrow", "arrow_explosion", "arrow_flame",
	"arrow_ice", "arrow_power", "staff_orb", "staff_orb_explosion", "staff_flame_bolt",
	"staff_ice_spear", "staff_ice_split", "tech_missile", "coin", "explosion",
	"fire_patch", "ice_freeze", "thorn_aura",
]
const ICONS := [
	"icon_staff_explosion", "icon_staff_flame", "icon_staff_power", "icon_staff_ice",
	"icon_armor_basic", "icon_armor_thorns", "icon_armor_knight", "icon_armor_berserk",
	"icon_armor_tech", "icon_helmet_basic", "icon_helmet_tech", "icon_gloves_basic",
	"icon_gloves_tech", "icon_enchant_explosion", "icon_enchant_flame", "icon_enchant_ice",
	"icon_enchant_power", "icon_coin", "icon_upgrade_base", "icon_upgrade_ascension",
	"icon_upgrade_branch", "icon_attr_move_speed", "icon_attr_pickup_range",
	"icon_attr_lifesteal", "icon_attr_critical", "icon_attr_defense", "icon_attr_range",
	"icon_attr_damage", "icon_attr_regeneration",
]


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var background := ColorRect.new()
	background.color = Color(0.07, 0.08, 0.12)
	background.size = Vector2(1280, 720)
	layer.add_child(background)

	var entries: Array = FRAMES.duplicate()
	entries.append_array(ICONS)
	var columns: int = 8
	var cell := Vector2(160, 120)
	for index: int in range(entries.size()):
		var column: int = index % columns
		var row: int = index / columns
		var center := Vector2(column * cell.x + cell.x * 0.5, row * cell.y + cell.y * 0.5 - 14)
		_add_entry(layer, String(entries[index]), center)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://art_review/v2_asset_sheet_preview.png")
	if result != OK:
		push_error("Could not save asset sheet preview: %s" % result)
	quit(0 if result == OK else 1)


func _add_entry(layer: CanvasLayer, entry_name: String, center: Vector2) -> void:
	if entry_name.begins_with("icon_"):
		var texture: Texture2D = load("res://assets/v2_dark_comic/ui/%s.png" % entry_name) as Texture2D
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.position = center
		sprite.scale = Vector2.ONE * (72.0 / maxf(float(texture.get_width()), 1.0))
		layer.add_child(sprite)
	else:
		var frames: SpriteFrames = load("res://data/visuals/v2_dark_comic/%s_frames.tres" % entry_name) as SpriteFrames
		var animated := AnimatedSprite2D.new()
		animated.sprite_frames = frames
		animated.position = center
		var first: Texture2D = frames.get_frame_texture(&"default", 0)
		animated.scale = Vector2.ONE * (72.0 / maxf(float(first.get_width()), 1.0))
		layer.add_child(animated)
		if frames.has_animation(&"default"):
			animated.play(&"default")
	var label := Label.new()
	label.text = entry_name
	label.position = center + Vector2(-74, 42)
	label.add_theme_font_size_override("font_size", 13)
	layer.add_child(label)
