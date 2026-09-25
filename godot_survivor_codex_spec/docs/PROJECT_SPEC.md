# Survivor-like 2D 最小 Demo：Codex 开发说明书

## 文档信息

| 项目 | 内容 |
|---|---|
| 项目代号 | `survivor_demo` |
| 游戏类型 | 2D 俯视角 Survivor-like / Bullet Heaven |
| 引擎 | Godot 4.7.1 stable |
| 脚本语言 | GDScript |
| 首要平台 | macOS |
| 基准分辨率 | 1280 × 720 |
| 单局时长 | 10 分钟 |
| 目标 | 完成一个可运行、可游玩、可扩展的最小 Demo |

---

# 1. 产品目标

制作一个参考《吸血鬼幸存者》和《土豆兄弟》核心循环的最小可玩 Demo。

玩家只需要使用 WASD 或方向键移动。角色自动寻找目标并攻击，敌人从场地周围生成并追踪玩家。敌人死亡后掉落经验，玩家升级时从三个随机选项中选择一个强化。游戏持续 10 分钟，最后生成 Boss；玩家死亡则失败，Boss 被击败或满足通关条件则胜利。

## 1.1 核心体验

```text
进入游戏
  ↓
移动并躲避敌人
  ↓
武器自动攻击
  ↓
敌人死亡并掉落经验
  ↓
拾取经验并升级
  ↓
升级三选一
  ↓
敌人数量和强度提高
  ↓
Boss 出现
  ↓
胜利或失败结算
```

## 1.2 本 Demo 必须包含

- 玩家八方向移动
- 摄像机跟随
- 敌人持续生成并追踪玩家
- 自动寻找最近目标
- 自动发射子弹
- 伤害、生命值和死亡
- 经验掉落和拾取
- 等级与经验条
- 升级时暂停游戏
- 随机三选一升级
- 10 分钟倒计时
- 两种普通敌人
- 一个 Boss
- 玩家死亡界面
- 胜利界面
- 重新开始

## 1.3 暂不实现

第一版禁止加入以下内容：

- 联机
- 存档
- Steam 成就
- 复杂背包
- 商店
- 随机地图生成
- 复杂地图阻挡和寻路
- 装备词缀系统
- 元进度
- 复杂剧情
- 多语言系统
- 手柄适配
- 移动端适配
- 第三方测试插件
- 大规模对象池框架

这些内容只能在四个阶段完成后单独规划。

---

# 2. 总体技术设计

## 2.1 设计原则

### 数据驱动

不同角色、敌人、武器、子弹和升级不应通过复制代码实现。使用自定义 `Resource` 保存配置，通过同一套基础行为加载不同配置。

例如，新增一种子弹原则上只需要：

1. 新建一个 `ProjectileDefinition` 资源；
2. 选择对应的子弹场景；
3. 配置速度、伤害、穿透、持续时间和命中特性；
4. 必要时继承 `ProjectileBase` 添加特殊行为。

### 组合优先于继承

基础继承只用于表达稳定类别，例如：

```text
ActorBase
├── PlayerActor
└── EnemyActor

ProjectileBase
├── StraightProjectile
├── PiercingProjectile
└── AreaProjectile
```

生命值、碰撞、经验、状态效果等能力通过组件组合，避免出现层次过深的继承结构。

### 信号解耦

以下事件优先使用信号：

- 生命值变化
- 角色死亡
- 敌人被击杀
- 经验变化
- 玩家升级
- 游戏计时变化
- 游戏结束
- 升级选项确认

不允许 UI 直接每帧读取大量战斗节点。UI 应监听游戏会话或玩家状态信号。

### 场景局部状态优先

本 Demo 的战斗状态放在当前 `GameSession` 场景中，不使用大量 Autoload。

允许的 Autoload 候选：

- `SceneRouter`：场景切换
- `GameSettings`：全局设置
- `AudioManager`：后续统一音频管理

第一版若不需要跨场景持久化，可以完全不使用 Autoload。

---

# 3. 推荐目录结构

Codex 应按以下结构创建和维护文件：

