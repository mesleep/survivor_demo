# 变更记录

本项目的重要变更记录在此。

## [Unreleased]

### 规则决策 D08–D12 定案与“数值可配置”全局规则（2026-09-25）

- D08：附魔箭继承做成可配置模式（`SNAPSHOT`/`LIVE`），首版默认快照。
- D09：科技三件套必须三件都选择科技质变才激活。
- D10：每敌 15% 掉 1 金，结算按 `击杀数 × 2`，`user://` 版本化 JSON；数值全配置化。
- D11：永久强化按建议首版实现（属性分级购买、初始仅默认角色与现有武器）。
- D12：T31 射手被动 +10% 远程伤害；T32 剑仅基础扇形；T33 暂不新增敌人/地图。
- 新增全局要求：所有玩法数值必须放在 `Resource` 或 `@export` 字段，禁止写死。

### 整理设计实施规划（2026-09-25）

- 新增 `docs/整理设计/逐步实施方案.md`，对照七份设计稿和当前实现，整理系统差距、待确认规则、分步依赖与验收标准；本次未修改游戏功能或任务完成状态。
- 新增 `docs/实施蓝图/`，把路线拆为任务索引、规则决策、六组具体任务卡、验证协议与执行记录模板，作为后续文件驱动开发的工作单；任务初始状态均为未开始。

### T01 当前版本回归基准和规则定案（2026-09-25）

- 记录当前四把武器、21 项升级、胜负与重开的现状清单，确认 `逐步实施方案.md` 的“已有/缺失”判断仍准确。
- D01 候选池、D02 装备位、D03 局内获取、D07 伤害顺序依用户授权采用“建议”首版并改为“已确认”；D04/D05/D06/D10/D11/D12 保持“待确认”。
- 基准证据：Godot 4.7.1 解析与主场景 300 帧退出码 0；27 项快速冒烟与 120 秒 soak 全部退出码 0；完整五分钟人工游玩未执行，标记未完成。本次未新增玩法代码。

### T02 角色/武器目录与单局配置快照（2026-09-25）

- 新增只读 `ContentCatalog`（`data/catalog/content_catalog.gd`）与默认目录 `default_catalog.tres`，按 ID 查询并校验重复/空引用/缺失场景。
- 新增运行时 `RunLoadout`（`scripts/core/run_loadout.gd`），保存角色 ID、候选武器 ID、起始武器 ID，复制数组并提供校验与解析；候选池上限 10（D01）。
- `GameSession` 新增 `content_catalog`、`auto_start`、`set_run_loadout()`、`run_started` 信号；`start_run()` 优先使用快照，缺失时回退旧 `player_definition`，不修改共享 `.tres`。
- `SessionControls` 改为经 `run_started` 延迟连接玩家，兼容菜单先创建 UI 再开局的流程。
- 新增 `run_loadout_smoke_test.gd`；解析、启动与 28 项快速冒烟通过。

### T03 主菜单选择与兼容启动（2026-09-25）

- 新增 `MainMenu`（`scripts/ui/main_menu.gd`、`scenes/ui/main_menu.tscn`）：按目录生成角色与候选武器按钮，校验后发出 `start_requested(loadout)`；起始武器自动保留、候选上限 10。
- 新增 `GameEntry`（`scripts/core/game_entry.gd`、`scenes/bootstrap/game_entry.tscn`）：主菜单与单局之间的路由，在 `start_run()` 前注入 `RunLoadout`，并跨重载记住上次选择。
- `project.godot` 主场景切换为 `game_entry.tscn`；`main.tscn` 保留为默认直启入口，既有测试与直接启动不受影响。
- 新增 `main_menu_smoke_test.gd`；解析、启动与 29 项快速冒烟通过。

### T04 六格装备清单与升级获取过滤（2026-09-25）

- `PlayerActor` 新增六格装备清单（D02）、`equipment_changed` 信号与统一获取入口 `can_acquire()`/`try_acquire_weapon()`；起始武器同样占格，重复获取不占新格。
- `UpgradeSystem` 的 `ACQUIRE_WEAPON` 过滤改用 `player.can_acquire()`，同时覆盖候选池（D01）、重复与满格；满格后获取卡消失但通用与专属升级照常。
- `GameSession.start_run()` 注入本局候选武器 ID；旧直启路径候选为空表示不限制，保持兼容。
- `SessionControls` 武器栏改为显示“装备 n/6”并监听装备变化。
- 新增 `equipment_slots_smoke_test.gd`；解析、启动与 30 项快速冒烟通过。

### T05 单件装备等级/质变运行时模型（2026-09-25）

