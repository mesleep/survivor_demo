# 架构基线（As-Built Architecture）

> 本文档描述**当前仓库真实实现**的架构，而非计划。计划与验收标准见 `docs/PROJECT_SPEC.md`。
> 需求到实现的追踪、测试清单和已知偏差见 `docs/BASELINE.md`。
> 本文档只读，不修改任何脚本、场景或 Resource。

## 文档信息

| 项目 | 内容 |
|---|---|
| 基线版本 | `baseline-1.0` |
| 对应提交 | `447a78786dcb3458a295e3159041183012768921` |
| 对应提交说明 | `feat: add cute pixel art and animated character weapons` |
| 生成日期 | 2026-09-20 |
| 引擎 | Godot 4.7.1 stable，GL Compatibility |
| 语言 | GDScript（尽量静态类型） |
| 入口场景 | `res://scenes/bootstrap/main.tscn` |
| 基准分辨率 | 1280 × 720，`canvas_items` 拉伸 |
| Autoload | 无 |

---

## 1. 系统总览

运行时采用「单一组合根 + 数据驱动 + 组件组合 + 信号解耦」结构。

```text
Main (Node)
└── GameSession (Node2D)          ← 单局组合根，唯一权威状态
    ├── Arena (Node2D)            ← 可视化网格 + World 物理边界
    ├── Actors (Node2D)
    │   ├── Player (PlayerActor)  ← 运行时创建，位置原点
    │   └── Enemies (Node2D)      ← EnemyActor 直接子节点
    ├── Projectiles (Node2D)      ← ProjectileBase 容器
    ├── Pickups (Node2D)          ← ExperienceGem 容器
    ├── Systems (Node)
    │   ├── EnemySpawner
    │   ├── TargetingService
    │   ├── UpgradeSystem
    │   └── DifficultyDirector
    └── CanvasLayer
        ├── HUD
        ├── LevelUpPanel
        └── EndPanel
```

分层职责：

| 层 | 职责 | 代表 |
|---|---|---|
| 数据层 | 只读配置，不保存运行时状态 | `data/**/*.tres` 及对应 `Resource` 脚本 |
| 组件层 | 可复用能力 | `HealthComponent`、`HitboxComponent`、`HurtboxComponent`、`PickupComponent`、`DamageFeedbackComponent`、`WeaponController` |
| Actor 层 | 角色运行时行为 | `ActorBase` → `PlayerActor` / `EnemyActor` |
| 战斗层 | 伤害与子弹 | `DamageEvent`、`ProjectileBase`、`ProjectileSpawnContext`、`WeaponRuntimeModifier` |
| 系统层 | 单局规则与服务 | `EnemySpawner`、`TargetingService`、`DifficultyDirector`、`UpgradeSystem` |
| 表现层 | 只读展示，不持有规则 | `HUD`、`LevelUpPanel`、`EndPanel`、`ActorSprite` |
| 组合层 | 创建、连接、暂停、结算、重开 | `GameSession` |

设计约束（全仓库生效）：

- 单局升级与难度倍率只写入运行时对象，**不回写共享 `.tres`**。
- UI 只监听信号、只提交选择，不直接改玩家/武器内部状态。
- 不在每帧逻辑中做场景树搜索（`get_node`/`find_child`/组查询）；依赖通过 `initialize()` 注入或 `%` 唯一名缓存。
- 战斗实体彼此不产生物理阻挡（仅检测 World），接触伤害由 Area 检测。

---

## 2. 实际目录结构