```text
survivor_demo/
├── AGENTS.md
├── README.md
├── project.godot
├── export_presets.cfg                 # 配置导出后再创建
├── .gitignore
│
├── assets/
│   ├── placeholders/
│   │   ├── player.svg
│   │   ├── enemy_basic.svg
│   │   ├── enemy_fast.svg
│   │   ├── boss.svg
│   │   ├── projectile.svg
│   │   └── experience_gem.svg
│   ├── sprites/
│   ├── audio/
│   ├── fonts/
│   └── ui/
│
├── data/
│   ├── characters/
│   │   ├── player_default.tres
│   │   └── character_definition.gd
│   ├── enemies/
│   │   ├── enemy_basic.tres
│   │   ├── enemy_fast.tres
│   │   ├── boss_default.tres
│   │   └── enemy_definition.gd
│   ├── weapons/
│   │   ├── starter_weapon.tres
│   │   └── weapon_definition.gd
│   ├── projectiles/
│   │   ├── basic_projectile.tres
│   │   └── projectile_definition.gd
│   ├── upgrades/
│   │   ├── damage_up.tres
│   │   ├── fire_rate_up.tres
│   │   ├── projectile_count_up.tres
│   │   ├── move_speed_up.tres
│   │   └── upgrade_definition.gd
│   └── waves/
│       ├── default_run.tres
│       └── run_definition.gd
│
├── scenes/
│   ├── bootstrap/
│   │   └── main.tscn
│   ├── gameplay/
│   │   ├── game_session.tscn
│   │   └── arena.tscn
│   ├── actors/
│   │   ├── common/
│   │   │   └── actor_base.tscn
│   │   ├── player/
│   │   │   └── player.tscn
│   │   └── enemies/
│   │       ├── enemy_basic.tscn
│   │       ├── enemy_fast.tscn
│   │       └── boss.tscn
│   ├── combat/
│   │   ├── projectiles/
│   │   │   └── projectile_base.tscn
│   │   └── effects/
│   ├── pickups/
│   │   └── experience_gem.tscn
│   ├── components/
│   │   ├── health_component.tscn
│   │   ├── hitbox_component.tscn
│   │   ├── hurtbox_component.tscn
│   │   └── pickup_component.tscn
│   └── ui/
│       ├── hud.tscn
│       ├── level_up_panel.tscn
│       └── end_panel.tscn
│
├── scripts/
│   ├── core/
│   │   ├── game_session.gd
│   │   ├── game_result.gd
│   │   └── spawn_context.gd
│   ├── actors/
│   │   ├── actor_base.gd
│   │   ├── player_actor.gd
│   │   └── enemy_actor.gd
│   ├── combat/
│   │   ├── damage_event.gd
│   │   ├── projectile_base.gd
│   │   ├── weapon_controller.gd
│   │   └── targeting_service.gd
│   ├── components/
│   │   ├── health_component.gd
│   │   ├── hitbox_component.gd
│   │   ├── hurtbox_component.gd
│   │   └── pickup_component.gd
│   ├── systems/
│   │   ├── enemy_spawner.gd
│   │   ├── difficulty_director.gd
│   │   ├── experience_system.gd
│   │   └── upgrade_system.gd
│   ├── pickups/
│   │   └── experience_gem.gd
│   └── ui/
│       ├── hud.gd
│       ├── level_up_panel.gd
│       └── end_panel.gd
│
├── tests/
│   ├── smoke/
│   │   ├── boot_smoke_test.tscn
│   │   └── combat_smoke_test.tscn
│   └── README.md
│
├── tools/
│   ├── validate_project.sh
│   └── run_game.sh
│
└── docs/
    ├── PROJECT_SPEC.md
    ├── TASKS.md
    ├── ARCHITECTURE.md               # 需要时由 Codex补充
    └── CHANGELOG.md
```

## 3.1 目录规则

- `assets/`：仅放美术、音频、字体和原始资源。
- `data/`：仅放自定义 Resource 类型和 `.tres` 配置。
- `scenes/`：仅放 Godot 场景。
- `scripts/`：按业务功能分类脚本。
- `tests/`：放自动或手动测试场景。
- `tools/`：放开发脚本，不放游戏运行时代码。
- `docs/`：需求、架构、任务和变更记录。
- 不允许创建 `misc/`、`temp/`、`new_folder/` 等含义不清的目录。
- 新文件必须放入最接近其职责的功能目录。

---

# 4. 场景树设计

## 4.1 主入口

```text
Main (Node)
└── GameSession (Node2D)
```

`Main` 只负责加载和切换游戏场景，不保存具体战斗逻辑。

## 4.2 GameSession

```text
GameSession (Node2D)
├── Arena (Node2D)
├── Actors (Node2D)
│   ├── Player
│   └── Enemies
├── Projectiles (Node2D)
├── Pickups (Node2D)
├── Systems (Node)
│   ├── EnemySpawner
│   ├── DifficultyDirector
│   ├── TargetingService
│   ├── ExperienceSystem
│   └── UpgradeSystem
└── CanvasLayer
    ├── HUD
    ├── LevelUpPanel
    └── EndPanel
```

`GameSession` 是单局游戏的组合根节点，负责：

