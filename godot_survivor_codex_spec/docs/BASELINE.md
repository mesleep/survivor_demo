# 项目基线（Baseline）

> 本文档冻结当前仓库在某一提交上的**可交付状态**：需求追踪、资源清单、测试覆盖、已知偏差与限制。
> 它是后续开发的比较基准；修改实现前应先阅读本文档与 `docs/ARCHITECTURE.md`。
> 本文档只读，不修改任何代码。

## 基线信息

| 项目 | 内容 |
|---|---|
| 基线版本 | `baseline-1.0` |
| 对应提交 | `447a78786dcb3458a295e3159041183012768921` |
| 提交说明 | `feat: add cute pixel art and animated character weapons` |
| 提交时间 | 2026-09-20 20:10:30 +0800 |
| 生成日期 | 2026-09-20 |
| 基线范围 | 阶段 0–4 全部功能 + 受伤反馈/进阶升级扩展 + 像素美术 |
| 主场景 | `res://scenes/bootstrap/main.tscn` |
| 目标平台 | macOS（首要），Windows 曾用于 headless 验证 |

**状态定义**：`已实现` = 代码/资源存在且被验收记录或测试覆盖；`部分` = 存在但未完全满足原文；`未实现` = 不存在。

---

## 1. 总体状态

四阶段核心循环已闭环，可完整游玩一局（5 分钟 → Boss → 胜负结算 → 重开）：

```text
移动 → 自动索敌攻击 → 击杀掉落经验 → 拾取 → 升级三选一 → 敌人随时间增强
→ 5:00 Boss → 胜利/失败结算 → 重新开始
```

- 代码解析与主场景启动通过（历史验证记录）。
- 冒烟测试共 **26 个**（`tests/smoke/*.gd`），以 `--script` 方式运行并返回退出码。
- 无 Autoload，单局状态全部在 `GameSession` 子树内。
- 配置数据驱动：角色/敌人/武器/子弹/升级/波次均为自定义 `Resource`。

---

## 2. 需求追踪（`PROJECT_SPEC.md` → 实现 → 验证）

### 阶段 0：准备

| 任务 | 状态 | 证据 |
|---|---|---|
| P0-01 Godot 4.7.1 | 已实现 | `project.godot` `config/features=("4.7",...)`；TASKS 阶段一记录 |
| P0-02 Git 仓库 | 已实现 | 仓库存在，`main` 有 8 个提交 |
| P0-03 文档入库 | 已实现 | `AGENTS.md`、`docs/PROJECT_SPEC.md` 存在 |
| P0-04 可读项目 | 已实现 | 本次只读分析完成 |

> `TASKS.md` 中 P0-01..04 复选框仍为空，与实际状态不一致（见第 6 节）。

### 阶段 1：基础运行

| 任务 | 状态 | 实现 | 测试 |
|---|---|---|---|
| P1-01 项目初始化 | 已实现 | `project.godot`、`main.tscn`、目录、`.gitignore`、占位 SVG | `input_map_smoke_test.gd` |
| P1-02 玩家移动 | 已实现 | `player_actor.gd`、`player.tscn`、`arena.tscn` | `player_movement_smoke_test.gd` |
| P1-03 敌人追踪 | 已实现 | `enemy_actor.gd`、`enemy_basic.*` | `enemy_tracking_smoke_test.gd` |
| P1-04 敌人生成 | 已实现 | `enemy_spawner.gd`、`phase_one_spawn.tres` | `enemy_spawner_smoke_test.gd`、`enemy_spawner_soak_test.gd` |

### 阶段 2：战斗循环

| 任务 | 状态 | 实现 | 测试 |
|---|---|---|---|
| P2-01 生命与伤害 | 已实现 | `DamageEvent`、`HealthComponent`、`Hitbox`/`Hurtbox` | `health_damage_smoke_test.gd` |
| P2-02 索敌 | 已实现 | `TargetingService`（0.1s 刷新） | `targeting_service_smoke_test.gd` |
| P2-03 自动武器 | 已实现 | `WeaponDefinition`、`WeaponController`、`WeaponRuntimeModifier` | `weapon_definition/controller`、`automatic_weapon`、`attack_range` |
| P2-04 子弹 | 已实现 | `ProjectileDefinition`、`ProjectileSpawnContext`、`ProjectileBase` | `projectile_definition/base`、`projectile_weapon_integration` |
| P2-05 经验 | 已实现 | `PickupComponent`、`ExperienceGem`、`GameSession.spawn_experience_gem` | `experience_gem`、`experience_flow` |