```text
godot_survivor_codex_spec/
├── project.godot                  # 主场景、1280×720、输入、碰撞层名
├── AGENTS.md / README.md / CODEX_FIRST_PROMPT.md
├── assets/
│   ├── placeholders/              # 6 个占位 SVG（保留）
│   └── sprites/cute_pixel/        # 原创 PNG 图集 + 生成说明
├── data/
│   ├── characters/                # character_definition.gd + player_default.tres
│   ├── enemies/                   # enemy_definition.gd + basic/fast/boss .tres
│   ├── projectiles/               # projectile_definition.gd + basic/fast .tres
│   ├── upgrades/                  # upgrade_definition.gd + 10 个升级 .tres
│   ├── visuals/                   # 8 个 SpriteFrames .tres（表现资源）
│   ├── waves/                     # run_definition / difficulty_stage /
│   │                              #   enemy_spawn_settings + phase_one_spawn、default_run
│   └── weapons/                   # weapon_definition.gd + starter_weapon.tres
├── scenes/
│   ├── bootstrap/main.tscn
│   ├── gameplay/{arena,game_session}.tscn
│   ├── actors/{player/player,enemies/{enemy_basic,enemy_fast,boss}}.tscn
│   ├── combat/projectiles/projectile_base.tscn
│   ├── components/*.tscn          # health/hitbox/hurtbox/pickup/damage_feedback
│   ├── pickups/experience_gem.tscn
│   └── ui/{hud,level_up_panel,end_panel}.tscn
├── scripts/
│   ├── core/                      # game_session / arena / game_result
│   ├── actors/                    # actor_base / player_actor / enemy_actor
│   ├── combat/                    # damage_event / projectile_base /
│   │                              #   projectile_spawn_context / weapon_runtime_modifier
│   ├── components/                # health / hitbox / hurtbox / pickup /
│   │                              #   damage_feedback / weapon_controller
│   ├── systems/                   # enemy_spawner / targeting_service /
│   │                              #   difficulty_director / upgrade_system
│   ├── pickups/experience_gem.gd
│   ├── ui/                        # hud / level_up_panel / end_panel
│   └── visuals/actor_sprite.gd
├── tests/smoke/                   # 26 个 SceneTree 冒烟测试脚本
├── tools/                         # 空目录（规范中的脚本尚未创建）
└── docs/                          # PROJECT_SPEC / TASKS / CHANGELOG / 本文档
```

> 与 `PROJECT_SPEC.md` 第 3 节的目录差异集中记录在 `docs/BASELINE.md` 第 5 节。

---

## 3. 场景树

### 3.1 Player（`scenes/actors/player/player.tscn`）

```text
Player (CharacterBody2D, layer=2 PlayerBody, mask=1 World, FLOATING)
├── Visual (AnimatedSprite2D, ActorSprite)         # scale 0.19，nearest
├── CollisionShape2D (Circle r=24)
├── HealthComponent
├── HurtboxComponent (layer=2, monitorable)
├── PickupComponent (mask=32 Pickup)
├── DamageFeedbackComponent (含 AudioStreamPlayer2D，play_sound=true)
├── WeaponControllers (Node)                       # 运行时挂 WeaponController
└── Camera2D (位置平滑 8.0，limit 由 Arena 边界配置)
```

### 3.2 Enemy / Boss（`enemy_basic.tscn` / `enemy_fast.tscn` / `boss.tscn`）

```text
Enemy (CharacterBody2D, layer=4 EnemyBody, mask=1 World, FLOATING)
├── Visual (AnimatedSprite2D, ActorSprite)
├── CollisionShape2D (basic r=24 / fast r=22 / boss r=44)
├── HealthComponent
├── HurtboxComponent (layer=4)                     # boss 半径 44
├── ContactHitbox (HitboxComponent, layer=16 EnemyAttack, mask=2 PlayerBody)
│                                                    # boss 半径 50
└── DamageFeedbackComponent (play_sound=false)
```

敌人外观由场景中的 `SpriteFrames` 决定：basic→`slime_frames`，fast→`bat_frames`，boss→`boss_frames`。

### 3.3 Projectile（`scenes/combat/projectiles/projectile_base.tscn`）

```text
ProjectileBase (Area2D, layer=8 PlayerAttack, mask=4 EnemyBody,
                monitoring=false, monitorable=false)
├── Visual (AnimatedSprite2D, bolt_frames, scale 0.1)
├── CollisionShape2D (Circle r=8，运行时按 hit_radius 复制替换)
└── LifetimeTimer (one_shot)
```

### 3.4 ExperienceGem（`scenes/pickups/experience_gem.tscn`）

```text
ExperienceGem (Area2D, layer=32 Pickup, mask=0, monitoring=false)
├── Visual (AnimatedSprite2D, gem_frames, scale 0.12)
└── CollisionShape2D (Circle r=10)
```

### 3.5 组件场景

| 场景 | 类型 | 关键默认值 |
|---|---|---|
| `health_component.tscn` | `Node` | 纯逻辑，无碰撞 |
| `hitbox_component.tscn` | `Area2D` | layer/mask=0，monitoring=false；由 `initialize()` 激活 |
| `hurtbox_component.tscn` | `Area2D` | layer/mask=0，Circle r=24；`monitorable` 由 `initialize()` 设置 |
| `pickup_component.tscn` | `Area2D` | mask=32，Circle r=96，`resource_local_to_scene=true` |
| `damage_feedback_component.tscn` | `Node` | 内含 `AudioStreamPlayer2D`，volume -7dB，max_distance 1600 |