- 创建和初始化玩家；
- 管理当前游戏时间；
- 保存当前运行状态；
- 接收玩家死亡和 Boss 死亡事件；
- 暂停和恢复；
- 结束与重新开始；
- 向 UI 发布状态变化。

## 4.3 Player

```text
Player (CharacterBody2D)
├── Visual (Sprite2D)
├── CollisionShape2D
├── HealthComponent
├── HurtboxComponent
├── PickupArea (Area2D)
│   └── CollisionShape2D
├── WeaponController
└── Camera2D
```

## 4.4 Enemy

```text
Enemy (CharacterBody2D)
├── Visual (Sprite2D)
├── CollisionShape2D
├── HealthComponent
├── HurtboxComponent
└── ContactHitbox (Area2D)
    └── CollisionShape2D
```

## 4.5 Projectile

```text
ProjectileBase (Area2D)
├── Visual (Sprite2D)
├── CollisionShape2D
└── LifetimeTimer
```

---

# 5. 核心数据模型

## 5.1 CharacterDefinition

```gdscript
class_name CharacterDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export var max_health: float = 100.0
@export var move_speed: float = 220.0
@export var base_attack_range: float = 1000.0
@export var pickup_radius: float = 96.0
@export var starting_weapons: Array[WeaponDefinition] = []
```

扩展时可以增加：

- 护甲
- 暴击率
- 暴击倍率
- 闪避
- 生命恢复
- 角色被动
- 角色专属升级池

## 5.2 EnemyDefinition

```gdscript
class_name EnemyDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export var max_health: float = 10.0
@export var move_speed: float = 80.0
@export var contact_damage: float = 5.0
@export var experience_value: int = 1
@export var spawn_cost: float = 1.0
@export var is_boss: bool = false
```

## 5.3 WeaponDefinition

```gdscript
class_name WeaponDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var projectile_definition: ProjectileDefinition
@export var cooldown_seconds: float = 1.0
@export var projectile_count: int = 1
@export var spread_degrees: float = 0.0
@export var target_range: float = 900.0
```

后续可以增加不同发射策略：

- 最近敌人
- 随机敌人
- 鼠标方向
- 环形发射
- 固定方向
- 链式目标
- 召唤物攻击

不要直接在 `WeaponController` 中写大量 `match weapon_id`。不同复杂策略应抽成独立策略对象或武器行为脚本。

攻击范围采用两层数据约束：

- `CharacterDefinition.base_attack_range` 表示角色自身可索敌的基础范围上限，不同角色可独立配置；
- `WeaponDefinition.target_range` 表示该武器自身的最大索敌射程，不同武器可独立配置；
- 单把武器的有效索敌范围为 `min(角色当前攻击范围, 武器射程)`；
- 范围只参与索敌，不替代子弹速度、生命周期、碰撞或近战区域等实际命中规则；
- 后续单局升级应在 Actor 或 `WeaponController` 的运行时计算中叠加，不得回写共享 `.tres`。

## 5.4 ProjectileDefinition

```gdscript
class_name ProjectileDefinition
extends Resource

@export var id: StringName
@export var scene: PackedScene
@export var damage: float = 10.0
@export var speed: float = 600.0
@export var lifetime_seconds: float = 2.0
@export var pierce_count: int = 0
@export var hit_radius: float = 8.0
@export var knockback_strength: float = 0.0
```

扩展时可支持：

- 直线弹
- 穿透弹
- 追踪弹
- 爆炸弹
- 弹射弹
- 回旋弹
- 持续区域
- 激光
- 近战范围攻击

## 5.5 UpgradeDefinition

```gdscript
class_name UpgradeDefinition
extends Resource

enum UpgradeType {
    DAMAGE_MULTIPLIER,
    FIRE_RATE_MULTIPLIER,
    PROJECTILE_COUNT,
    MOVE_SPEED_MULTIPLIER,
    MAX_HEALTH,
    HEAL,
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var type: UpgradeType
@export var value: float
@export var max_stacks: int = 5
@export var weight: float = 1.0
```

第一版可以使用枚举实现简单升级；后续复杂升级应改为效果 Resource 或策略对象，避免升级系统持续膨胀。

---

# 6. 公共运行时接口

## 6.1 DamageEvent

所有伤害通过统一数据对象传递：

```gdscript
class_name DamageEvent
extends RefCounted

var amount: float
var source: Node
var source_position: Vector2
var tags: Array[StringName]
var can_crit: bool
var knockback_strength: float
```

不要只传一个数字，因为后续可能需要：

- 伤害来源
- 武器来源
- 暴击
- 元素标签
- 击退方向
- 击杀统计
- 伤害浮字
- 状态效果

