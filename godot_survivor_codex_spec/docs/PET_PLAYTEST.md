# 四宠庭院与武器扩展验收

日期：2026-09-20；Godot 4.7.1 stable；macOS / Apple M5 / OpenGL Compatibility。

## 完成内容与文件作用

- `assets/sprites/pets/`、`data/visuals/`：虎妞小眼绷脸、黑豹保留原稿、小四白底狸花、小七深色虎斑，各四帧；新增飞叶刃、回旋骨棒和环绕铃铛动画。
- `assets/backgrounds/`、`assets/audio/`、`tools/generate_audio.py`：庭院背景与原创 8 个音频素材，完整生成提示词见 `assets/素材说明.md`。
- `data/enemies/`、`scenes/actors/enemies/`、`data/waves/default_run.tres`：两只猫复用 EnemyActor，2:30 后加入混合池。
- `data/weapons/`、`data/projectiles/`、`data/upgrades/`：三把武器，穿透、弹速、体积、暴击、自然恢复，三项专属强化与三项武器获取。升级池合计 21 项。
- `scripts/combat/`、`scripts/components/weapon_controller.gd`、`scripts/actors/player_actor.gd`：配置驱动的直射、返回、环绕；运行时修正历史让后来获取的武器继承通用强化。
- `scripts/systems/game_audio.gd`、`scripts/ui/session_controls.gd`、现有 UI：音效节流与清理、中文 HUD/菜单、暂停静音、Boss 血条、武器栏。

## 修复与公共接口

- “弹数 +1”原来确实创建多弹，但初始扩散角为 0，弹体完全重叠，造成类似穿透的观感。现在魔杖扩散为 18 度；穿透另设升级，断言分别验证。
- `PlayerActor.add_weapon(definition, allow_duplicate=false)`、`has_weapon(id)`、`weapon_added(controller)`：起始配置仍允许同种武器多个独立控制器，升级获取禁止重复。
- `UpgradeDefinition.required_weapon_id/weapon_definition`：专属筛选与授予；未持有对应武器时不提供专属选项。
- `ProjectileDefinition.MotionType/visual_frames/visual_scale/orbit_radius/orbit_speed`：行为与表现配置，不复制武器脚本。
- `WeaponRuntimeModifier`、`ProjectileSpawnContext` 新增穿透、速度、体积、暴击修正；不回写共享 `.tres`。
- `GameAudio.play_cue/set_muted/finish_run`；`SessionControls.initialize/toggle_pause`，升级和结算暂停不能被 Esc 跳过。

## 执行命令

以下在项目目录执行：

```bash
GODOT=/Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --log-file /tmp/pet-import.log --path . --editor --quit
"$GODOT" --headless --log-file /tmp/pet-boot.log --path . --quit-after 300
for test in tests/smoke/*_smoke_test.gd; do
  "$GODOT" --headless --log-file "/tmp/arsenal-${test##*/}.log" --path . --script "res://$test" || exit 1
done
"$GODOT" --headless --log-file /tmp/pet-soak.log --path . --script res://tests/smoke/enemy_spawner_soak_test.gd
"$GODOT" --path . --log-file /tmp/arsenal-render.log --script res://tests/smoke/arsenal_smoke_test.gd -- --capture
```

## 验证结果

- 全部 27 项快速烟雾测试通过；涵盖移动、索敌、弹体物理命中、经验、升级、五分钟 Boss 单次生成、胜负与连续三次重开。
- 新专项验证弹数和穿透分离、晚获取继承、专属隔离、回旋返程、环绕半径、暴击双倍、每秒恢复、弹速移动距离、四帧裁切边界。
- 120 秒生成稳定性测试通过：30/60/90/120 秒场上均为 30；另有 140 上限快速密度测试。
- GUI 截图确认四宠、武器和背景透明裁切正常，中文升级面板无截断。截图来自自动布置的验收场景，不冒充人工完整游玩。
- 静音、暂停/恢复及不能跳过升级/结算有专项测试。

## 限制与如实说明

- 未执行完整五分钟人工操作或主观听感验收；新武器数值是第一版，短测不是长期性能或平衡保证。
- 受伤测试增加一帧预热，排除资源加载首帧耗时导致 Timer 比 Tween 提前结束；扩散测试改为比较原始配置快照，不再硬编码 0 度。
- headless 环境仅加载背景/短音资源，不创建虚拟音频播放流；真实窗口播放正常，退出/重开显式释放音频。首次 GUI 快速退出曾报告音频播放流残留，补清理后武器专项 GUI 退出无警告。
- 沙箱曾限制用户日志和系统证书读取，最终复验使用 `/tmp` 独立日志和允许访问的环境，不是玩法错误。
- 素材名与界面中文化，历史文件和代码标识符保留原命名；`baseline-1.0` 仍是历史冻结快照。
