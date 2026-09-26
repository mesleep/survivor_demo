# DEV_HANDOFF：开发交接文档

> 面向接手的全新 coding agent。本文不依赖任何聊天记录，读完即可继续开发。
> 权威规则见 `AGENTS.md`、`docs/PROJECT_SPEC.md`、`docs/TASKS.md`、`docs/实施蓝图/`（README、规则决策、任务索引、验证协议、执行记录）。本文只做现状与交接补充。

## 0. 元信息（先核对）

- 仓库根：`/Users/taochenhui/codesource/survivorDemo/godot_survivor_codex_spec`
- 分支：`feat/dark-comic-art`（不要推送远端；不要做微信小游戏迁移；不要引入第三方插件）
- 最新提交：以 `git log --oneline -5` 为准。`fb1a600` 之后，本会话已提交按钮修复、11 个属性图标接入和菜单/升级卡素材接入三笔变更，并新增本文件。
- 引擎：Godot `4.7.1.stable.official.a13da4feb`，可执行文件 `/Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot`
- 基线命令：
  - 解析：`"$GODOT" --headless --path . --editor --quit`
  - 启动：`"$GODOT" --headless --path . --quit-after 300`
  - 快速冒烟：逐个运行 `tests/smoke/*_test.gd`（排除 `enemy_spawner_soak_test.gd`），当前 **70 项全部退出码 0**
  - 压力：`"$GODOT" --headless --path . --script res://tests/smoke/enemy_spawner_soak_test.gd`（120 秒，30 敌上限）
  - 图形实拍（需非 headless）：`tests/smoke/v2_art_preview.gd`（`-- --upgrade` / `-- --end` / `-- --hit`）、`menu_preview.gd`、`option_preview.gd`、`new_content_preview.gd`、`new_asset_sheet_preview.gd`，输出到 `art_review/`
- 工作树状态：干净（本会话三笔提交已包含 11 个属性图标 PNG/`.import` 与本文件）。

## 1. 当前开发目标

- 产品：Godot 4.7.1 + GDScript 的 2D 俯视角 Survivor-like 最小可玩 Demo（参考《吸血鬼幸存者》《土豆兄弟》）。
- 核心循环：`移动 → 自动攻击 → 击杀 → 拾取经验/金币 → 升级三选一（可刷新）→ 敌人增强 → 终局 Boss → 胜负结算 → 重开`。
- 当前单局时长：**10 分钟（600 秒）**，10:00 生成 Boss 且普通敌人继续刷新；5:00 后降低基础/通用卡权重、提高质变权重。
- 实施蓝图 T01–T34 已完成，T35 自动验收通过、**真实五分钟/十分钟人工游玩未完成**。
- 交付约束（全局不变量）：数据驱动（所有玩法数值在 `Resource`/`@export`）；组件与信号组合优先，不复制角色/敌人/武器脚本；`.tres` 是共享静态定义，运行时状态不得回写；保持主场景可启动；中文注释与文档；每个任务单独中文提交。

## 2. 已完成功能（T01–T34 + 用户追加）