## 6.2 HealthComponent

必须提供：

```gdscript
signal health_changed(current: float, maximum: float)
signal damaged(event: DamageEvent)
signal died(event: DamageEvent)

func initialize(maximum_health: float) -> void
func apply_damage(event: DamageEvent) -> void
func heal(amount: float) -> void
func reset() -> void
func is_dead() -> bool
```

边界要求：

- 生命值不能低于 0；
- 生命值不能高于最大值；
- 死亡信号只能触发一次；
- 死亡后不再接受普通伤害；
- 初始化或复用时必须重置死亡状态。

## 6.3 ActorBase

```gdscript
signal actor_died(actor: ActorBase, event: DamageEvent)

func initialize(definition: Resource) -> void
func apply_damage(event: DamageEvent) -> void
func die(event: DamageEvent) -> void
func get_aim_position() -> Vector2
func get_team_id() -> StringName
```

`PlayerActor` 和 `EnemyActor` 可以继承该基类，但移动和决策逻辑分别实现。

## 6.4 WeaponController

```gdscript
signal weapon_fired(weapon_id: StringName)

func initialize(
    definition: WeaponDefinition,
    owner_actor: ActorBase,
    projectile_parent: Node
) -> void

func can_fire() -> bool
func request_fire(target: Node2D) -> bool
func apply_runtime_modifier(modifier: WeaponRuntimeModifier) -> void
func reset_runtime_state() -> void
```

要求：

- 武器配置只读；
- 单局升级值保存在运行时状态中；
- 不修改共享 `.tres` Resource；
- 发射逻辑不能直接依赖固定玩家路径；
- 子弹父节点通过初始化参数注入。

## 6.5 ProjectileBase

```gdscript
func initialize(
    definition: ProjectileDefinition,
    context: ProjectileSpawnContext
) -> void

func launch(direction: Vector2) -> void
func on_hit(target: Node) -> void
func deactivate() -> void
func reset_runtime_state() -> void
```

`ProjectileSpawnContext` 至少包含：

- 发射者
- 队伍
- 初始位置
- 初始方向
- 最终伤害倍率
- 可选目标
- 武器 ID

## 6.6 经验掉落与拾取

```gdscript
signal PlayerActor.experience_changed(current_experience: int, gained_amount: int)

func PlayerActor.add_experience(amount: int) -> void
func PlayerActor.get_current_experience() -> int
func ExperienceGem.initialize(experience_value: int) -> void
func ExperienceGem.collect(collector: PlayerActor) -> bool
func GameSession.spawn_experience_gem(experience_value: int, world_position: Vector2) -> ExperienceGem
```

要求：

- 经验值来自 `EnemyDefinition.experience_value`，宝石实例只保存本局数值；
- 敌人死亡通过 `ActorBase.actor_died` 通知 `GameSession` 生成宝石；
- 玩家拾取半径来自 `CharacterDefinition.pickup_radius`；
- 宝石必须先标记已结算再通知玩家，同一实例不能重复增加经验；
- UI 只监听玩家经验信号，不直接扫描宝石或敌人；
- 等级、经验阈值和升级触发属于阶段三，不在宝石脚本中实现。

## 6.7 UpgradeSystem

```gdscript
signal choices_ready(choices: Array[UpgradeDefinition])
signal upgrade_applied(definition: UpgradeDefinition)

func request_choices(count: int = 3) -> void
func apply_choice(definition: UpgradeDefinition) -> void
func can_offer(definition: UpgradeDefinition) -> bool
func reset() -> void
```

要求：

- 不提供已达到最大层数的升级；
- 同一次三选一不重复；
- 升级选项不足三个时允许返回较少数量；
- 暂停和恢复由 `GameSession` 统一控制；
- UI 不直接修改玩家属性，只提交选择。

---

# 7. 碰撞层设计

统一使用以下碰撞层，禁止各场景自行随意设置：

| 层 | 名称 | 用途 |
|---:|---|---|
| 1 | World | 地图边界和障碍物 |
| 2 | PlayerBody | 玩家实体 |
| 3 | EnemyBody | 敌人实体 |
| 4 | PlayerAttack | 玩家攻击 |
| 5 | EnemyAttack | 敌人攻击 |
| 6 | Pickup | 经验和掉落物 |
| 7 | Sensor | 索敌、拾取和范围检测 |
| 8 | Reserved | 预留 |

建议关系：

