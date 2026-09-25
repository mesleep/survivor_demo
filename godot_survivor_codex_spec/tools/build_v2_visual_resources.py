"""为独立的暗色漫画素材生成 Godot SpriteFrames。

单帧图可填充现有动画槽；四张编号动作图齐备时自动替换对应动画，
场景引用保持不变。
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "data" / "visuals" / "v2_dark_comic"
ASSETS = {
    "player": ("actors/B01_月光小法师_单帧.png", ("idle", 1, 1.0, True), ("walk", 4, 8.0, True)),
    "huniu": ("actors/B03_虎妞_单帧.png", ("idle", 1, 1.0, True), ("walk", 4, 8.0, True)),
    "heibao": ("actors/B04_黑豹_单帧.png", ("idle", 1, 1.0, True), ("walk", 4, 8.0, True)),
    "xiaosi": ("actors/B05_小四_单帧.png", ("idle", 1, 1.0, True), ("walk", 4, 8.0, True), ("fire", 4, 12.0, False), ("default", 4, 8.0, True)),
    "xiaoqi": ("actors/B06_小七_单帧.png", ("idle", 1, 1.0, True), ("walk", 4, 8.0, True), ("fire", 4, 12.0, False), ("default", 4, 8.0, True)),
    "boss": ("enemies/B09_月夜领主_单帧.png", ("idle", 1, 1.0, True), ("walk", 4, 6.0, True)),
    "wand": ("weapons/starlight_wand.png", ("fire", 4, 14.0, False), ("idle", 1, 1.0, True)),
    "bolt": ("projectiles/starlight_bolt.png", ("default", 4, 12.0, True)),
    "leaf": ("projectiles/leaf_blade.png", ("idle", 1, 1.0, True), ("walk", 4, 8.0, True), ("fire", 4, 12.0, False), ("default", 4, 12.0, True)),
    "bone": ("projectiles/bone_returner.png", ("idle", 1, 1.0, True), ("walk", 4, 8.0, True), ("fire", 4, 12.0, False), ("default", 4, 12.0, True)),
    "bell": ("projectiles/orbit_bell.png", ("idle", 1, 1.0, True), ("walk", 4, 8.0, True), ("fire", 4, 12.0, False), ("default", 4, 12.0, True)),
    "gem": ("pickups/experience_gem.png", ("default", 4, 8.0, True)),
    "impact": ("fx/hit_spark.png", ("default", 4, 16.0, False)),
    "enemy_shooter": ("enemies/enemy_shooter_单帧.png", ("idle", 1, 1.0, True), ("walk", 4, 8.0, True)),
    "enemy_brute": ("enemies/enemy_brute_单帧.png", ("idle", 1, 1.0, True), ("walk", 4, 8.0, True)),
    "ranger": ("actors/B02_远程射手_单帧.png", ("idle", 1, 1.0, True), ("walk", 4, 8.0, True)),
}
MOTION_STEMS = {
    "player": "actors/B01_月光小法师_walk",
    "huniu": "actors/B03_虎妞_walk",
    "heibao": "actors/B04_黑豹_walk",
    "xiaosi": "actors/B05_小四_walk",
    "xiaoqi": "actors/B06_小七_walk",
    "boss": "enemies/B09_月夜领主_walk",
    "wand": "weapons/starlight_wand_fire",
    "bolt": "projectiles/starlight_bolt_pulse",
    "enemy_shooter": "enemies/enemy_shooter_walk",
    "enemy_brute": "enemies/enemy_brute_walk",
    "ranger": "actors/B02_远程射手_walk",
}
MOTION_ANIMATIONS = {"player": "walk", "huniu": "walk", "heibao": "walk", "xiaosi": "walk", "xiaoqi": "walk", "boss": "walk", "wand": "fire", "bolt": "default", "enemy_shooter": "walk", "enemy_brute": "walk", "ranger": "walk"}


def build(name: str, definition: tuple) -> None:
    image_path, *animations = definition
    source = ROOT / "assets" / "v2_dark_comic" / image_path
    if not source.is_file():
        raise FileNotFoundError(source)
    paths = [image_path]
    motion_paths = []
    if name in MOTION_STEMS:
        motion_paths = [f"{MOTION_STEMS[name]}_{index:02d}.png" for index in range(1, 5)]
        if all((ROOT / "assets" / "v2_dark_comic" / path).is_file() for path in motion_paths):
            paths.extend(motion_paths)
        else:
            motion_paths = []
    resource_ids = {path: str(index + 1) for index, path in enumerate(paths)}
    entries = []
    for animation_name, frame_count, speed, loop in animations:
        use_motion = motion_paths and animation_name == MOTION_ANIMATIONS[name] and frame_count == 4
        frame_paths = motion_paths if use_motion else [image_path] * frame_count
        frames = ", ".join(
            '{"duration": 1.0, "texture": ExtResource("%s")}' % resource_ids[path]
            for path in frame_paths
        )
        entries.append(
            '{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.1f}'
            % (frames, str(loop).lower(), animation_name, speed)
        )
    content = (
        f'[gd_resource type="SpriteFrames" load_steps={len(paths) + 1} format=3]\n\n'
        + "\n".join(
            f'[ext_resource type="Texture2D" path="res://assets/v2_dark_comic/{path}" id="{resource_ids[path]}"]'
            for path in paths
        ) + '\n\n'
        '[resource]\nanimations = [\n' + ',\n'.join(entries) + '\n]\n'
    )
    (OUTPUT / f"{name}_frames.tres").write_text(content, encoding="utf-8")


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for asset_name, asset_definition in ASSETS.items():
        build(asset_name, asset_definition)
    print(f"Built {len(ASSETS)} SpriteFrames resources in {OUTPUT}")