### 蓝图任务（`docs/实施蓝图/任务索引.md`）
- T01–T15：目录/快照/主菜单/六格装备、单件等级与质变模型、升级分类过滤、防具接口、射程语义、伤害结算基座、基础盔甲、弓/多重/万箭、蓄力法杖。
- T16 爆炸与范围命中：`ExplosionDefinition` + `AreaHitResolver` + `ExplosionEffect`；爆炸弹首击引爆停用、同次去重、`hits_direct_target` 可配。
- T17 火焰 DoT 与火坑：`DamageOverTimeEffect` + `StatusEffectComponent`；`GroundDamageAreaDefinition` + `GroundDamageArea`；dot 标签不反伤。
- T18 威能分支：`WeaponRuntimeModifier` 改可导出 Resource + 捆绑修正；单武器射程倍率；冷却下限。
- T19 寒冰减速/冻结/分裂：状态组件扩展；`MovementSlowEffect`/`FreezeEffect`；冰枪穿透 + 对称分裂不递归；Boss 控制免疫。
- T20 附魔箭联动：四张附魔卡共享 `branch_id=enchant` 互斥；需弓满级且法杖已质变对应分支；数值独立。
- T21–T23 盔甲质变：反伤刺甲（`ThornAuraComponent` 周期刺圈 + 受击返还）、骑士（固定减伤 + 免疫概率，受 `CombatRules` 上限）、狂战（`BerserkDrainComponent` 失血 + 半血吸血 + 一次免死）。
- T24 头盔/手套/科技单件：手套冷却/射程；科技单件每秒经验 + 宝石倍率（统一入口、暂停不计时）。
- T25 科技三件套与发射器：三件都需科技质变才激活；可撤销高移速 + 飞行视觉；数据驱动发射器，随机目标取自 `TargetingService`；**激光按用户要求“同时获得、交替攻击”**（奇数发 3 枚爆炸导弹、偶数发 1 道高速穿透激光）。
- T26 金币与结算：`EconomyRules`（15% 掉 1 金、结算每击杀 2 金）；`CoinPickup` 原子拾取；`GameResult` 含拾取/击退/总金币；结算一次。
- T27 版本化存档：`Profile` + `ProfileStore`（临时文件→校验→备份→替换；损坏/失败保留旧档）；`GameEntry` 结算累加金币并写档。
- T28 升级刷新：每局刷新 = 基础 1 + 档案加成；刷新换卡不自动应用；跨升级保留、重开归零。
- T29 解锁购买：`unlock_cost` 写 Resource；`UnlockService` 唯一交易入口（失败回滚）；菜单锁定/价格显示；开局只接受已解锁。
- T30 永久强化：`PermanentUpgradeDefinition`/`Catalog`；`UnlockService` 购买；开局快照写入玩家，运行中不读档案。
- T31 远程射手：`player_ranger` 复用 `PlayerActor`；被动“带 ranged 标签武器伤害 +10%”；默认锁定需 120 金。
- T32 基础剑：`AttackMode.MELEE_FAN` 近战扇形（不发射弹体）；`MeleeSlashEffect`。
- T33 新敌人与地图：远程「月影投手」（保持距离、发射弹体）、精英近战「石甲兽」（高血高速）；`EnemyDefinition.attack_type` 等；`ArenaDefinition` + 「月蚀荒原」。
- T34 界面收口：主菜单面板/按钮样式、局内金币图标、主菜单两栏布局。

### 用户追加（本会话期间用户本人提交）
- `3e230da 优化菜单与战斗平衡`：默认法师改为蓄力法杖开局；正式候选武器收敛为弓/法杖/剑（旧星光魔杖/飞叶刃/骨棒/铃铛仅在 `tests/fixtures/` 兼容测试）；Boss 远程弹 `boss_bolt.tres`；`UnlockService.unlock_all_for_testing`；`balance_revision_smoke_test`。
- `4d11c91 延长终局并调整后期升级权重`：单局 300→600 秒；`UpgradeSystem` 加权抽取 + 后期权重/保底（`late_*` 导出）；`ten_minute_flow_smoke_test`。

### 用户追加（本会话由我实现并提交）
- `829ceef 装备图标/质变名、设置面板、金币兜底与地图选择`：
  - 装备栏显示图标与名称，质变后显示「基础名·分支名」并换质变图标（`EquipmentProgress.branch_display_name`/`branch_icon`）。
  - 局内 Esc 暂停并打开设置面板（声音开关 + 返回主菜单 + 退出游戏）；主菜单也有设置与退出游戏。
  - 升级池无可用卡时给金币兜底卡（`COIN_REWARD`，`UpgradeSystem.fallback_upgrades`）。
  - 目录 `maps` + `RunLoadout.map_id`，主菜单可选月光庭院/月蚀荒原并在单局应用。
- `a751f58 升级卡图标排版并补齐 46 个升级图标`：`LevelUpPanel` 改为自绘卡面（图标 + 分类标题 + 描述）；46 个升级卡补图标。
- `fb1a600 主菜单与暂停菜单新增退出游戏`：两处 `get_tree().quit()`。