- 玩家和敌人的实体身体只检测 World，彼此不产生物理阻挡；
- 玩家与敌人的战斗接触统一由 Hitbox/Hurtbox Area 检测，避免追踪敌人贴住或锁住玩家；
- 玩家攻击只检测 EnemyBody 或敌人的 Hurtbox；
- 敌人攻击只检测 PlayerBody 或玩家 Hurtbox；
- Pickup 只与玩家 PickupArea 交互；
- Sensor 不产生实体阻挡。

碰撞层变化必须同步更新本表。

---

# 8. 四阶段开发计划

# 阶段一：基础运行

## 8.1 目标

建立项目基础结构，实现玩家移动、摄像机跟随、敌人生成和追踪。

## 8.2 功能

### P1-01 项目初始化

- 创建 Godot 项目；
- 设置主场景；
- 设置 1280 × 720；
- 配置拉伸模式；
- 创建推荐目录；
- 创建 `.gitignore`；
- 配置输入：
  - `move_up`
  - `move_down`
  - `move_left`
  - `move_right`
- WASD 和方向键同时可用；
- 创建占位 SVG 资源。

### P1-02 玩家

- 使用 `CharacterBody2D`；
- 根据输入生成归一化方向；
- 使用 `velocity` 和 `move_and_slide()`；
- 斜向速度不能更快；
- 摄像机跟随玩家；
- 玩家不能离开基础场地边界。

### P1-03 敌人

- 创建 `EnemyDefinition`；
- 创建通用 `EnemyActor`；
- 敌人直接朝玩家移动；
- 第一阶段不使用 `NavigationAgent2D`；
- 敌人从玩家视野外生成；
- 敌人失去有效玩家引用时安全停止。

### P1-04 生成器

- `EnemySpawner` 通过配置生成敌人；
- 生成位置必须在相机视野之外、合理距离之内；
- 不允许生成在玩家脚下；
- 初始频率约每秒 1 个；
- 可限制最大敌人数。

## 8.3 验收标准

- 项目打开后无解析错误；
- 点击运行直接进入游戏；
- WASD 和方向键均可移动；
- 斜向移动速度正常；
- 摄像机稳定跟随；
- 敌人从四周持续出现；
- 敌人能追踪玩家；
- 运行 2 分钟无明显错误；
- 至少保留基础角色和敌人 Resource 接口。

---

# 阶段二：战斗循环

## 8.4 目标

实现自动攻击、伤害、敌人死亡、经验掉落和拾取。

## 8.5 功能

### P2-01 组件化生命值

- 创建 `HealthComponent`；
- 玩家和敌人均使用相同组件；
- 使用 `DamageEvent`；
- 生命变化和死亡通过信号通知。

### P2-02 索敌

- 创建 `TargetingService`；
- 支持获取一定范围内最近的有效敌人；
- 不在每个武器脚本中遍历整个场景树；
- 第一版可按固定间隔刷新候选，例如 0.1 秒；
- 无目标时武器不发射。

### P2-03 武器

- 创建 `WeaponDefinition`；
- 创建 `WeaponController`；
- 默认武器每约 1 秒攻击最近敌人；
- 角色基础攻击范围与武器自身射程分别配置，有效索敌范围取两者较小值；
- 武器运行时数据与共享 Resource 分离；
- 支持未来角色拥有多个武器控制器。

### P2-04 子弹

- 创建 `ProjectileDefinition`；
- 创建 `ProjectileBase`；
- 子弹直线移动；
- 命中敌人造成伤害；
- 超时自动销毁或停用；
- 默认命中一次后消失；
- `pierce_count` 接口必须保留；
- 同一子弹不能在同一物理帧重复伤害同一目标。

### P2-05 经验

- 敌人死亡生成经验宝石；
- 宝石携带经验值；
- 玩家进入拾取范围后拾取；
- 拾取后宝石不能被重复结算；
- 玩家经验变化通过信号通知 UI。

## 8.6 验收标准

- 玩家自动攻击最近敌人；
- 无敌人时不生成无意义子弹；
- 子弹命中正确目标；
- 敌人生命耗尽后只死亡一次；
- 敌人死亡后掉落经验；
- 玩家接近后可拾取；
- 经验值正确累加；
- 连续击杀 100 个敌人不出现明显错误；
- 新建第二种 `ProjectileDefinition` 不需要修改玩家代码。

---

# 阶段三：成长系统

## 8.7 目标

完成经验升级、暂停和随机三选一强化。

## 8.8 功能

### P3-01 等级模型

玩家运行时状态至少包含：

- 当前等级；
- 当前经验；
- 下一级所需经验；
- 当前升级栈；
- 武器运行时倍率；
- 移动速度倍率；
- 最大生命值修正。

建议简单经验曲线：

```text
required_xp(level) = 5 + level × 3
```

公式必须集中在一个方法中，不能散落在 UI 或宝石脚本里。