- D04 经用户确认：装备基础等级 1→5、基础满级后两条互斥质变（每件每局一次）、分支专属升级 3 级；样板星光魔杖分支为星屑散射与星辉聚焦。
- 新增运行时 `EquipmentProgress`（基础等级、质变分支、分支专属层数）与 `copy()` 只读快照，不写入任何 `.tres`。
- `PlayerActor` 新增每装备进度字典与 `equipment_progress_changed` 信号，提供 `get_progress()` 及基础升级/质变选择/专属升级的唯一修改入口。
- 新增 `equipment_progress_smoke_test.gd`；解析、启动与 31 项快速冒烟通过。

### T06 升级候选的分类、前置与上限（2026-09-25）

- `UpgradeDefinition` 新增 `UpgradeCategory`（通用/获取/基础/质变/分支专属）与 `target_equipment_id`、`branch_id`，`get_target_equipment_id()` 统一解析目标装备。
- `UpgradeSystem.can_offer()` 集中执行前置、互斥与上限过滤：获取看候选/空格，基础看基础等级，质变需基础满级且未选分支，分支专属需匹配分支与上限；D05 首版保留均匀无放回抽取。
- `PlayerActor.apply_upgrade()` 支持基础升级、质变与分支专属三类进度应用。
- 三个获取升级资源标注 `category=1`；新增 `upgrade_category_smoke_test.gd`；解析、启动与 32 项快速冒烟通过。

### T07 星光魔杖样板质变（2026-09-25）

- 新增星光魔杖基础升级、两条互斥质变与各自分支专属升级共 5 个 Resource，并加入升级池。
- `PlayerActor.apply_upgrade()` 对基础/质变/专属先写入装备进度再应用效果，使质变与专属产生真实战斗效果；基础满级才出现质变，分支互斥且专属 3 级。
- `LevelUpPanel` 卡面新增【获取】【基础】【质变】【专属】中文分类标记。
- 新增 `weapon_ascension_smoke_test.gd`；解析、启动与 33 项快速冒烟通过。

### T08 防具静态定义与运行时装配接口（2026-09-25）

- 新增 `ArmorDefinition`（`data/armor/armor_definition.gd`，盔甲/头盔/手套类别、图标、预留基础/分支升级引用）。
- 装备清单支持武器与防具共存并记录类别；防具不创建 `WeaponController`，共用六格、重复与满格规则；新增 `armor_acquired` 信号与 `try_acquire_armor()` 等接口。
- `UpgradeDefinition` 新增 `ACQUIRE_ARMOR` 与 `armor_definition`；`ContentCatalog` 新增 `armors`；装备栏分列武器与防具。
- 新增 `armor_equipment_smoke_test.gd`；解析、启动与 34 项快速冒烟通过。

### T09 全武器射程 Buff 与射程语义（2026-09-25）

- D06 定案：基础索敌范围取 `min(角色攻击范围, 武器 target_range)`，再乘角色级“全武器射程”倍率；弹体可达距离仍由弹速×寿命决定。
- `ActorBase.get_weapon_range_multiplier()`（默认 1.0）与 `PlayerActor` 覆盖、`UpgradeType.ALL_WEAPON_RANGE`；新增“全武器射程 +10%”升级并加入池。
- 新增 `weapon_range_buff_smoke_test.gd`；解析、启动与 35 项快速冒烟通过。

### T10 防御/免疫/反伤伤害结算基座（2026-09-25）

- 新增可调 `CombatRules` Resource（最低伤害比例、闪避/免疫/反伤上限）与 `DamageResult` 结算结果。
- `ActorBase.apply_damage()` 重写为 免疫 → 闪避 → 防御 → 扣血 → 反伤 的统一管线，返回 `DamageResult`；闪避/免疫不扣血、不反伤、不吸血；`reflect`/`dot` 标签防止反伤递归；防御公式 `max(原始−防御, 原始×最低比例)`。
- `DamageFeedbackComponent` 绑定 `damage_dodged`/`damage_immune`，以代码文字占位显示“闪避/免疫”提示；正式素材清单见 `docs/整理设计/闪避免疫提示素材清单.md`。
- 新增防御/闪避/免疫升级（数值可在 Resource 调整）并加入升级池；`GameSession` 下发 `CombatRules`。
- 新增 `damage_resolution_smoke_test.gd`；解析、启动与 36 项快速冒烟通过。

### T11 基础盔甲（2026-09-25）

- `ArmorDefinition` 新增可调数值：基础防御、每级防御、移速惩罚与每级减轻；新增 `armor_basic.tres`、获取卡与强化卡，并加入目录与升级池。
- `PlayerActor` 按已装备防具及其基础等级汇总防御与移速惩罚，升级即刷新，满级惩罚归零；`SessionControls` 显示防御与当前移速。
- 新增 `armor_basic_smoke_test.gd`；解析、启动与 37 项快速冒烟通过。