### 用户追加（2026-09-26，本会话实现）
- `fix: 修复菜单与暂停按钮贴图被压扁`：`fb1a600` 为省宽度把按钮样式内容边距压到 12/6，按钮实际高度低于贴图上下 60px 的九宫格边距而变形。现保留上下纹理边距、只收窄左右内容边距；主菜单地图区改横排，1280 宽内不溢出。
- `feat: 接入 11 个通用属性升级图标`：`fire_rate/projectile_count/projectile_size/projectile_speed/repeat_shot/bonus_projectile/max_health/heal/dodge/immune/pierce` 全部补 `icon`；`wire_combat_visuals.py` 修正 `icon` 必须插在 `script` 之后的顺序问题；`v2_art_validation.gd` 新增“所有升级必须有新版图标”检查。
- `feat: 主菜单卡片/标签与竖版升级卡应用新素材`：卡片应用 `menu_card_base`，分区标题应用 `menu_tab`；`LevelUpPanel` 三选一改为竖版卡面（200×300，随 `ui_scale`）并应用 `ui_upgrade_card`，图标置顶、标题/描述居中，刷新按钮保留。
- `fix: 修复主菜单按钮文字超出背景框`：按钮样式恢复完整九宫格内容边距，角色/武器/地图信息移到标题右侧，底部只留地图与操作按钮。
- `feat: 数值/素材工作台与存档重置`：主菜单设置新增「重置存档」（带确认）与「数值/素材工作台」。工作台按 13 类枚举 `data/` 资源，中文字段名取脚本 `##` 注释，支持改数值（即时生效）、更换素材/引用并保存回 `.tres`。主要定义脚本补了中文 `@export_group`。新档默认解锁免费角色起始武器，购买角色附送起始武器（否则 0 金新档无武器）。
- 数据/素材总入口见 `docs/数据与素材索引.md`。

### 美术素材（外部 AI 生成，已接入）
- 第一批（`f232b74`）：武器/弹体/特效/金币/图标 84 PNG → 19 个 SpriteFrames。
- 第二批（`7891b5d`）：B02 射手、月影投手、石甲兽、月蚀荒原背景、铁剑与斩击弧光、喷气/导弹尾焰、主菜单整套、科技徽记、敌方弹体。
- 激光（`220da85`）：激光射束/命中/口闪；`ProjectileDefinition.hit_effect_*`/`muzzle_*`。

## 3. 当前架构与关键设计决定

### 3.1 入口与场景流
- `scenes/bootstrap/game_entry.tscn`（主场景，`project.godot` 指向它）：`GameEntry` 管主菜单 ↔ 单局、档案加载、结算写档、解锁交易、永久强化注入、地图/刷新次数注入。
- `scenes/bootstrap/main.tscn`：旧直启入口（默认角色 + 起始武器，无档案），所有旧测试用它，**不要破坏**。
- `scenes/gameplay/game_session.tscn`：单局组合根（`GameSession` + Arena + Actors/Enemies/Projectiles/Pickups + Systems + UI）。导出字段挂载：目录、战斗规则、经济规则、金币场景、科技套装、永久目录、RunDefinition、经验宝石场景。

