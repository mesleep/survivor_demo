"""为新增战斗素材生成 Godot SpriteFrames（T16-T26 接入用）。

静态对象使用单张 PNG 填充 default/idle/fire；四帧对象使用 <stem>_01..04.png。
输出到 data/visuals/v2_dark_comic/<name>_frames.tres，场景与 Resource 引用保持不变。
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "data" / "visuals" / "v2_dark_comic"

# name -> (asset relative path, [ (animation, frame_count, speed, loop), ... ])
STATIC_ASSETS = {
    "bow": ("weapons/bow.png", (("idle", 1, 1.0, True), ("fire", 1, 14.0, False))),
    "staff_weapon": ("weapons/staff.png", (("idle", 1, 1.0, True), ("fire", 1, 14.0, False))),
    "tech_launcher": ("weapons/tech_launcher.png", (("idle", 1, 1.0, True), ("fire", 1, 14.0, False))),
    "arrow": ("projectiles/arrow.png", (("default", 1, 1.0, True),)),
    "arrow_explosion": ("projectiles/arrow_explosion.png", (("default", 1, 1.0, True),)),
    "arrow_flame": ("projectiles/arrow_flame.png", (("default", 1, 1.0, True),)),
    "arrow_ice": ("projectiles/arrow_ice.png", (("default", 1, 1.0, True),)),
    "arrow_power": ("projectiles/arrow_power.png", (("default", 1, 1.0, True),)),
    "staff_ice_spear": ("projectiles/staff_ice_spear.png", (("default", 1, 1.0, True),)),
    "staff_ice_split": ("projectiles/staff_ice_split.png", (("default", 1, 1.0, True),)),
    "enemy_bolt": ("projectiles/enemy_bolt.png", (("default", 1, 1.0, True),)),
    "sword": ("weapons/sword.png", (("idle", 1, 1.0, True), ("fire", 1, 14.0, False))),
}

# name -> (asset stem without index, frame_count, speed, loop)
ANIMATED_ASSETS = {
    "staff_orb": ("projectiles/staff_orb", 4, 12.0, True),
    "staff_orb_explosion": ("projectiles/staff_orb_explosion", 4, 14.0, True),
    "staff_flame_bolt": ("projectiles/staff_flame_bolt", 4, 14.0, True),
    "tech_missile": ("projectiles/tech_missile", 4, 14.0, True),
    "coin": ("pickups/coin", 4, 8.0, True),
    "explosion": ("fx/explosion", 4, 18.0, False),
    "fire_patch": ("fx/fire_patch", 4, 10.0, True),
    "ice_freeze": ("fx/ice_freeze", 4, 8.0, True),
    "thorn_aura": ("fx/thorn_aura", 4, 8.0, True),
    "slash_arc": ("fx/slash_arc", 4, 18.0, False),
    "jet_flight": ("fx/jet_flight", 4, 12.0, True),
    "missile_trail": ("fx/missile_trail", 4, 14.0, True),
}


def write_frames(name: str, paths: list, animations: list) -> None:
    resource_ids = {path: str(index + 1) for index, path in enumerate(paths)}
    entries = []
    for animation_name, frame_count, speed, loop in animations:
        frame_paths = [paths[0]] * frame_count if len(paths) == 1 else paths
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
    built = 0
    for asset_name, (asset_path, animations) in STATIC_ASSETS.items():
        if not (ROOT / "assets" / "v2_dark_comic" / asset_path).is_file():
            raise FileNotFoundError(asset_path)
        write_frames(asset_name, [asset_path], list(animations))
        built += 1
    for asset_name, (stem, frame_count, speed, loop) in ANIMATED_ASSETS.items():
        frame_paths = [f"{stem}_{index:02d}.png" for index in range(1, frame_count + 1)]
        for path in frame_paths:
            if not (ROOT / "assets" / "v2_dark_comic" / path).is_file():
                raise FileNotFoundError(path)
        write_frames(asset_name, frame_paths, [("default", frame_count, speed, loop)])
        built += 1
    print(f"Built {built} SpriteFrames resources in {OUTPUT}")