攻击范围两层约束（角色 `base_attack_range` × 武器 `target_range` 取小）已落地于 `WeaponController.get_effective_target_range()`。

### 阶段 3：成长系统

| 任务 | 状态 | 实现 | 测试 |
|---|---|---|---|
| P3-01 等级与经验 | 已实现 | `PlayerActor` 等级模型、`get_required_experience`、`leveled_up` | `level_progression_smoke_test.gd` |
| P3-02 升级系统 | 已实现 | `UpgradeDefinition`、`UpgradeSystem` | `upgrade_system_smoke_test.gd` |
| P3-03 升级 UI | 已实现 | `LevelUpPanel`、`GameSession` 暂停流程 | `level_up_flow_smoke_test.gd` |
| P3-04 属性修正 | 已实现 | `PlayerActor.apply_upgrade` + 运行时对象 | `advanced_upgrade_smoke_test.gd` 等 |

经验曲线：`required_xp(level) = 5 + level × 3`，集中于 `PlayerActor.get_required_experience()`。

### 阶段 4：完整 Demo

| 任务 | 状态 | 实现 | 测试 |
|---|---|---|---|
| P4-01 游戏计时 | 已实现 | `GameSession.elapsed_seconds`、HUD 倒计时 | `difficulty_*`、`ending_restart` |
| P4-02 难度导演 | 已实现 | `DifficultyDirector`、`DifficultyStage` | `difficulty_director`、`difficulty_density` |
| P4-03 两种普通敌人 | 已实现 | `enemy_basic`、`enemy_fast` 共用 `EnemyActor` | 同上、`pixel_art` |
| P4-04 Boss | 已实现 | `boss.tscn`、`boss_default.tres`、单次生成 | `boss_victory_smoke_test.gd` |
| P4-05 结算与重开 | 已实现 | `EndPanel`、`GameResult`、`restart_run` | `ending_restart_smoke_test.gd` |

### 阶段四后扩展

| 需求 | 状态 | 实现 | 测试 |
|---|---|---|---|
| 受伤视觉反馈（全员） | 已实现 | `DamageFeedbackComponent` | `damage_feedback_smoke_test.gd` |
| 受伤音效（仅玩家） | 已实现 | `play_sound` 配置 + 运行时合成音频 | `damage_feedback_smoke_test.gd` |
| 幸运射击（+15% 额外弹） | 已实现 | `BONUS_PROJECTILE_CHANCE` | `advanced_upgrade_smoke_test.gd` |
| 子弹吸血（实际伤害 3%） | 已实现 | `PROJECTILE_LIFESTEAL` | 同上 |
| 拾取范围 +25%/层 | 已实现 | `PICKUP_RANGE_MULTIPLIER` | 同上 |
| 追加射击（+15% 延迟弹） | 已实现 | `REPEAT_SHOT_CHANCE` | 同上 |
| 可爱像素美术 | 已实现 | `assets/sprites/cute_pixel/`、`data/visuals/*.tres`、`ActorSprite` | `pixel_art_smoke_test.gd` |

---

## 3. 数据资源清单

### 3.1 Resource 类型（`class_name`）

| 类 | 文件 | 用途 |
|---|---|---|
| `CharacterDefinition` | `data/characters/character_definition.gd` | 角色基础属性 |
| `EnemyDefinition` | `data/enemies/enemy_definition.gd` | 敌人属性 |
| `WeaponDefinition` | `data/weapons/weapon_definition.gd` | 武器参数 |
| `ProjectileDefinition` | `data/projectiles/projectile_definition.gd` | 子弹参数 |
| `UpgradeDefinition` | `data/upgrades/upgrade_definition.gd` | 升级选项 |
| `RunDefinition` | `data/waves/run_definition.gd` | 单局流程 |
| `DifficultyStage` | `data/waves/difficulty_stage.gd` | 分段难度 |
| `EnemySpawnSettings` | `data/waves/enemy_spawn_settings.gd` | 阶段一单段生成配置 |

### 3.2 `.tres` 实例