### 3.2 数据驱动 Resource（`data/`）
- 目录：`data/catalog/default_catalog.tres`（角色 2、武器 3、防具 3、地图 2）。
- 角色 `CharacterDefinition`（含 `unlock_cost`、`passive_damage_multiplier`/`passive_weapon_tag`）。
- 武器 `WeaponDefinition`：`AttackMode`(PROJECTILE/MELEE_FAN)、`TargetMode`(NEAREST/RANDOM)、蓄力、近战参数、`tags`、`icon`、`visual_scale`、`alternate_projectile_definition/count`、`unlock_cost`。
- 弹体 `ProjectileDefinition`：直线/回旋/环绕、爆炸、DoT、地面区域、减速/冻结、分裂、命中层 `collision_mask`、`visual_modulate`、尾焰 `trail_*`、命中/口闪 `hit_effect_*`/`muzzle_*`。
- 升级 `UpgradeDefinition`：`UpgradeType`（44 种，含 `COIN_REWARD=44`）、`UpgradeCategory`(GENERIC/ACQUIRE_EQUIPMENT/BASE_UPGRADE/ASCENSION/BRANCH_UPGRADE)、`branch_id`、`target_equipment_id`、`projectile_definition`、`weapon_modifier`、`icon`、`weight`、`max_stacks`。
- 防具 `ArmorDefinition`（防御/移速惩罚/冷却/射程/图标）；盔甲质变档案 `Thorn/Knight/BerserkArmorDefinition`；科技 `TechArmorDefinition`/`TechSetDefinition`。
- 战斗 `data/combat/`：`CombatRules`、`ExplosionDefinition`、`DamageOverTimeEffect`、`GroundDamageAreaDefinition`、`MovementSlowEffect`、`FreezeEffect`。
- 经济 `data/economy/EconomyRules`；局外 `data/progression/PermanentUpgradeCatalog`；地图 `data/maps/ArenaDefinition`；波次 `data/waves/RunDefinition`+`DifficultyStage`。
- **禁止写死数值**：新数值一律加 `@export` 或 Resource；已实现的写死项在触及相关任务时迁出。

### 3.3 运行时状态与共享 Resource 分离
- 共享 `.tres` 只读；运行时状态在各控制器/组件/`Profile`/`RunLoadout`/`EquipmentProgress`。
- `RunLoadout`（RefCounted）：character_id、candidate/starting weapon ids、`map_id`；构造复制数组；`validate`/`resolve_*`。
- `Profile`（RefCounted）：version、coins、unlocked ids、refresh_bonus、permanent_upgrades；`ProfileStore` 原子读写 `user://`（正式路径 `user://profile.json`，测试用独立路径）。
- `EquipmentProgress`（RefCounted）：base_level、branch_id、branch_upgrade_levels、branch_display_name、branch_icon；`copy()` 快照。

### 3.4 战斗管线
- `ActorBase.apply_damage`：免疫 → 闪避 → 防御（`max(原始−防御, 原始×最低比例)`）→ 扣血 → 反伤/吸血/死亡；`dot`/`reflect` 标签防递归；一次免死标记。
- `ProjectileBase.on_hit`：直击伤害 → 附加效果（DoT/地面/减速/冻结）→ 命中特效 → 分裂 → 爆炸（有爆炸则引爆停用）→ 穿透。
- `WeaponController`：冷却/弹数/扩散/穿透/暴击/吸血/额外弹/追加射击/多轮/随机索敌/近战扇形/弹体覆盖/交替攻击；`get_effective_*` 读取角色级加成。
- `TargetingService`：0.1s 缓存候选，`get_nearest_target`/`get_random_target`，不每帧搜树。
- `AreaHitResolver`：受控圆形查询 + 按 Actor 实例去重，供爆炸/火坑/刺圈/近战使用。

### 3.5 UI 与输入
- `GameEntry` → `MainMenu`（角色/武器/地图/永久强化/解锁/设置/退出；角色/武器/地图信息显示在标题右侧）；`SessionControls`（局内 HUD 附加层：金币、装备栏、状态、Boss 血条、设置面板）；`SettingsPanel`（声音/重置存档/数值素材工作台/返回主菜单/继续/退出，暂停时隐藏重置与工作台）；`LevelUpPanel`（竖版三卡 + 刷新按钮）；`EndPanel`。
- 输入：WASD/方向键移动；Esc 打开/关闭设置（暂停）；M 静音；升级/结算时暂停。
- 主题：`data/visuals/v2_dark_comic/menu_*_style.tres`（九宫格面板/按钮三态；按钮使用完整纹理内容边距，保证文字落在边框内）。
- 开发工具：`ConfigWorkbench`（`scripts/tools/config_workbench*.gd` + `scenes/tools/config_workbench.tscn`），入口在主菜单设置；服务层可 headless 测试，保存直接写 `res://` 的 `.tres`。

