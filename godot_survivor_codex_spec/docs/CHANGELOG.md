# 变更记录

本项目的重要变更记录在此。

## [Unreleased]

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

### Fixed

- 敌人改为设置生成位置后再加入场景树，避免原点短暂碰撞配对导致玩家被物理恢复到远处。
- 接触 Hitbox 使用略大于实体碰撞体的范围，避免贴边抖动在一次持续接触中重复触发伤害。
- P1-04 稳定性测试使用独立运行时生命值隔离 P2 接触伤害，保持共享 `.tres` 不变。
- 玩家与敌人改用 Survivor-like 常见的非实体阻挡方案，并切换为俯视角 `MOTION_MODE_FLOATING`，避免接触后持续贴边锁定玩家。

### Verified

- 阶段一 P1-01 至 P1-04 通过代码审查、Godot 4.7.1 解析与启动检查、四项功能烟雾测试和 120 秒稳定性测试。
- P2-01 通过 Godot 4.7.1 解析、300 帧启动、生命与伤害专项测试及阶段一快速回归；玩家和敌人死亡信号均验证为单次触发。