### P3-02 升级触发

- 达到经验阈值后升级；
- 支持一次拾取跨越多个等级；
- 每次升级都应得到一次选择；
- 若连续升级，完成前一次选择后继续下一次；
- 游戏暂停但升级 UI 仍可操作。

### P3-03 三选一

初始升级：

- 伤害 +20%
- 攻击冷却 -10%
- 子弹数量 +1
- 移动速度 +10%
- 最大生命值 +20
- 恢复一定生命值

每次随机选择三个不重复且可用的选项。

### P3-04 属性修正

不要直接在多个地方修改基础数据。

建议结构：

```text
最终属性 = 基础属性 × 乘法修正 + 加法修正
```

至少区分：

- 基础值；
- 永久运行时升级；
- 临时效果（预留）；
- 最终计算值。

## 8.9 验收标准

- HUD 显示等级和经验条；
- 达到阈值后游戏暂停；
- 三个选项无重复；
- 点击后强化生效；
- UI 关闭后游戏恢复；
- 攻击力、攻速、弹数和移速强化可观察验证；
- 达到最大层数的选项不再出现；
- 一次获得大量经验时不会丢失升级次数；
- UI 不直接修改 `WeaponDefinition` 或 `CharacterDefinition`。

---

# 阶段四：完整 Demo

## 8.10 目标

加入时间推进、难度增长、敌人类型、Boss 和结算。

## 8.11 功能

### P4-01 游戏计时

- 单局 10 分钟；
- HUD 显示剩余时间；
- 暂停选择升级时计时停止；
- 计时不得依赖 UI；
- `GameSession` 维护唯一权威时间。

### P4-02 难度导演

`DifficultyDirector` 根据经过时间计算：

- 生成间隔；
- 同批生成数量；
- 可生成敌人类型；
- 生命倍率；
- 移动速度倍率；
- 伤害倍率；
- 最大场上敌人数。

第一版使用分段配置，不需要复杂曲线编辑器。

建议：

| 时间 | 行为 |
|---|---|
| 0:00–1:00 | 基础敌人，低密度 |
| 1:00–2:30 | 增加生成速度 |
| 2:30–4:00 | 加入快速敌人 |
| 4:00–10:00 | 高密度混合敌人；5:00 后降低基础/通用 Buff 权重，增加质变权重 |
| 10:00 | 生成 Boss，普通敌人继续生成 |

### P4-03 两种普通敌人

基础敌人：

- 中等生命；
- 中等速度；
- 中等经验。

快速敌人：

- 低生命；
- 高速度；
- 较低经验；
- 使用相同 `EnemyActor` 行为，主要通过 Resource 区分。

### P4-04 Boss

- 使用独立 Boss 场景；
- 仍复用生命值和伤害组件；
- 明显更高生命值；
- 体积更大；
- 可以先只追踪并接触攻击；
- Boss 死亡触发胜利；
- Boss 只生成一次。

### P4-05 结算

失败条件：

- 玩家生命值归零。

胜利条件：

- Boss 被击败。

结束时：

- 停止生成；
- 停止战斗；
- 显示胜利或失败；
- 显示存活时间、等级、击杀数；
- 提供重新开始按钮；
- 重开后所有单局状态必须清空。

## 8.12 验收标准

- 游戏可完整运行 10 分钟；
- 敌人密度随时间提高；
- 2 分 30 秒后出现快速敌人；
- 10 分钟时 Boss 只生成一次；
- 玩家死亡进入失败结算；
- Boss 死亡进入胜利结算；
- 重新开始不会保留旧敌人、子弹、经验、等级或信号连接；
- 至少连续重新开始三次无明显错误；
- 最终版本可以在 macOS 编辑器中稳定运行。

---

# 9. UI 规范

## 9.1 HUD

必须显示：

- 玩家生命条；
- 当前等级；
- 当前经验条；
- 剩余时间；
- 可选：击杀数。

HUD 仅负责显示，不承担游戏规则。

## 9.2 LevelUpPanel

- 默认隐藏；
- 居中显示；
- 显示 1–3 个升级按钮；
- 每个按钮显示名称和描述；
- 输入后防止重复提交；
- 选择后通知 `UpgradeSystem`；
- 不直接访问玩家内部节点。

## 9.3 EndPanel

显示：

- `Victory` 或 `Defeat`；
- 存活时间；
- 等级；
- 击杀数；
- 重新开始按钮。

---

# 10. 性能设计

## 10.1 第一版基线

目标不是一开始支持上千个实体，而是先保证：