### 3.6 关键规则决策
见 `docs/实施蓝图/规则决策.md` D01–D32。重点：D04 装备基础 1→5、满级二选一互斥质变、专属 3 级；D06 射程语义；D07 伤害顺序；D08 附魔快照；D09 科技三件套；D10 经济；D11 永久成长；D12 新内容；D13 爆炸；D14 火焰；D15 威能；D16 寒冰；D17 附魔；D18 刺甲；D19 骑士；D20 狂战；D21 头脚手；D22 科技套装；D23 金币；D24 存档；D25 刷新；D26 解锁；D27 永久强化；D28 射手；D29 剑；D30 新敌人/地图；D31 激光（同时获得、交替攻击）；D32 装备显示/设置/兜底/地图。

## 4. 本次会话修改过的文件及作用

> 提交区间：`24fc2a3`(T16) → `fb1a600`，另有用户提交 `3e230da`、`4d11c91`。

### 新增脚本（核心）
- `scripts/combat/area_hit_resolver.gd`、`explosion_effect.gd`、`melee_slash_effect.gd`
- `scripts/combat/damage_result.gd`（T10 起）；`scripts/combat/projectile_base.gd`（大幅扩展）
- `scripts/components/status_effect_component.gd`、`ground_damage_area.gd`、`thorn_aura_component.gd`、`berserk_drain_component.gd`
- `scripts/core/profile.gd`、`profile_store.gd`、`unlock_service.gd`、`equipment_progress.gd`（T05）
- `scripts/ui/settings_panel.gd`
- `scripts/combat/*` 数据类：`data/combat/explosion_definition.gd`、`damage_over_time_effect.gd`、`ground_damage_area_definition.gd`、`movement_slow_effect.gd`、`freeze_effect.gd`
- `data/armor/thorn_armor_definition.gd`、`knight_armor_definition.gd`、`berserk_armor_definition.gd`、`tech_armor_definition.gd`、`tech_set_definition.gd`
- `data/economy/economy_rules.gd`、`data/progression/permanent_upgrade_definition.gd`、`permanent_upgrade_catalog.gd`、`data/maps/arena_definition.gd`

### 修改脚本（关键）
- `scripts/actors/actor_base.gd`（伤害管线/状态/免死/额外吸血/冷却射程加成）
- `scripts/actors/player_actor.gd`（各分支激活、永久强化、装备显示名/图标、科技经验、金币、套装、被动）
- `scripts/actors/enemy_actor.gd`（远程行为、弹体容器）
- `scripts/components/weapon_controller.gd`（弹体覆盖、爆炸/区域/冻结/分裂倍率、随机索敌、近战、交替、clear_cooldown）
- `scripts/core/game_session.gd`（地图/刷新/永久注入、金币结算、返回主菜单、经济、科技套装）
- `scripts/core/game_entry.gd`（档案/解锁/永久/菜单注入/结算写档/返回菜单）
- `scripts/core/run_loadout.gd`（`map_id`、resolve/validate）
- `scripts/core/game_result.gd`（金币字段）
- `scripts/systems/upgrade_system.gd`（分类过滤、刷新、金币兜底、后期权重、保底）
- `scripts/systems/targeting_service.gd`（随机目标）
- `scripts/systems/enemy_spawner.gd`（projectile_parent）
- `scripts/ui/main_menu.gd`、`session_controls.gd`、`level_up_panel.gd`、`end_panel.gd`
- `data/weapons/weapon_definition.gd`、`data/projectiles/projectile_definition.gd`、`data/upgrades/upgrade_definition.gd`、`data/enemies/enemy_definition.gd`、`data/characters/character_definition.gd`、`data/armor/armor_definition.gd`、`data/catalog/content_catalog.gd`

