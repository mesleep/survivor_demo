"""把新增 SpriteFrames 与图标写入既有 .tres（一次性接入脚本，可重复运行）。

只做精确路径替换 / 追加 icon 引用，不改玩法数值；每个改动都断言命中次数。
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FRAMES_ROOT = "res://data/visuals/v2_dark_comic"
ICON_ROOT = "res://assets/v2_dark_comic/ui"

# 目标 .tres -> 新的 SpriteFrames 名称（替换原 SpriteFrames ext_resource 路径）
FRAMES_REMAP = {
    "data/weapons/bow.tres": "bow_frames",
    "data/weapons/staff.tres": "staff_weapon_frames",
    "data/weapons/tech_launcher.tres": "tech_launcher_frames",
    "data/projectiles/arrow_projectile.tres": "arrow_frames",
    "data/projectiles/arrow_explosion.tres": "arrow_explosion_frames",
    "data/projectiles/arrow_flame.tres": "arrow_flame_frames",
    "data/projectiles/arrow_ice.tres": "arrow_ice_frames",
    "data/projectiles/arrow_power.tres": "arrow_power_frames",
    "data/projectiles/staff_orb.tres": "staff_orb_frames",
    "data/projectiles/staff_orb_explosion.tres": "staff_orb_explosion_frames",
    "data/projectiles/staff_flame_bolt.tres": "staff_flame_bolt_frames",
    "data/projectiles/staff_ice_spear.tres": "staff_ice_spear_frames",
    "data/projectiles/staff_ice_split.tres": "staff_ice_split_frames",
    "data/projectiles/tech_missile.tres": "tech_missile_frames",
}

# 目标 .tres -> 图标 PNG 名称
ICON_ASSIGN = {
    "data/armor/armor_basic.tres": "icon_armor_basic.png",
    "data/armor/armor_helmet.tres": "icon_helmet_basic.png",
    "data/armor/armor_gloves.tres": "icon_gloves_basic.png",
    "data/upgrades/armor_thorns.tres": "icon_armor_thorns.png",
    "data/upgrades/armor_knight.tres": "icon_armor_knight.png",
    "data/upgrades/armor_berserk.tres": "icon_armor_berserk.png",
    "data/upgrades/armor_tech.tres": "icon_armor_tech.png",
    "data/upgrades/helmet_tech.tres": "icon_helmet_tech.png",
    "data/upgrades/gloves_tech.tres": "icon_gloves_tech.png",
    "data/upgrades/staff_explosion.tres": "icon_staff_explosion.png",
    "data/upgrades/staff_flame.tres": "icon_staff_flame.png",
    "data/upgrades/staff_might.tres": "icon_staff_power.png",
    "data/upgrades/staff_ice.tres": "icon_staff_ice.png",
    "data/upgrades/enchant_explosion.tres": "icon_enchant_explosion.png",
    "data/upgrades/enchant_flame.tres": "icon_enchant_flame.png",
    "data/upgrades/enchant_ice.tres": "icon_enchant_ice.png",
    "data/upgrades/enchant_power.tres": "icon_enchant_power.png",
    "data/upgrades/damage_up.tres": "icon_attr_damage.png",
    "data/upgrades/move_speed_up.tres": "icon_attr_move_speed.png",
    "data/upgrades/pickup_range_up.tres": "icon_attr_pickup_range.png",
    "data/upgrades/projectile_lifesteal_up.tres": "icon_attr_lifesteal.png",
    "data/upgrades/critical_up.tres": "icon_attr_critical.png",
    "data/upgrades/defense_up.tres": "icon_attr_defense.png",
    "data/upgrades/weapon_range_up.tres": "icon_attr_range.png",
    "data/upgrades/regeneration.tres": "icon_attr_regeneration.png",
}


def remap_frames() -> None:
    for relative, frames_name in FRAMES_REMAP.items():
        path = ROOT / relative
        text = path.read_text(encoding="utf-8")
        new_path = f"{FRAMES_ROOT}/{frames_name}.tres"
        if new_path in text:
            continue
        assert text.count('[ext_resource type="SpriteFrames"') == 1, relative
        start = text.index('[ext_resource type="SpriteFrames"')
        end = text.index("]", start) + 1
        line = text[start:end]
        original_id = line.split('id="', 1)[1].split('"', 1)[0]
        new_line = f'[ext_resource type="SpriteFrames" path="{new_path}" id="{original_id}"]'
        text = text[:start] + new_line + text[end:]
        path.write_text(text, encoding="utf-8")
        print(f"frames {relative} -> {frames_name}")


def assign_icons() -> None:
    for relative, icon_name in ICON_ASSIGN.items():
        path = ROOT / relative
        text = path.read_text(encoding="utf-8")
        icon_path = f"{ICON_ROOT}/{icon_name}"
        if icon_path in text:
            continue
        lines = text.splitlines()
        # 在脚本 ext_resource 之后插入图标 ext_resource，并更新 load_steps。
        script_index = -1
        for index, line in enumerate(lines):
            if not line.startswith("[ext_resource"):
                continue
            if "upgrade_definition.gd" in line or "armor_definition.gd" in line:
                script_index = index
                break
        assert script_index >= 0, relative
        icon_id = "icon"
        lines.insert(script_index + 1, f'[ext_resource type="Texture2D" path="{icon_path}" id="{icon_id}"]')
        text = "\n".join(lines) + "\n"
        if "[resource]" not in text:
            raise AssertionError(relative)
        text = text.replace("[resource]\n", f'[resource]\nicon = ExtResource("{icon_id}")\n', 1)
        # 更新 load_steps（仅在该文件确有该字段时）
        if "load_steps=" in text:
            head_end = text.index("]\n")
            head = text[:head_end]
            steps = int(head.split("load_steps=")[1].split(" ")[0])
            text = head.replace(f"load_steps={steps}", f"load_steps={steps + 1}", 1) + text[head_end:]
        path.write_text(text, encoding="utf-8")
        print(f"icon {relative} -> {icon_name}")


if __name__ == "__main__":
    remap_frames()
    assign_icons()
    print("Wired combat visuals.")