### 3.6 UI 场景

- `hud.tscn`：全屏 `Control`（`mouse_filter=2`），`HealthLabel`/`TimeLabel`/`HealthBar`/`LevelLabel`/`ExperienceBar`。
- `level_up_panel.tscn`：默认隐藏，`process_mode=3`（WHEN_PAUSED），背景遮罩 + 居中面板 + `ChoicesContainer`。
- `end_panel.tscn`：默认隐藏，`process_mode=3`，`Title`/`StatsLabel`/`RestartButton`。

---

## 4. 数据模型（自定义 Resource）

所有定义均为 `Resource`，字段见脚本（`data/**/*.gd`）。当前默认值：

### 4.1 CharacterDefinition（`player_default.tres`）

| 字段 | 值 |
|---|---|
| id / display_name | `player_default` / Default Survivor |
| scene | `player.tscn` |
| max_health | 100 |
| move_speed | 220 |
| camera_zoom | 0.75 |
| base_attack_range | 1000 |
| pickup_radius | 96 |
| starting_weapons | `[starter_weapon]` |

### 4.2 EnemyDefinition

| id | scene | max_health | move_speed | contact_damage | experience_value | is_boss |
|---|---|---:|---:|---:|---:|---|
| `enemy_basic` | `enemy_basic.tscn` | 10 | 80 | 5 | 1 | false |
| `enemy_fast` | `enemy_fast.tscn` | 6 | 145 | 4 | 1 | false |
| `boss_default` | `boss.tscn` | 500 | 55 | 18 | 0 | true |

### 4.3 WeaponDefinition（`starter_weapon.tres`）

冷却 1.0s，弹数 1，扩散 0°，`target_range` 900，`projectile_definition=basic_projectile`，`visual_frames=wand_frames`。

### 4.4 ProjectileDefinition

| id | damage | speed | lifetime | pierce | hit_radius |
|---|---:|---:|---:|---:|---:|
| `basic_projectile` | 10 | 600 | 2.0 | 0 | 8 |
| `fast_projectile` | 6 | 900 | 1.5 | 0 | 6 |

### 4.5 UpgradeDefinition（10 个选项，`UpgradeType` 枚举 0–9）

| id | type | value | max_stacks |
|---|---|---:|---:|
| `damage_up` | 0 DAMAGE_MULTIPLIER | 0.20 | 5 |
| `fire_rate_up` | 1 FIRE_RATE_MULTIPLIER | 0.10 | 5 |
| `projectile_count_up` | 2 PROJECTILE_COUNT | +1 | 3 |
| `move_speed_up` | 3 MOVE_SPEED_MULTIPLIER | 0.10 | 5 |
| `max_health_up` | 4 MAX_HEALTH | +20 | 5 |
| `heal` | 5 HEAL | +30 | 99 |
| `bonus_projectile_chance_up` | 6 BONUS_PROJECTILE_CHANCE | 0.15 | 5 |
| `projectile_lifesteal_up` | 7 PROJECTILE_LIFESTEAL | 0.03 | 5 |
| `pickup_range_up` | 8 PICKUP_RANGE_MULTIPLIER | 0.25 | 5 |
| `repeat_shot_chance_up` | 9 REPEAT_SHOT_CHANCE | 0.15 | 5 |

`weight` 字段已预留，当前选取仍为均匀洗牌（见 `UpgradeSystem._shuffle_available`）。

### 4.6 RunDefinition / DifficultyStage（`default_run.tres`）

单局 `run_duration_seconds=300`，`boss_definition=boss_default`，四段：

| 起始 | 间隔 | 批量 | 上限 | 生命× | 移速× | 伤害× | 敌人池 |
|---:|---:|---:|---:|---:|---:|---:|---|
| 0s | 1.00 | 1 | 30 | 1.00 | 1.00 | 1.00 | basic |
| 60s | 0.75 | 1 | 50 | 1.25 | 1.08 | 1.15 | basic |
| 150s | 0.55 | 2 | 90 | 1.60 | 1.15 | 1.35 | basic, fast |
| 240s | 0.35 | 3 | 140 | 2.10 | 1.25 | 1.65 | basic, fast |

`EnemySpawnSettings`（`phase_one_spawn.tres`）是阶段一遗留的单段配置：间隔 1.0s、上限 30、环带 760–1500、离屏余量 64。

---

## 5. 运行时接口与信号

### 5.1 ActorBase（`scripts/actors/actor_base.gd`）