### T12 基础弓箭（2026-09-25）

- 新增长弓与直线箭 Resource（冷却 1.2s、箭伤 12、箭速 850、射程 1000），获取卡与基础强化卡加入目录与升级池；武器/弹体暂复用现有动画占位。
- 新增 `bow_weapon_smoke_test.gd`；解析、启动与 38 项快速冒烟通过。

### T13 长弓多重射击（2026-09-25）

- `WeaponDefinition` 新增可配 `volley_interval_seconds`；`WeaponController` 支持同一次冷却内多轮发射（`get_effective_volley_count`），并抽取 `_fire_volley` 复用弹幕生成。
- 新增“多重射击”质变与“连轮/贯穿”专属升级（轮次、弹数、穿透三个独立属性）；重置/重开取消未完成轮次。
- 新增 `bow_multishot_smoke_test.gd`；解析、启动与 39 项快速冒烟通过。

### T14 长弓万箭齐发（2026-09-25）

- 长弓扩散角设为 25°（Resource 可改）；新增“万箭齐发”质变与“箭雨”专属（每轮弹数 +1），与多重射击分支互斥，只改变每轮弹数不改变轮数。
- 新增 `bow_volley_smoke_test.gd`；解析、启动与 40 项快速冒烟通过。

### T15 基础蓄力法杖（2026-09-25）

- `WeaponDefinition` 新增可配 `charge_seconds`/`charge_damage_multiplier`；`WeaponController` 支持可取消蓄力（`begin_charge`/`is_charging`/`get_charge_remaining`），释放后从释放时起算冷却。
- 新增蓄力法杖与法球、获取卡与基础强化并接入目录/升级池（外观占位）。
- 新增 `staff_charge_smoke_test.gd`；解析、启动与 41 项快速冒烟通过。

### T16 爆炸与范围命中（2026-09-25）

- 新增可配 `ExplosionDefinition`（半径、溅射伤害倍率、是否命中直击目标、碰撞掩码、目标上限、击退与特效参数）与复用查询 `AreaHitResolver`，同一次爆炸按 Actor 实例去重并过滤死亡/已释放/同阵营目标。
- `ProjectileBase` 命中后触发一次受控范围爆炸并立即停用；直击目标是否再吃溅射由 `hits_direct_target` 配置；表现由一次性 `ExplosionEffect` 承担，未提供 E02 素材时绘制占位圆环。
- 新增“爆炸法术”质变及“裂爆（范围 +25%/级）”“灼爆（溅射伤害 +20%/级）”专属升级；`WeaponController` 支持运行时弹体覆盖与爆炸倍率，`UpgradeDefinition` 新增 `EXPLOSION`/`EXPLOSION_RADIUS`/`EXPLOSION_DAMAGE` 与 `projectile_definition`。
- `GameSession` 结算时同时清理爆炸特效；新增 `explosion_aoe_smoke_test.gd`；解析、启动与 42 项快速冒烟、120 秒 soak 通过。

### T17 火焰持续伤害与地面火坑（2026-09-25）

- 新增可配 `DamageOverTimeEffect` 与 `StatusEffectComponent`：DoT 按 tick 间隔结算、同 ID 刷新不叠层、带 `dot` 标签不反伤/不吸血/不暴击（D14）。
- 新增可配 `GroundDamageAreaDefinition` 与 `GroundDamageArea`：独立地面区域按 tick 对范围内敌人结算，复用去重查询，来源离树后继续到自身时长结束。
- `ProjectileDefinition` 新增 `damage_over_time` 与 `ground_area`；`ProjectileBase` 命中后挂 DoT 并生成火坑，与爆炸能力分离。
- 新增“火焰法术”质变及“烈燃（+20% 火焰伤害）”“余烬（火坑时长 +25%）”专属升级；`UpgradeDefinition` 新增 `FLAME`/`AREA_DURATION`，控制器新增地面持续时间倍率。
- `ActorBase` 自动挂载状态组件并在初始化/死亡时清空；`GameSession` 结算清理火坑。
- 修复 T16 之前既有的 `bow_multishot` 首帧自动发射弹体计数抖动（仅测试）；新增 `flame_dot_smoke_test.gd`；解析、启动与 43 项快速冒烟、120 秒 soak 通过。

### T18 威能分支（2026-09-25）