- 约 200 个敌人；
- 约 150 个活动子弹；
- 约 200 个经验宝石；
- 60 FPS 或无明显卡顿；
- 不出现持续增长的节点泄漏。

具体性能取决于设备，以上作为开发烟雾测试，不作为发行承诺。

## 10.2 性能规则

1. 敌人直接追踪玩家，不为每个敌人创建导航代理。
2. 不让每个敌人每帧搜索玩家；初始化时注入或缓存引用。
3. 不让每个武器每帧遍历整个场景树。
4. 索敌按固定间隔更新。
5. 重复资源使用 `PackedScene`。
6. 避免在 `_process()` 和 `_physics_process()` 中创建大量临时数组。
7. 经验宝石过多时可合并附近宝石，但不属于第一阶段。
8. 对象池只在性能分析证明有必要后加入。
9. 若加入对象池，所有对象必须实现 `reset_runtime_state()`。
10. 禁止为了“未来可能需要”立即实现复杂通用 ECS。

## 10.3 对象池预留

第一版可直接 `instantiate()` 和 `queue_free()`，但子弹和敌人基础类应保留：

```gdscript
func activate(context: Variant) -> void
func deactivate() -> void
func reset_runtime_state() -> void
```

以后切换为对象池时，业务代码不需要完全重写。

---

# 11. 代码规范

## 11.1 类型

优先：

```gdscript
var move_speed: float = 220.0
var current_target: Node2D
func apply_damage(event: DamageEvent) -> void:
```

避免无必要的动态 Variant。

## 11.2 导出变量

`@export` 用于：

- 场景设计者需要编辑的引用；
- 可视化调试参数；
- Resource 配置；
- 外部场景注入。

不要把大量运行时状态暴露为 `@export`。

## 11.3 节点引用

优先：

```gdscript
@onready var health_component: HealthComponent = %HealthComponent
```

对稳定内部节点可使用唯一名称。跨模块引用通过初始化参数或导出引用注入。

禁止在每帧逻辑中反复调用：

```gdscript
get_node()
find_child()
get_first_node_in_group()
```

## 11.4 信号

- 信号名使用过去式或事件式：`died`、`health_changed`；
- 连接和断开必须考虑节点生命周期；
- 不重复连接同一信号；
- 信号参数使用明确类型；
- UI 监听上层模型或会话信号。

## 11.5 错误处理

必要引用缺失时：

```gdscript
if player == null:
    push_error("EnemyActor 初始化失败：缺少 player 引用。")
    set_physics_process(false)
    return
```

不要让空引用错误持续每帧刷屏。

## 11.6 魔法数字

以下数值不能散落在代码中：

- 移动速度；
- 伤害；
- 攻击间隔；
- 生成频率；
- 经验值；
- 游戏时长；
- Boss 出现时间。

它们应集中到 Resource、常量或唯一规则方法。

---

# 12. 注释和文档标准

## 12.1 文件头

公共基础脚本建议包含：

```gdscript
## 子弹运行时基础类。
##
## 负责移动、生命周期、命中去重和伤害事件构造。
## 子类可以覆盖 on_hit() 实现爆炸、弹射或状态效果。
class_name ProjectileBase
extends Area2D
```

## 12.2 公共方法

复杂公共方法说明：

```gdscript
## 使用配置和生成上下文重置子弹。
##
## 每次实例化或从对象池取出时必须调用。
## 该方法不得修改共享 ProjectileDefinition。
func initialize(
    definition: ProjectileDefinition,
    context: ProjectileSpawnContext
) -> void:
    ...
```

## 12.3 注释应说明

- 设计原因；
- 不明显的边界条件；
- 生命周期要求；
- 性能取舍；
- 扩展方式；
- 数据是否共享或只读。

## 12.4 注释不应说明

```gdscript
# 速度乘以 delta
position += velocity * delta
```

这种注释没有提供额外信息，应删除。

---

# 13. Git 与项目管理

## 13.1 分支

```text
main
├── feat/p1-project-bootstrap
├── feat/p1-player-movement
├── feat/p1-enemy-spawner
├── feat/p2-health-damage
├── feat/p2-auto-weapon
├── feat/p2-experience
├── feat/p3-level-up
└── feat/p4-game-ending
```

个人项目也建议每个较大任务使用功能分支，完成验证后合并。

## 13.2 提交粒度

所有提交信息一律使用中文；类型前缀保留英文小写，格式为 `type: 中文说明`。

推荐：

```text
feat: 新增强类型角色定义
feat: 新增归一化玩家移动
feat: 新增敌人环形生成
fix: 修复子弹重复命中
refactor: 将伤害逻辑抽取到生命组件
docs: 标记阶段二战斗循环完成
```

不推荐：