```gdscript
signal actor_died(actor: ActorBase, event: DamageEvent)

func initialize(new_definition: Resource) -> void
func apply_damage(event: DamageEvent) -> void
func die(event: DamageEvent) -> void          # 单次转发 + 停用碰撞
func get_aim_position() -> Vector2
func get_team_id() -> StringName              # 默认 &"neutral"
func get_attack_range() -> float              # 默认 0.0
```

- `_ready()` 连接 `HealthComponent.died`、初始化 Hurtbox 与受伤反馈。
- 子类提供 `_get_base_max_health()`、`get_team_id()`、`get_attack_range()`。
- `free_on_death=true` 时死亡后 `queue_free()`。

### 5.2 HealthComponent（`scripts/components/health_component.gd`）

```gdscript
signal health_changed(current, maximum)
signal damaged(event)
signal died(event)

func initialize(max) / apply_damage(event) / heal(amount)
func set_maximum_health(new_max, heal_increase=true)
func reset() / is_dead()
```

边界：生命夹在 `[0, max]`；死亡后忽略伤害与治疗；`_dead` 在 `died` 前设置，保证单次死亡。

### 5.3 Hitbox / Hurtbox

- `HitboxComponent.initialize(owner_actor, damage, tags)`；`apply_to(hurtbox)` 生成 `DamageEvent` 并调用 `hurtbox.receive_damage()`。
- `HurtboxComponent.initialize(owner_actor)` 设置 `monitorable`；`receive_damage(event)` 过滤死亡后转发给 `owner_actor.apply_damage()`。
- 当前只有敌人 `ContactHitbox` 使用 Hitbox；玩家没有近战 Hitbox。

### 5.4 WeaponController（`scripts/components/weapon_controller.gd`，`Node2D`）

```gdscript
signal fire_requested(definition, owner_actor, target, projectile_parent, count, damage_multiplier)
signal weapon_fired(weapon_id)
signal projectile_spawned(projectile)

func initialize(definition, owner_actor, projectile_parent)
func set_targeting_service(service)
func can_fire() / request_fire(target) -> bool
func spawn_projectile(definition, context) -> ProjectileBase
func apply_runtime_modifier(modifier) / reset_runtime_state()
```

- 运行参数：冷却倍率、弹数加成、伤害倍率、幸运弹概率、吸血比、追加射击概率。
- 有效索敌范围 = `min(owner_actor.get_attack_range(), definition.target_range)`。
- 所有弹数/扩散在一次 `request_fire` 内生成；未生成任一颗则不消耗冷却。
- 追加射击在冷却 35% 时间点延迟发射，带 generation 防止重开残留。
- 武器可视化子节点跟随角色位置并随控制器清理。

### 5.5 ProjectileBase（`scripts/combat/projectile_base.gd`）

```gdscript
signal projectile_hit(target, event)
signal deactivated(projectile)

func initialize(definition, context) / launch(direction)
func on_hit(target) -> bool / deactivate() / reset_runtime_state()
```

- 命中过滤：非 `HurtboxComponent`/`ActorBase` 忽略；同阵营/发射者忽略；死亡或待删忽略。
- 同物理帧按 `instance_id` 去重（`_last_hit_frame_by_instance_id`）。
- `pierce_count` 表示首个命中后可额外穿透数，默认 0。
- 吸血按目标**实际损失生命**结算；命中回调中延迟修改 `monitoring`。
- 发射者离树清空 `context.shooter`，保留飞行与阵营。

### 5.6 TargetingService（`scripts/systems/targeting_service.gd`）

```gdscript
signal candidates_refreshed(count)
func initialize(candidate_parent) / stop()
func get_nearest_target(origin, max_range, target_team=&"enemy") -> ActorBase
func refresh_candidates() / get_candidate_count()
```

- 每 0.1s 读取注入容器的直接 `ActorBase` 子节点并缓存；查询不遍历场景树。
- 查询时即时剔除失效/死亡候选。

### 5.7 EnemySpawner（`scripts/systems/enemy_spawner.gd`）

```gdscript
signal enemy_spawned(enemy)
func initialize(settings, player, enemy_parent, spawn_bounds)
func spawn_once() -> EnemyActor
func spawn_batch() -> Array[EnemyActor]
func spawn_enemy(definition, position, ignore_alive_limit=false) -> EnemyActor
func get_offscreen_spawn_position() / get_enemy_count() / stop()
func apply_difficulty_stage(stage)
```