- D15 定案：“射速/攻击间隔”是同一冷却参数，单武器射程倍率与角色级全武器射程相乘，冷却有全局下限。
- `WeaponRuntimeModifier` 由 RefCounted 改为可导出 Resource，新增 `range_multiplier`，支持升级资源引用捆绑修正。
- 新增“威能法术”质变（伤害 ×1.4、冷却 ×0.8、射程 ×1.25）及“崩解/疾涌/远震”专属升级，各自 3 级独立上限，并接入升级池。
- 新增 `staff_might_smoke_test.gd`；解析、启动与 44 项快速冒烟、120 秒 soak 通过。

### T19 寒冰减速/冻结/分裂（2026-09-25）

- 新增可配 `MovementSlowEffect`/`FreezeEffect`，`StatusEffectComponent` 支持减速与冻结（同 ID 刷新不叠层，冻结移速为 0，控制免疫拒绝）。
- `EnemyDefinition` 新增 `control_immune`，Boss 默认免疫控制；`EnemyActor` 追踪速度乘以状态移速倍率，死亡/重开清理。
- 冰枪（穿透 3、冰缓、冻结）命中时左右对称分裂小冰枪，小冰枪不再分裂（上下文与资源双层防递归）；新增“寒冰法术”质变与穿刺/冰封/裂冰专属升级并接入升级池。
- 新增 `ice_slow_smoke_test.gd`、`ice_freeze_smoke_test.gd`、`ice_split_smoke_test.gd`；解析、启动与 47 项快速冒烟、120 秒 soak 通过。

### T20 附魔箭与法杖分支联动（2026-09-25）

- 新增 `ENCHANT_ARROW` 与 `required_equipment_id`/`required_equipment_branch_id`，`UpgradeSystem.can_offer` 支持按前置装备分支过滤（D17）。
- 四张附魔箭质变卡共享 `branch_id=enchant`，需持弓、弓基础满级且法杖已质变到对应分支；效果映射为爆炸/DoT+火坑/减速+冻结/威能捆绑，数值独立。
- 新增四种附魔箭 Resource 与威能箭独立捆绑修正；D08 快照继承（当前规则与实时等价）。
- 修复 `staff_charge_smoke_test` 首帧弹体计数抖动（仅测试）；新增 `enchant_arrow_smoke_test.gd`；解析、启动与 48 项快速冒烟、120 秒 soak 通过。

### T21 反伤刺甲（2026-09-25）

- 新增可配 `ThornArmorDefinition` 与 `ThornAuraComponent`：刺圈按周期对范围内敌人结算带 `reflect` 标签的伤害，受击返还由统一伤害管线按实际扣血比例处理（D18）。
- 新增“反伤刺甲”质变及“扩刺（范围 +20%/级）”“锐刺（返还 +10%/级）”专属升级，并接入升级池；玩家重新初始化清空刺圈与返还。
- 刺圈不会触发二次反伤，零伤害/闪避/免疫不返还。
- 新增 `thorn_armor_smoke_test.gd`；解析、启动与 49 项快速冒烟、120 秒 soak 通过。

### T22 骑士盔甲（2026-09-25）

- 新增可配 `KnightArmorDefinition`：固定减伤作为额外防御进入统一伤害管线，完全免伤作为免疫概率并严格受 `CombatRules.max_immune_chance` 钳制（D19）。
- 新增“骑士盔甲”质变及“坚壁（固定减伤 +3/级）”“圣佑（免伤 +5%/级，受上限钳制）”专属升级并接入升级池；与反伤刺甲互斥。
- `ActorBase` 新增 `set_immune_chance()`；玩家初始化清空免疫与骑士减伤。
- 新增 `knight_armor_smoke_test.gd`；解析、启动与 50 项快速冒烟、120 秒 soak 通过。

### T23 狂战盔甲（2026-09-25）

- 新增可配 `BerserkArmorDefinition` 与 `BerserkDrainComponent`：周期失血绕过防御、默认不致死（D20）。
- 玩家动态提供额外吸血（基础 + 半血以下加成），武器生成弹体时读取并钳制；`ActorBase` 新增一次免死标记与统一致命拦截，DoT 同样适用、每局一次。
- 新增“狂战盔甲”质变及“忍痛/嗜血/不屈”三档专属升级并接入升级池；与反伤刺甲、骑士盔甲互斥。
- 新增 `berserk_armor_smoke_test.gd`；解析、启动与 51 项快速冒烟、120 秒 soak 通过。

### T24 头盔、手套与科技分支（2026-09-25）