### 新增/修改场景与 Resource
- 场景：`scenes/ui/settings_panel.tscn`、`scenes/actors/enemies/enemy_shooter.tscn`、`enemy_brute.tscn`、`scenes/actors/player/player_ranger.tscn`；修改 `main_menu.tscn`、`game_session.tscn`、`arena.tscn`、`coin_pickup.tscn`、`level_up_panel.tscn`。
- 武器/弹体：`data/weapons/{bow,staff,sword,tech_launcher}.tres`；`data/projectiles/{arrow_*, staff_*, tech_laser, tech_missile, enemy_bolt, boss_bolt}.tres`。
- 升级：大量 `data/upgrades/*.tres`（法杖四分支+专属、附魔箭、盔甲四分支+专属、头脚手/科技、剑、金币卡、通用属性卡）；46 个补了 `icon`。
- 防具/经济/局外/地图/波次：`data/armor/*.tres`、`data/economy/default_economy_rules.tres`、`data/progression/*.tres`、`data/maps/{moonlit_courtyard,eclipse_wasteland}.tres`、`data/waves/default_run.tres`。
- 视觉：`data/visuals/v2_dark_comic/*_frames.tres`（新增 ~27 个）、`menu_*_style.tres`。

### 素材与工具
- `assets/v2_dark_comic/**`：多批透明 PNG（武器/弹体/特效/金币/图标/敌人/射手/地图/菜单/激光）。
- `tools/build_v2_visual_resources.py`、`tools/build_combat_visual_resources.py`（生成 SpriteFrames）、`tools/wire_combat_visuals.py`（批量接入/写图标）。
- `art_review/`：实拍截图（`v2_equipment_bar_preview.png`、`v2_settings_preview.png`、`v2_main_menu_preview.png`、`v2_new_content_preview.png`、`v2_upgrade_panel_preview.png`、`v2_asset_sheet_preview.png` 等）。

### 测试
- `tests/smoke/`：新增约 30 个专项测试（explosion_aoe、flame_dot、staff_might、ice_slow/freeze/split、enchant_arrow、thorn/knight/berserk_armor、helmet_gloves_tech、tech_set、coin_economy、profile_store、upgrade_refresh、unlock_shop、permanent_upgrade、ranger_character、sword_melee、enemy_map、full_run_content、equipment_display、settings_panel、coin_fallback、map_selection 等）。当前快速冒烟 **68 项**。
- `tests/fixtures/legacy_*`：用户提交的旧武器兼容夹具。

### 文档
- `docs/实施蓝图/规则决策.md`（D13–D32）、`任务索引.md`、`执行记录.md`；`docs/TASKS.md`、`docs/CHANGELOG.md`、`docs/整理设计/美术素材清单.md`；本文件 `docs/DEV_HANDOFF.md`。

## 5. 尚未完成的问题

1. **T35 真实人工游玩未完成**（唯一硬性未完成项）：需在目标机实际游玩约 5–10 分钟，验收移动/自动攻击/升级三选一/刷新/Boss/胜负/重开、双角色可辨认、新敌人（远程/精英）与激光强度、手感与音效、macOS 长时间稳定性、长期数值平衡；并重点看新的竖版升级卡与菜单卡框在实际点击/分辨率下的表现。
2. **可选美术缺口**：`ui/icon_menu_{shop,unlock,permanent,achievement,skin}.png`（D06 局外菜单图标）、`enemies/B09_月夜领主_头像.png`（Boss 血条徽记）。不影响可玩。
3. **未实现的次要内容**：近战质变、非金币解锁条件、永久强化的重置/退款、正式商店版式（F03 已在主菜单部分使用）、C08 激光之外的套装扩展。
4. **未单独截图验证**：局内金币/科技徽记图标已接入但未单独实拍；主菜单设置面板已随 2026-09-26 工作台一并实拍（`v2_menu_settings_preview.png`）。
5. **工作台范围**：SpriteFrames 等复杂资源不在工作台内直接编辑，需在上层定义的 `visual_frames` 字段更换引用；工作台保存直接写 `res://`，只适合开发环境。

## 6. 已知 bug / 风险