- 环带采样：玩家周围 `[min,max]` 距离，必须落在场地内且不在可见矩形 + `offscreen_margin` 内；失败回退到离视野中心最远的场地角。
- 生成前先设局部位置再入树，避免原点碰撞配对。
- 数量上限默认由舞台 `max_alive_enemies` 决定。

### 5.8 DifficultyDirector（`scripts/systems/difficulty_director.gd`）

```gdscript
signal stage_changed(stage_index, stage)
func initialize(run_definition, spawner) / update_elapsed_time(t) / reset()
```

按 `start_time_seconds` 选择当前阶段并推送给生成器；阶段不变时不重复下发。

### 5.9 UpgradeSystem（`scripts/systems/upgrade_system.gd`）

```gdscript
signal choices_ready(choices)
signal upgrade_applied(definition)
func initialize(player) / request_choices(count=3)
func apply_choice(definition) -> bool / can_offer(definition) / reset()
func is_awaiting_choice() / get_current_choices()
```

- 过滤 `max_stacks` 未满的定义后洗牌取前 N；一次三选一内不重复。
- 只接受当前展示列表中的一次选择；`apply_choice` 失败会保持等待。
- 不负责暂停/UI。

### 5.10 GameSession（`scripts/core/game_session.gd`）

```gdscript
signal time_changed(remaining_seconds, elapsed_seconds)
signal run_ended(result: GameResult)
signal boss_spawned(boss: EnemyActor)

func start_run() / advance_time(delta)
func end_run(outcome) / restart_run()
func spawn_experience_gem(value, world_position) -> ExperienceGem
func get_remaining_seconds()
```

- 唯一权威时间 `elapsed_seconds`；暂停、结束或无配置时不推进。
- `start_run` 流程：创建玩家 → 注入摄像机边界/武器/索敌 → 初始化生成器、难度、升级、HUD、面板 → 连接信号。
- 到达 `run_duration_seconds` 时停止普通生成并只生成一次 Boss。
- `end_run` 停生成/索敌/战斗节点，暂停并显示 `EndPanel`，发布 `GameResult`。
- `restart_run` 通过 `reload_current_scene()` 清除所有单局状态。

### 5.11 PlayerActor（`scripts/actors/player_actor.gd`）

```gdscript
signal experience_changed(current_experience, gained_amount)
signal level_progress_changed(current_level, current_level_experience, required_experience)
signal leveled_up(new_level, pending_upgrade_count)
signal upgrade_state_changed(upgrade_id, stack_count)

func initialize / configure_camera_bounds / configure_weapons / clear_weapons
func add_experience(amount) / get_current_experience / get_current_level_experience
func get_current_level / get_required_experience(level=current)
func get_pending_upgrade_count / consume_pending_upgrade
func get_upgrade_stack(id) / apply_upgrade(upgrade) -> bool
func get_effective_move_speed / get_effective_maximum_health / get_effective_pickup_radius
```

- 经验曲线集中在 `get_required_experience`：`5 + level × 3`。
- `add_experience` 支持一次跨多级，每级 +1 待选择升级。
- 移动每物理帧读 InputMap 并归一化（`Input.get_vector`）。
- 运行时修正：移速倍率、最大生命加成、拾取倍率、每个武器控制器的 `WeaponRuntimeModifier`。

### 5.12 其他

- `EnemyActor`：`initialize`、`apply_difficulty_multipliers(health×, speed×, damage×)`、`set_target_player()`；目标失效即停止。
- `ExperienceGem`：`initialize(value)` / `collect(collector) -> bool` / `get_experience_value()` / `is_collected()`；原子化单次结算。
- `Arena`：`get_bounds() -> Rect2`（默认 2560×1440），`_draw()` 画网格与边框。
- `GameResult`（`RefCounted`）：`outcome`(VICTORY/DEFEAT)、`elapsed_seconds`、`level`、`kill_count`。

---

## 6. 关键运行时数据流

### 6.1 伤害

```text
敌人 ContactHitbox (Area2D) ──area_entered──▶ HitboxComponent.apply_to(hurtbox)
    → DamageEvent(amount, source, position)
    → HurtboxComponent.receive_damage()
    → ActorBase.apply_damage() → HealthComponent.apply_damage()
    → damaged / health_changed / died
    → DamageFeedbackComponent 受伤反馈（红色闪烁 + 缩放 + 可选音效）
    → HealthComponent.died → ActorBase.actor_died
```

子弹路径：`WeaponController.request_fire` → `spawn_projectile` → `ProjectileBase.initialize/launch` → `area_entered` → `ProjectileBase.on_hit` → `DamageEvent` → `Hurtbox.receive_damage`。