- `ArmorDefinition` 新增冷却缩短与全武器射程加成及按等级成长；玩家汇总后由武器读取，不写共享 `.tres`（D21）。
- 新增基础头盔（小防御、无移速惩罚）与基础手套（防御 + 冷却缩短 + 射程）及其获取/强化卡，并加入目录。
- 新增科技战甲/头盔/手套质变：单件提供每秒经验与宝石经验倍率，统一经玩家入口结算，暂停不计时，宝石单次结算。
- 新增 `helmet_gloves_tech_smoke_test.gd`；解析、启动与 52 项快速冒烟、120 秒 soak 通过。

### T25 科技三件套与发射器（2026-09-25）

- 新增可配 `TechSetDefinition`：三件都选科技质变才激活，状态只在切换时应用/撤销一次（D22、D09）；高移速为可撤销运行时乘数，飞行仅视觉高度变化、不绕过 World 碰撞。
- 新增数据驱动科技发射器与爆炸导弹；`WeaponDefinition` 新增 `TargetMode.RANDOM`，`TargetingService.get_random_target` 从缓存随机取目标，无候选回退基础方向（不每帧搜树）。
- 激光按用户确认留作后续可配置分支，本任务不实现。
- 新增 `tech_set_smoke_test.gd`；解析、启动与 53 项快速冒烟、120 秒 soak 通过。

### T26 金币掉落与一次性结算（2026-09-25）

- 新增可配 `EconomyRules`（掉率 15%、每次 1 金、结算每击杀 2 金）与金币拾取物 `CoinPickup`，原子结算一次（D23、D10）。
- `GameResult` 新增已拾取/击退/总金币明细；结算只生成一次，重开余额归零、地面金币清空；金币暂存内存，持久化留待 T27。
- 结算面板与局内装备栏显示金币。
- 新增 `coin_economy_smoke_test.gd`；解析、启动与 54 项快速冒烟、120 秒 soak 通过。

### T27 版本化存档与安全读写（2026-09-25）

- 新增 `Profile`（只含标量与稳定 ID）与 `ProfileStore`：读档校验类型/范围、丢弃未知 ID、版本迁移；写入采用临时文件+校验+备份+替换，失败保留旧档（D24）。
- `GameEntry` 启动加载档案、结算累加金币并写档，写入失败时主菜单显示状态。
- 新增 `profile_store_smoke_test.gd`；修复 T26 掉金导致的 `experience_flow` 拾取计数抖动（仅测试）；解析、启动与 55 项快速冒烟、120 秒 soak 通过。

### 新增战斗美术素材接入（2026-09-25，跨 T16–T26）

- 接入外部生成的 84 个透明 PNG：长弓/法杖/科技发射器、箭与四款附魔箭、法球/爆炸法球/火焰弹/冰枪/小冰枪/导弹、爆炸/火坑/冻结/刺圈特效、金币，以及法杖/盔甲/头盔/手套/附魔箭/属性/成长图标。
- 新增生成脚本 `tools/build_combat_visual_resources.py`（19 个 SpriteFrames）与 `tools/wire_combat_visuals.py`（批量接入弹体帧与图标）；`ExplosionDefinition`/`GroundDamageAreaDefinition`/`FreezeEffect`/`ThornArmorDefinition` 的序列帧与升级卡图标生效，无素材时仍回退占位。
- `WeaponDefinition` 新增可配置 `visual_scale`（迁移原控制器硬编码的手持缩放）；按实拍结果调整弹体显示比例。
- 图形模式实拍证据：`art_review/v2_new_combat_art_preview.png`、`v2_asset_sheet_preview.png`；解析、启动与 55 项快速冒烟、120 秒 soak 通过。

### T28 升级选项刷新次数（2026-09-25）

- 每局刷新次数 = `GameSession.base_refresh_count`（默认 1）+ `Profile.refresh_bonus`，由 GameEntry 开局注入（D25）。
- `UpgradeSystem` 新增刷新接口：消耗一次并优先换出不同可用卡，不自动应用、不改变已选层数；次数跨升级保留、重开归零。
- `LevelUpPanel` 卡列表下方新增“刷新（剩余 N）”按钮，按状态启用/禁用。
- 新增 `upgrade_refresh_smoke_test.gd`；解析、启动与 56 项快速冒烟、120 秒 soak 通过。

### 四宠庭院与武器扩展（2026-09-20）

- 新增虎妞、黑豹、小四、小七四帧动画；虎妞二次修订为小眼绷脸，黑豹引用原图。
- 新增庭院背景、中文命名原创音频，全中文升级/结算/提示、暂停静音、Boss 血条和武器栏。
- 修复初始武器零扩散造成的多弹重叠，弹数与穿透独立升级。
- 新增飞叶刃、回旋骨棒、环绕铃铛及动画，5 项通用强化、3 项专属强化和 3 项获取选项；新武器继承旧通用强化，不回写共享资源。
- 27 项快速烟雾和 120 秒生成压力测试通过；详细接口、命令、图形验收与限制见 `docs/PET_PLAYTEST.md`。