1. **`.tres` 的 `[ext_resource]` 必须写在 `[resource]` 之前**；且 `icon = ExtResource(...)` 必须写在 `script = ...` 之后，否则属性会被忽略（历史上踩过：一批图标静默失效）。`tools/wire_combat_visuals.py` 已改为插在 `script` 之后，`v2_art_validation.gd` 会兜底校验所有升级都带新版图标。
2. **九宫格按钮样式的上下内容边距决定按钮最小高度**：`menu_button_*_style.tres` 只收窄了左右内容边距、保留上下纹理边距（60px）；后续若再压按钮高度或加底部控件，需同时复核贴图高度与 1280 宽布局。
3. **测试偶发抖动**：`bow_multishot`/`staff_charge`/`ending_restart` 曾因“首帧起始武器自动发射/随机首卡为闪避免疫”抖动，已在测试内隔离（移除首帧弹体、关闭概率免伤）。若再遇到，优先检查测试的确定性而非产品逻辑。
4. **性能/平衡未定稿**：所有分支/经济/永久数值均为首版，需人工游玩后调整（改 Resource 即可）。
5. **预览脚本退出有对象未释放 warning**（仅预览脚本，不影响游戏与回归）。
6. 主菜单默认解锁“价格为 0”的角色/武器；射手（120 金）与部分武器需在菜单购买或点“测试：一键解锁全部”。
7. 主菜单永久强化 5 项在卡片内需要滚动查看；升级卡竖版布局下长标题会自动折行，属预期。
8. 新档默认只解锁免费角色的起始武器；若把某角色/武器的 `unlock_cost` 改回 0，需要重开菜单（`GameEntry._ensure_profile_store` 在启动时计算默认解锁）。

## 7. 下一步建议执行顺序

1. **T35 人工游玩验收**：由用户在目标机执行；据反馈用工作台或 Resource 调数值（不写死）。这是当前唯一硬性未完成项。
2. 可选：补 D06 菜单图标与 Boss 徽记；补局内金币/科技徽记实拍。
3. 若继续扩展内容：按 `docs/实施蓝图/任务模板.md` 新增原子任务卡，保持“一次一个任务、单独提交、先测试后实现”；新字段记得在 `@export` 上方补 `##` 中文注释，工作台会自动显示。

## 8. 新会话继续工作时必须知道的上下文

- **工作方式**：文件驱动。开始先读 `AGENTS.md`、`docs/PROJECT_SPEC.md`、`docs/TASKS.md`、`docs/实施蓝图/README.md`+`规则决策.md`+`任务索引.md`+当前任务卡；核对 `git status`、分支、现有实现；一次只做一个任务 ID；先写专项测试再做最小实现；完成后按 `验证协议.md` 跑解析/启动/专项/回归，写 `执行记录.md`，同步 `任务索引.md`、`TASKS.md`、`CHANGELOG.md`；任务通过后单独中文提交（`type: 中文说明`）。不要推送远端、不装插件、不做微信迁移、不改无关文件。
- **验证门槛**：解析 0、启动 300 帧 0、相关回归 0；视觉/手感必须 GUI 实拍或明确标记“未完成”，不得冒充通过。
- **不要破坏旧直启**：`main.tscn` 与 `tests/fixtures/legacy_*` 是兼容基线，很多测试依赖默认角色/旧武器。
- **共享 `.tres` 不回写**；数值可配置；中文注释；静态类型；`class_name`；snake_case 文件名/变量。
- **测试确定性**：新增/修改测试用受控随机种子、受控计时/敌人容器；避免升级暂停与真实波次干扰。
- **当前默认内容**：角色 2（法师/射手）、武器 3（弓/法杖/剑）、防具 3、地图 2；单局 10 分钟；Boss 在 10:00。
- **UI 素材现状**：11 个通用属性图标已接入；主菜单用 `menu_card_style`/`menu_tab_style`，升级三选一用 `upgrade_card_style`（竖版 200×300，随 `ui_scale`）。
- **数据/素材入口**：改数值与换素材见 `docs/数据与素材索引.md`；游戏内工作台在主菜单 → 设置 → 「数值/素材工作台」。
- **实拍命令**（非 headless）：`"$GODOT" --path . --script res://tests/smoke/<preview>.gd`，截图在 `art_review/`。

（本文只描述现状，未修改任何业务代码。）