### 6.2 经验与升级

```text
EnemyActor.actor_died
  → GameSession._on_enemy_died：kill_count++，非 Boss 则在死亡位置生成 ExperienceGem
  → gem 入树（延迟到物理安全时机）→ 玩家 PickupComponent.pickup_detected
  → ExperienceGem.collect(player) → PlayerActor.add_experience()
  → leveled_up(new_level, pending)
  → GameSession._on_player_leveled_up → _request_next_upgrade()
      → get_tree().paused = true
      → UpgradeSystem.request_choices(3) → choices_ready
      → LevelUpPanel.show_choices() 展示按钮
      → 点击 → UpgradeSystem.apply_choice → PlayerActor.apply_upgrade()
      → upgrade_applied → 若仍有待选择则继续，否则恢复
```

经验宝石先标记 `_is_collected` 再通知玩家，避免重复结算。

### 6.3 时间 / 难度 / Boss / 结算

```text
GameSession._process → advance_time(delta)
  → elapsed_seconds++ → DifficultyDirector.update_elapsed_time()
      → 阶段变化时 EnemySpawner.apply_difficulty_stage()
  → HUD.update_remaining_time + time_changed
  → 到达 300s → _spawn_boss()（停普通生成，只一次，ignore_alive_limit）
玩家死亡 / Boss 死亡
  → GameSession.end_run(VICTORY|DEFEAT)
  → 停生成、索敌、战斗节点；暂停；EndPanel.show_result(GameResult)
  → RestartButton → restart_run() → reload_current_scene()
```

---

## 7. 碰撞层（与 `project.godot` 一致）

| 层 | 名称 | 值 | 当前使用 |
|---:|---|---:|---|
| 1 | World | 1 | Arena `Bounds` StaticBody2D；玩家/敌人移动 mask=1 |
| 2 | PlayerBody | 2 | 玩家实体层、玩家 Hurtbox 层；敌人 ContactHitbox mask |
| 3 | EnemyBody | 4 | 敌人实体层、敌人 Hurtbox 层；子弹 mask |
| 4 | PlayerAttack | 8 | ProjectileBase 层 |
| 5 | EnemyAttack | 16 | 敌人 ContactHitbox 层 |
| 6 | Pickup | 32 | ExperienceGem 层；玩家 PickupComponent mask |
| 7 | Sensor | 64 | 预留，暂未使用 |
| 8 | Reserved | - | 未使用 |

关系要点：

- 玩家与敌人 `collision_mask` 仅 World，双方互不阻挡（`MOTION_MODE_FLOATING`）。
- 接触伤害由 `ContactHitbox(mask=2)` ↔ 玩家 `Hurtbox(layer=2)` 的 Area 检测完成。
- 玩家子弹 `layer=8, mask=4` 检测敌人 `Hurtbox(layer=4)`。
- 拾取由 `PickupComponent(mask=32)` 检测 `ExperienceGem(layer=32, monitorable=true)`。

---

## 8. 扩展点（保持现有接口时优先）

| 需求 | 推荐做法 |
|---|---|
| 新角色 | 新建 `CharacterDefinition` + 场景；不复制 `PlayerActor` |
| 新敌人 | 新建 `EnemyDefinition` + 场景，复用 `EnemyActor`/组件；必要时让行为独立 |
| 新武器 | 新建 `WeaponDefinition` + 子弹定义；`PlayerActor.configure_weapons` 支持多控制器 |
| 新子弹 | 新建 `ProjectileDefinition`（可换场景）；子类覆盖 `on_hit()` |
| 新升级 | 新建 `UpgradeDefinition`；若超出枚举则先扩展 `UpgradeType` 或抽效果策略 |
| 新波次/难度 | 修改/新增 `RunDefinition` 与 `DifficultyStage` |
| 可视化反馈 | `ActorSprite`（SpriteFrames）与 `DamageFeedbackComponent` |

对象池预留接口已在 `ProjectileBase` 保留：`deactivate()` / `reset_runtime_state()`；`ActorBase.free_on_death`、`ProjectileBase.free_on_deactivate` 可关闭以复用节点。

---

## 9. 验证入口

```bash
# 解析与导入（macOS 示例路径）
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit

# 启动主场景 300 帧
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300

# 单个冒烟测试（SceneTree 脚本仍返回退出码）
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/smoke/<name>_smoke_test.gd
```

测试清单、覆盖矩阵与已知限制见 `docs/BASELINE.md`。