### 架构与基线文档（2026-09-20）

- 新增 `docs/ARCHITECTURE.md`：记录当前实现的架构基线，包括目录、场景树、数据模型、公共接口与信号、伤害/经验/难度/结算数据流、碰撞层与扩展点。
- 新增 `docs/BASELINE.md`：冻结 `baseline-1.0`（提交 `447a787`），包含需求追踪、资源清单、26 项冒烟测试矩阵、与规范的结构偏差、已知问题及基线变更流程。
- `README.md` 增加架构与基线文档索引、基线与提交约定。
- 统一提交信息为中文，类型前缀保留英文小写（同步更新 `AGENTS.md` 与 `PROJECT_SPEC.md` 第 13.2 节）。
- 补齐 `TASKS.md` 阶段 0 复选框与验证记录。

### 跨平台启动文档（2026-09-20）

- `README.md` 补充 macOS 与 Windows 命令行启动示例，明确示例路径需替换为本机实际的 Godot 可执行文件。
- 同步更新 `docs/ARCHITECTURE.md` 验证入口与 `docs/BASELINE.md` 回归命令为跨平台写法，并提示 Windows 使用 `*_console.exe` 查看输出。

### 可爱像素美术（2026-09-20）

- 新增两张原创透明 PNG 图集及八个 SpriteFrames 配置，覆盖玩家、两种敌人、Boss、武器、子弹、经验水晶与预留命中特效。
- ActorSprite 根据速度切换四帧移动动画、待机和左右朝向，保留原有受伤反馈组件。
- WeaponDefinition 新增可选 visual_frames；WeaponController 从 Node 扩展为 Node2D，子节点拥有独立武器动画，随发射信号流程触发并随控制器清理。
- 新增像素动画专项测试，验证帧推进、朝向、待机恢复、裁切边界与武器动画；通过移动、追踪、受伤、武器、弹体、升级、Boss 和三次重开回归。
- 使用 Godot 图形模式渲染截图，人工检查透明背景、素材比例和裁切；素材来源及完整提示词见 assets/sprites/cute_pixel/README.md。

### Added