- 角色：`player_default.tres`
- 敌人：`enemy_basic.tres`、`enemy_fast.tres`、`boss_default.tres`
- 武器：`starter_weapon.tres`
- 子弹：`basic_projectile.tres`、`fast_projectile.tres`（第二种子弹，验证无需改玩家代码）
- 升级：10 个（见 `ARCHITECTURE.md` §4.5）
- 波次：`phase_one_spawn.tres`、`default_run.tres`
- 表现：`player/slime/bat/boss/wand/bolt/gem/impact_frames.tres`（8 个 `SpriteFrames`）

数值明细见 `docs/ARCHITECTURE.md` 第 4 节。

---

## 4. 验证与测试基线

### 4.1 冒烟测试清单（26）

| # | 测试脚本 | 覆盖 |
|---:|---|---|
| 1 | `input_map_smoke_test.gd` | WASD/方向键绑定 |
| 2 | `player_movement_smoke_test.gd` | 归一化移动、Camera、边界 |
| 3 | `enemy_tracking_smoke_test.gd` | 追踪与目标失效停止 |
| 4 | `enemy_spawner_smoke_test.gd` | 离屏生成、间隔、上限 |
| 5 | `enemy_spawner_soak_test.gd` | 120 秒稳定性（固定上限 30） |
| 6 | `health_damage_smoke_test.gd` | 生命边界、单次死亡、接触伤害 |
| 7 | `targeting_service_smoke_test.gd` | 最近目标、范围、刷新、失效过滤 |
| 8 | `weapon_definition_smoke_test.gd` | 武器 Resource |
| 9 | `weapon_controller_smoke_test.gd` | 冷却、修正、重置、依赖失效 |
| 10 | `automatic_weapon_smoke_test.gd` | 自动索敌发射 |
| 11 | `attack_range_smoke_test.gd` | 角色/武器有效射程取小 |
| 12 | `projectile_definition_smoke_test.gd` | 子弹 Resource |
| 13 | `projectile_base_smoke_test.gd` | 移动、伤害、寿命、穿透、去重 |
| 14 | `projectile_weapon_integration_smoke_test.gd` | 武器→子弹→命中击杀 |
| 15 | `experience_gem_smoke_test.gd` | 单次结算、Resource 隔离 |
| 16 | `experience_flow_smoke_test.gd` | 死亡掉落、拾取、连续 100 次 |
| 17 | `level_progression_smoke_test.gd` | 阈值、跨级、待选择队列 |
| 18 | `upgrade_system_smoke_test.gd` | 无重复、层数过滤、重复提交拒绝 |
| 19 | `level_up_flow_smoke_test.gd` | 暂停 UI、选择恢复、连续升级 |
| 20 | `difficulty_director_smoke_test.gd` | 四段难度切换 |
| 21 | `difficulty_density_smoke_test.gd` | 动态上限高密度压力 |
| 22 | `boss_victory_smoke_test.gd` | Boss 单次生成、死亡胜利 |
| 23 | `ending_restart_smoke_test.gd` | 失败结算、连续三次重开无残留 |
| 24 | `damage_feedback_smoke_test.gd` | 受伤视觉/音效、玩家专属音效 |
| 25 | `advanced_upgrade_smoke_test.gd` | 幸运射击/吸血/拾取/追加射击 |
| 26 | `pixel_art_smoke_test.gd` | 四帧动画、朝向、图集边界、武器动画 |

### 4.2 建议回归命令

先按平台设置 Godot 路径（替换为本机实际路径）：

```bash
# macOS
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"

# Windows（PowerShell）
# $GODOT = "C:\Godot\Godot_v4.7.1-stable_win64_console.exe"
```

```bash
"$GODOT" --headless --path . --editor --quit
"$GODOT" --headless --path . --quit-after 300
for t in tests/smoke/*_smoke_test.gd; do
  "$GODOT" --headless --path . --script "res://$t" || echo "FAILED: $t"
done
```

`enemy_spawner_soak_test.gd` 为 120 秒测试，可按需单独执行。Windows 下建议使用 `*_console.exe` 以便查看输出。

### 4.3 验证缺口

- **未执行** GUI 窗口完整 5 分钟人工游玩（历史记录为 headless 验收）。
- 最终验收清单中「macOS 上稳定运行」仍未勾选。
- 音频、手感、动画节奏的**主观**验收未执行。
- `TASKS.md` 记录 Windows headless 会报系统根证书库读取错误（不影响退出码）。

---