```text
update files
game changes
fix stuff
final version
p2完成
```

## 13.3 任务状态

`docs/TASKS.md` 是当前唯一任务清单。每完成一项，Codex 应：

1. 标记完成；
2. 写明验证方式；
3. 更新 `docs/CHANGELOG.md`；
4. 提交独立 Git commit；
5. 不自动开始下一阶段。

## 13.4 `.gitignore`

至少包含：

```gitignore
.godot/
.import/
export/
build/
dist/
logs/
.DS_Store
*.tmp
*.log
.vscode/
.idea/
```

是否提交 `.vscode/` 可由用户后续决定；默认不提交个人编辑器配置。

---

# 14. 测试策略

## 14.1 第一版测试层次

### 解析检查

确保所有脚本和场景能被 Godot 正确加载。

### 启动烟雾测试

项目主场景能启动，不立即报错或退出。

### 功能烟雾测试

创建简单测试场景验证：

- 生命值只死亡一次；
- 子弹造成一次伤害；
- 穿透计数正确；
- 经验只拾取一次；
- 升级选项不重复；
- 重开清空状态。

### 手动游玩测试

每阶段按验收清单运行。

## 14.2 验证脚本

`tools/validate_project.sh` 可采用：

```bash
#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"

"$GODOT_BIN" --version
"$GODOT_BIN" --headless --path . --editor --quit
```

Mac 上若命令不可用，可通过环境变量指定：

```bash
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot" \
  ./tools/validate_project.sh
```

Codex 不得假定用户安装路径固定，执行失败时应报告实际错误。

---

# 15. Codex 每次任务的标准流程

## 15.1 开始前

Codex 必须：

1. 阅读 `AGENTS.md`；
2. 阅读本说明书；
3. 阅读 `docs/TASKS.md`；
4. 查看 Git 状态；
5. 查看相关目录和已有实现；
6. 确定当前任务和验收标准。

## 15.2 实现中

- 先实现最小可运行版本；
- 保持接口清晰；
- 不修改共享 Resource；
- 不复制已有逻辑；
- 不引入无关依赖；
- 每个关键步骤后检查错误；
- 若发现现有问题影响任务，先最小修复并说明。

## 15.3 完成后

最终回复格式：

```text
完成内容
- ...

修改文件
- path/to/file.gd：...
- path/to/file.tscn：...

验证
- 执行命令：...
- 手动检查：...
- 结果：...

已知问题
- ...

建议下一步
- ...
```

---

# 16. 首次交给 Codex 的推荐指令

将本文件和 `AGENTS.md` 放进空项目根目录后，向 Codex发送：

```text
请先阅读项目根目录的 AGENTS.md、docs/PROJECT_SPEC.md 和 docs/TASKS.md。

现在只执行阶段一中的 P1-01“项目初始化”，不要实现玩家、敌人或战斗功能。

要求：
1. 创建 Godot 4.7.1 项目的基础目录和 project.godot。
2. 设置 1280×720 和合理的 2D 拉伸配置。
3. 配置 WASD 与方向键的 move_up、move_down、move_left、move_right。
4. 创建主场景和最小 GameSession 空场景，使项目可以直接运行。
5. 创建 .gitignore、README.md、docs/CHANGELOG.md。
6. 使用简单占位资源，不依赖外部下载。
7. 执行可用的 Godot 解析或启动验证。
8. 更新 docs/TASKS.md，只标记 P1-01。
9. 最后列出修改文件、验证结果和已知问题。

不要自动开始 P1-02。
```

完成后，依次给 Codex 下发：

```text
按照 AGENTS.md 和 PROJECT_SPEC.md，只完成 P1-02。
```

```text
按照 AGENTS.md 和 PROJECT_SPEC.md，只完成 P1-03。
```

```text
按照 AGENTS.md 和 PROJECT_SPEC.md，只完成 P1-04。
```

每个任务验收通过后再进入下一任务。

---

# 17. 最终完成定义

只有同时满足以下条件，才能宣布 Demo 完成：

- 项目在 Godot 4.7.1 中无解析错误；
- 主场景可直接运行；
- 玩家可移动；
- 敌人可生成和追踪；
- 自动攻击完整；
- 伤害和死亡正确；
- 经验与升级完整；
- 三选一可用；
- 两种普通敌人和一个 Boss 可用；
- 10 分钟流程完整；
- 胜负结算可用；
- 重新开始可用；
- 连续重开三次不残留旧状态；
- 配置是数据驱动的；
- 新增角色、敌人、武器和子弹不需要重写核心系统；
- 文档、任务和变更记录已更新；
- `main` 分支保持可运行。