- 初始化 Godot 4.7.1 项目配置与标准目录。
- 配置 1280 × 720 视口、`canvas_items` 2D 拉伸和保持宽高比。
- 配置 WASD 与方向键移动动作。
- 新增可直接启动的主场景和最小 `GameSession` 场景。
- 新增本地 SVG 占位资源和 Godot 项目忽略规则。
- 新增 InputMap 烟雾检查，验证 WASD 和方向键绑定。
- 新增数据驱动的 `CharacterDefinition` 和默认玩家 Resource。
- 新增玩家场景、八方向归一化移动和 Camera2D 跟随。
- 新增具有可视网格和 World 物理边界的基础场地。
- 新增 P1-02 烟雾检查，验证数据注入、移动速度、摄像机和边界碰撞。
- 新增数据驱动的 `EnemyDefinition` 和基础敌人 Resource。
- 新增通用 `EnemyActor`，通过注入的玩家引用进行直线追踪。
- 玩家离开场景树时，敌人会立即停止并关闭物理处理。
- 配置 PlayerBody 与 EnemyBody 识别层；实体运动只阻挡 World，战斗接触由 Hitbox/Hurtbox 检测。
- 新增 P1-03 烟雾检查，验证配置、目标注入、追踪和目标失效处理。
- 新增数据驱动的 `EnemySpawnSettings`，配置生成间隔、数量上限和生成环带。
- 新增 `EnemySpawner`，在玩家周围、当前摄像机视野外且场地内生成敌人。
- 默认每秒生成一个基础敌人，并将场上敌人数限制为 30。
- 新增 P1-04 专项烟雾测试和 120 秒稳定性测试。
- 新增统一 `DamageEvent`，保留伤害来源、位置、标签、暴击和击退扩展字段。
- 新增可复用 `HealthComponent`、`HitboxComponent` 与 `HurtboxComponent` 场景和脚本。
- 新增 `ActorBase`，由玩家和敌人共享生命、受伤与单次死亡信号接口。
- 基础敌人的 `ContactHitbox` 从 `EnemyDefinition.contact_damage` 初始化，并通过物理重叠传递伤害事件。
- 新增 P2-01 专项烟雾测试，覆盖生命边界、治疗、重置、真实接触、共享组件、Resource 隔离和单次死亡。
- 新增 `TargetingService`，按 0.1 秒固定间隔缓存注入容器中的有效 Actor。
- 新增带范围和阵营过滤的最近目标查询接口，查询过程不搜索场景树。
- `GameSession` 组合并初始化索敌服务，供后续 WeaponController 通过明确引用使用。
- 新增 P2-02 专项烟雾测试，覆盖最近目标、范围、刷新间隔、死亡、释放和容器离树。
- 新增数据驱动的 `WeaponDefinition` 与默认 `starter_weapon.tres`，默认约一秒冷却和 900 像素射程。
- `CharacterDefinition.starting_weapons` 收窄为强类型数组，默认玩家通过配置获得起始武器。
- 新增 `WeaponController` 与 `WeaponRuntimeModifier`，支持发射请求、独立冷却、单局修正、重置和依赖失效处理。
- 玩家可组合多个武器控制器，并通过注入的 `TargetingService` 自动请求攻击射程内最近敌人。
- 新增三个 P2-03 烟雾测试，分别覆盖武器数据、控制器运行时逻辑和自动索敌集成。
- 新增数据驱动的 `ProjectileDefinition` 和默认 `basic_projectile.tres`。
- 新增 `ProjectileSpawnContext`，独立携带发射者、阵营、位置、方向、伤害倍率、目标和武器 ID。
- 新增 `ProjectileBase` 场景与脚本，实现直线移动、DamageEvent、寿命、穿透、同帧去重、停用和重置。
- `WeaponController` 根据运行时弹数和扩散配置创建实际子弹，并通过 `projectile_spawned` 发布实例。
- 新增三个 P2-04 烟雾测试，覆盖子弹数据、基础行为以及武器物理命中集成。
- `CharacterDefinition` 新增角色基础攻击范围；`WeaponController` 将其与武器自身射程取较小值作为有效索敌范围。
- 新增攻击范围专项烟雾测试，覆盖角色限制、武器限制、实际自动索敌边界和共享 Resource 隔离。
- 新增可复用 `PickupComponent`，拾取半径由 `CharacterDefinition.pickup_radius` 初始化。
- 新增 `ExperienceGem` 场景与一次性结算接口，复用本地经验宝石占位资源。
- `GameSession` 监听敌人死亡并按 `EnemyDefinition.experience_value` 在死亡位置生成经验宝石。
- `PlayerActor` 保存本局累计经验并发布 `experience_changed` 信号，供后续 HUD 和等级系统监听。
- 新增快速子弹 Resource，验证第二种子弹无需修改玩家或 `ProjectileBase` 代码。
- 新增两个 P2-05 烟雾测试，覆盖真实拾取范围、单次结算、死亡掉落、信号和连续 100 次击杀拾取。
- 新增玩家等级模型、集中经验阈值、连续升级队列和等级/经验进度信号。
- 新增数据驱动的 `UpgradeDefinition`、六种升级 Resource 与 `UpgradeSystem`，支持无重复三选一、最大层数过滤和权重字段预留。
- 新增 HUD 生命、等级和经验条，以及暂停态可操作的 `LevelUpPanel`。
- `GameSession` 串行处理连续升级选择并统一管理暂停恢复；UI 不直接修改玩家或武器状态。
- 新增伤害、攻速、弹数、移速、最大生命和治疗的单局运行时强化，不回写共享 Resource。
- 新增三个阶段三烟雾测试，覆盖等级溢出、升级筛选、全部属性效果、暂停 UI、防重复提交和连续升级。
- 新增可编辑的角色 `camera_zoom` 与单局 `ui_scale`，默认扩大玩家视野并放大 HUD、升级界面；屏幕外刷怪按实际摄像机范围同步计算。
- 新增 `RunDefinition`、`DifficultyStage` 和 `DifficultyDirector`，以四个时间阶段驱动生成间隔、批量、敌人池、实例倍率和动态数量上限。
- 新增快速敌人和 Boss 的数据与场景，复用通用敌人行为及生命、受击、接触伤害组件。
- `GameSession` 新增 5 分钟权威倒计时、击杀统计、Boss 单次生成、胜负结算和重新开始状态机。
- HUD 新增剩余时间显示，新增暂停态 `EndPanel` 显示胜负、存活时间、等级、击杀及重开按钮。
- 新增阶段四难度、密度、Boss 胜利、失败结算和连续三次重开烟雾测试。
- 新增可复用 `DamageFeedbackComponent`，玩家、基础敌人、快速敌人和 Boss 受伤时统一播放红色闪烁、缩放位移和短促合成音效。
- 新增“幸运射击”“子弹吸血”和“拾取范围”三种数据驱动升级，分别提供每层 15% 额外子弹概率、3% 实际伤害吸血和 25% 拾取半径增长。
- `ProjectileSpawnContext` 与 `WeaponRuntimeModifier` 新增吸血和额外子弹概率运行时字段，不修改武器、子弹或角色共享 Resource。
- 新增受伤反馈和进阶升级专项烟雾测试。
- 新增“追加射击”升级，每层增加 15% 概率在当前冷却周期内延迟追加一颗子弹，且不会递归触发自身。