## 5. 与 `PROJECT_SPEC.md` 的结构偏差（实际 vs 计划）

| 计划项 | 实际 | 说明 |
|---|---|---|
| `scripts/core/spawn_context.gd` | `scripts/combat/projectile_spawn_context.gd` | 更贴近战斗职责 |
| `scripts/systems/experience_system.gd` | 未创建 | 经验逻辑在 `PlayerActor` 与 `GameSession` |
| `scripts/combat/targeting_service.gd` | `scripts/systems/targeting_service.gd` | 归入系统层 |
| `scenes/actors/common/actor_base.tscn` | 未创建 | `ActorBase` 仅脚本继承，无独立场景 |
| `tests/smoke/*.tscn`、`tests/README.md` | 未创建 | 测试改为 `SceneTree` `.gd` 脚本 |
| `tools/validate_project.sh`、`run_game.sh` | 未创建（`tools/` 为空） | 尚无自动化脚本 |
| `assets/audio/`、`fonts/`、`ui/` | 未创建 | 使用运行时合成音与默认字体 |
| `assets/sprites/` | 有 `cute_pixel/` | 新增原创像素美术 |
| `data/visuals/` | 新增 | 8 个 `SpriteFrames` 表现资源 |
| 对象池 | 未实现 | 仅保留 `reset_runtime_state()` 等预留接口 |
| `UpgradeDefinition.weight` | 已预留未使用 | 选取仍为均匀随机 |

除以上结构性差异外，四阶段功能与验收标准均已覆盖。

---

## 6. 已知问题与技术债

### 6.1 文档一致性

- `TASKS.md` P3-01..P4-05 的勾选项未逐条附独立验证记录（合并在一段记录中）。
- 阶段 0 复选框已在补记验证后与事实一致。
- 基线对应的代码状态为提交 `447a787`；随后新增的架构/基线文档、README 索引与中文提交约定为纯文档提交，不改变被基线的代码行为。

### 6.2 实现限制

- 敌人接触伤害目前依赖持续重叠的 Area 事件；快速移动或高帧率下的极端穿透未专门处理。
- 没有伤害浮字、击杀统计 UI（击杀数仅用于结算）。
- 经验宝石不做合并/吸附，密集掉落可能产生较多节点。
- 未实现对象池；长时间高密度运行的对象创建压力未在目标机评测。
- 追加射击使用 `create_timer` 协程 + `generation` 防重开残留，重开流程正确性已测，但协程数量随概率增长。
- 无正式音频素材，命中音为运行时合成占位。
- 无手柄、移动端、存档、设置、多语言（按 Spec 属于暂不实现）。

### 6.3 待确认/待办

- `TASKS.md` 最终验收「macOS 上稳定运行」需要在目标机完成一次人工验收后勾选。
- 基线变更后应同步更新 `docs/ARCHITECTURE.md`、`docs/BASELINE.md`、`docs/TASKS.md`、`docs/CHANGELOG.md`。

---

## 7. 基线变更流程（文档驱动）

后续任何改动遵循以下顺序，避免文档与实现漂移：

1. **先改文档**：在 `docs/PROJECT_SPEC.md` 或 `docs/TASKS.md` 中明确本次任务与验收标准。
2. **确认基线**：阅读本文件与 `docs/ARCHITECTURE.md`，判断影响范围（接口、碰撞层、Resource 格式、目录）。
3. **实现最小切片**：保持 `main` 可运行；不修改共享 `.tres` 的运行时状态。
4. **验证**：Godot 解析 + 主场景启动 + 相关冒烟测试；必要时新增测试并登记到本文档第 4 节。
5. **更新记录**：更新 `TASKS.md` 验证记录与 `CHANGELOG.md`。
6. **提交**：一个逻辑变更一个提交，提交信息使用中文，类型前缀保留英文小写（`feat:`/`fix:`/`refactor:`/`docs:`/`test:`）。
7. **必要时应提升基线版本**（`baseline-1.0` → `baseline-1.1`），并更新本文件与 `ARCHITECTURE.md` 的「对应提交」。

以下改动属于**破坏性变更**，必须先说明影响并同步更新所有调用方与文档：

- 输入键位、碰撞层定义、目录规则；
- `initialize()` / `apply_damage()` / `fire()` 等公共接口签名；
- Resource 字段名或类型；
- 主场景路径与单局状态归属。