### Fixed

- 敌人改为设置生成位置后再加入场景树，避免原点短暂碰撞配对导致玩家被物理恢复到远处。
- 接触 Hitbox 使用略大于实体碰撞体的范围，避免贴边抖动在一次持续接触中重复触发伤害。
- P1-04 稳定性测试使用独立运行时生命值隔离 P2 接触伤害，保持共享 `.tres` 不变。
- 玩家与敌人改用 Survivor-like 常见的非实体阻挡方案，并切换为俯视角 `MOTION_MODE_FLOATING`，避免接触后持续贴边锁定玩家。
- 索敌查询先验证缓存对象实例再转换为 `ActorBase`，避免已释放强类型对象产生调用错误，并同步清除失效缓存。
- 修正默认角色 `.tres` 中起始武器强类型数组的脚本类型引用，避免 Resource 加载转换错误。
- 子弹从 Area 回调停用时延迟修改 monitoring，避免物理查询期间改变碰撞状态。
- 发射者离树后清空子弹上下文的来源引用，保留既有飞行和阵营信息，避免后续命中访问失效对象。
- P1/P2 专项测试显式隔离自动武器，避免子弹提前击杀验收敌人导致测试相互干扰。
- 经验宝石延迟加入场景树，避免敌人在 Area 查询回调内死亡时于物理服务器刷新阶段启用新碰撞形状。
- P2-05 压力测试在阶段三接入后自动提交升级选择，避免暂停阻断原有 100 次拾取回归。
- EnemySpawner 先建立基础运行时敌人池再校验依赖，避免阶段四接管生成配置时初始化失败。
- P1-04 soak 固定隔离动态难度，并新增阶段四高密度动态上限测试，区分规则增长与节点泄漏。
- 子弹吸血按目标实际损失生命结算，避免击杀低生命目标时按理论伤害过量治疗。
- 受伤反馈组件离树时主动停止音频并断开生命组件信号；涉及致命伤害的无头测试等待短音效结束，避免进程退出时遗留音频句柄。
- 修正攻击敌人时也会播放受伤音效的问题：敌人继续显示受伤视觉反馈，但只有玩家受伤会播放音效。

### Verified

- 阶段一 P1-01 至 P1-04 通过代码审查、Godot 4.7.1 解析与启动检查、四项功能烟雾测试和 120 秒稳定性测试。
- P2-01 通过 Godot 4.7.1 解析、300 帧启动、生命与伤害专项测试及阶段一快速回归；玩家和敌人死亡信号均验证为单次触发。
- P2-02 通过 Godot 4.7.1 解析、300 帧启动、索敌专项测试及 P1/P2-01 快速回归；死亡、释放和容器离树生命周期均安全通过。
- P2-03 通过分步专项测试、Godot 4.7.1 解析、300 帧启动及 P1 至 P2-02 快速回归；无目标、射程、冷却、多控制器和 Resource 隔离均验证通过。
- P2-04 通过分步专项测试、Godot 4.7.1 解析、启动运行及 P1 至 P2-03 快速回归；移动、伤害、寿命、穿透、同帧去重、清理、弹数和扩散均验证通过。
- 攻击范围前置设计通过解析和专项测试；不同角色与不同武器可独立限制自动索敌距离，且不修改共享配置。
- P2-05 通过解析、300 帧启动、经验专项测试、连续 100 次击杀拾取及全部快速回归；阶段二所有验收项完成。
- 阶段三通过 Godot 4.7.1 解析、300 帧启动、三个专项测试及阶段一至阶段二全部快速回归；等级、升级选择、暂停流程和六类属性修正均通过。
- 阶段四通过 Godot 4.7.1 解析、300 帧启动、22 项快速回归、120 秒基础生成 soak 和 140 敌人高密度测试；完整胜利、失败及连续三次重开流程通过。
- 受伤反馈与进阶升级扩展通过 Godot 4.7.1 解析、300 帧启动和全部 24 项快速烟雾测试；视觉恢复、共享音频流、100% 概率额外子弹、实际伤害吸血、拾取碰撞半径及 Resource 隔离均通过。
- 玩家专属受伤音效和追加射击扩展通过专项测试及全部 24 项快速回归；失败 0、对象泄漏 0。
