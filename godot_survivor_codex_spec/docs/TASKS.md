# 开发任务清单

> 规则：Codex 每次只完成用户明确指定的一个任务。完成后填写验证结果，不自动进入下一任务。

## 阶段 0：准备

- [ ] P0-01 安装并确认 Godot 4.7.1 stable
- [ ] P0-02 创建 Git 仓库
- [ ] P0-03 将 `AGENTS.md` 和 `docs/PROJECT_SPEC.md` 放入仓库
- [ ] P0-04 确认 Codex 可以读取项目目录

---

## 阶段 1：基础运行

### P1-01 项目初始化

- [x] 创建 `project.godot`
- [x] 设置主场景
- [x] 设置 1280 × 720
- [x] 配置 2D 拉伸
- [x] 配置 WASD 和方向键
- [x] 创建标准目录
- [x] 创建占位资源
- [x] 创建 `.gitignore`
- [x] 创建 `README.md`
- [x] 创建 `docs/CHANGELOG.md`
- [x] 项目可以直接启动

验证记录：

```text
日期：2026-07-17
执行命令：/Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 2
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/input_map_smoke_test.gd
手动验证：核对主场景引用、GameSession 实例和六个 SVG 占位资源；未执行 GUI 游玩验收。
结果：Godot 4.7.1 导入、解析、InputMap 烟雾检查和主场景启动均成功，三条命令退出码均为 0，未出现错误或重复警告。
已知问题：当前为 P1-01 空场景，运行后只显示背景；玩家移动属于 P1-02。
```

### P1-02 玩家移动

- [x] 创建 `CharacterDefinition`
- [x] 创建默认玩家 Resource
- [x] 创建玩家场景
- [x] 实现八方向移动
- [x] 归一化斜向速度
- [x] 添加 Camera2D
- [x] 添加场地边界

验证记录：

```text
日期：2026-07-17
执行命令：/Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 4
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/player_movement_smoke_test.gd
手动验证：核对 CharacterDefinition、默认 Resource、玩家场景、碰撞层和 GameSession 注入路径；未执行 GUI 键盘操作验收。
结果：Godot 4.7.1 解析和主场景启动成功；烟雾测试确认斜向速度为 220、Camera2D 已激活、World 边界可阻挡玩家，所有命令退出码为 0。
已知问题：尚未进行 GUI 手动游玩验收；敌人功能属于 P1-03。
```

### P1-03 敌人追踪

- [x] 创建 `EnemyDefinition`
- [x] 创建通用 EnemyActor
- [x] 创建基础敌人 Resource
- [x] 敌人获得玩家引用
- [x] 敌人直接追踪玩家
- [x] 玩家无效时安全停止

验证记录：

```text
日期：2026-07-17
执行命令：/Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 30
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_tracking_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/player_movement_smoke_test.gd
手动验证：核对 EnemyDefinition、基础 Resource、敌人场景、碰撞层和 GameSession 注入路径；未执行 GUI 追踪验收。
结果：Godot 4.7.1 解析和主场景启动成功；烟雾测试确认敌人以 Resource 中的 80 速度追踪玩家，玩家离树后敌人立即停止，P1-02 移动回归通过。
已知问题：尚未进行 GUI 手动游玩验收；当前只创建一个固定位置敌人，持续生成属于 P1-04。
```

### P1-04 敌人生成

- [x] 创建 EnemySpawner
- [x] 屏幕外环形生成
- [x] 设置生成频率
- [x] 设置最大敌人数
- [x] 连续运行 2 分钟

验证记录：

```text
日期：2026-07-17
执行命令：/Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_spawner_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_tracking_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/player_movement_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_spawner_soak_test.gd
手动验证：核对 EnemySpawnSettings、EnemySpawner 公共接口、Timer 连接、GameSession 注入和生成容器；未执行 GUI 手动游玩验收。
结果：屏幕外环带生成、1 秒间隔、30 个数量上限和玩家离树停止均通过；120 秒测试在 30/60/90/120 秒均保持 30 个敌人，退出码为 0，无阻断性错误。
已知问题：尚未进行 GUI 手动游玩验收；敌人尚无生命值、伤害和死亡逻辑，属于阶段二。
```

阶段一验收：

- [x] 玩家可移动
- [x] 摄像机跟随
- [x] 敌人持续生成
- [x] 敌人追踪玩家
- [x] 无阻断性错误

阶段一验收记录：

```text
日期：2026-07-17
代码审查：确认 Input.get_vector() 归一化移动；敌人与生成器通过 initialize() 注入玩家；无每帧场景树搜索；玩家 tree_exiting 时敌人停止。
执行命令：/Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --version
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/input_map_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/player_movement_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_tracking_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_spawner_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_spawner_soak_test.gd
结果：Godot 4.7.1 解析和启动成功；WASD/方向键、220 斜向归一化速度、Camera2D、场地边界、屏幕外生成、80 速度追踪、30 个上限和玩家失效停止均通过。
稳定性：真实运行 120 秒，30/60/90/120 秒均为 30 个敌人，退出码为 0，无阻断性错误或节点无限增长。
修复：未发现需要修复的阶段一实现问题。
已知限制：本轮为 headless 自动验收，未在 GUI 窗口中进行人工键盘操作；阶段二功能仍全部未实现。
```

---

## 阶段 2：战斗循环

### P2-01 生命值与伤害

- [x] 创建 DamageEvent
- [x] 创建 HealthComponent
- [x] 创建 Hitbox/Hurtbox
- [x] 玩家和敌人复用组件
- [x] 死亡只触发一次

验证记录：

```text
日期：2026-07-17
代码审查：确认 PlayerActor 与 EnemyActor 复用 ActorBase、HealthComponent 和 HurtboxComponent；敌人 ContactHitbox 从 EnemyDefinition.contact_damage 初始化；运行时生命只保存在组件中，未回写共享 Resource。
执行命令：/Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/health_damage_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/input_map_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/player_movement_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_tracking_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_spawner_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_spawner_soak_test.gd
手动验收：按“玩家与敌人组件结构 → Resource 初始生命 → 物理接触一次扣血 → 治疗上下界 → 连续致命伤害 → 重置后复用”的顺序执行专项场景逻辑；另核对玩家、敌人场景实例与碰撞层连接。未执行 GUI 窗口人工游玩。
结果：解析与 300 帧启动成功；玩家和敌人共用组件，接触伤害使用 DamageEvent，生命保持在 0 至最大值内，死亡后忽略普通伤害，HealthComponent.died 与 ActorBase.actor_died 均只触发一次，重置可恢复复用状态；阶段一快速回归全部通过，120 秒生成测试在 30/60/90/120 秒均稳定为 30 个敌人。
修复：敌人改为入树前设置生成位置，避免原点临时物理配对导致玩家瞬移；ContactHitbox 范围略大于实体碰撞体，避免贴边抖动造成一次持续接触内重复伤害；稳定性测试仅提高本局玩家生命以隔离接触伤害，不修改共享 Resource。
已知问题：未执行 GUI 窗口人工游玩；P2-02 索敌及后续武器、子弹、经验功能未实现。
```

### P2-02 索敌

- [ ] 创建 TargetingService
- [ ] 支持最近敌人查询
- [ ] 支持范围限制
- [ ] 固定间隔刷新
- [ ] 无效目标自动过滤

### P2-03 自动武器

- [ ] 创建 WeaponDefinition
- [ ] 创建 WeaponController
- [ ] 默认武器配置
- [ ] 自动攻击最近敌人
- [ ] 运行时状态与 Resource 分离

### P2-04 子弹

- [ ] 创建 ProjectileDefinition
- [ ] 创建 ProjectileSpawnContext
- [ ] 创建 ProjectileBase
- [ ] 实现直线移动
- [ ] 实现伤害
- [ ] 实现生命周期
- [ ] 保留穿透接口
- [ ] 防止重复命中

### P2-05 经验

- [ ] 创建经验宝石
- [ ] 敌人死亡掉落
- [ ] 玩家拾取范围
- [ ] 经验只结算一次
- [ ] UI 可监听经验变化

阶段二验收：

- [ ] 自动攻击完整
- [ ] 敌人可被击杀
- [ ] 掉落和拾取完整
- [ ] 连续击杀 100 个敌人无明显错误
- [ ] 可通过新 Resource 创建第二种子弹

---

## 阶段 3：成长系统

### P3-01 等级与经验

- [ ] 玩家运行时状态
- [ ] 经验阈值方法
- [ ] 升级信号
- [ ] 支持连续升级
- [ ] HUD 等级和经验条

### P3-02 升级系统

- [ ] 创建 UpgradeDefinition
- [ ] 创建 UpgradeSystem
- [ ] 随机无重复三选一
- [ ] 最大层数过滤
- [ ] 权重字段预留

### P3-03 升级 UI

- [ ] LevelUpPanel
- [ ] 升级时暂停
- [ ] UI 暂停时可操作
- [ ] 防止重复点击
- [ ] 选择后恢复

### P3-04 属性修正

- [ ] 伤害升级
- [ ] 攻速升级
- [ ] 子弹数量升级
- [ ] 移速升级
- [ ] 最大生命升级
- [ ] 治疗升级
- [ ] 不修改共享 Resource

阶段三验收：

- [ ] 拾取经验可升级
- [ ] 三选一无重复
- [ ] 强化效果生效
- [ ] 连续升级不丢失
- [ ] UI 不承担规则逻辑

---

## 阶段 4：完整 Demo

### P4-01 游戏计时

- [ ] GameSession 唯一维护时间
- [ ] 5 分钟倒计时
- [ ] 暂停时停止计时
- [ ] HUD 显示时间

### P4-02 难度导演

- [ ] DifficultyDirector
- [ ] 分段生成配置
- [ ] 生成速度增长
- [ ] 敌人倍率增长
- [ ] 最大敌人数控制

### P4-03 敌人类型

- [ ] 基础敌人
- [ ] 快速敌人
- [ ] 通过 Resource 区分
- [ ] 不复制基础行为代码

### P4-04 Boss

- [ ] Boss 场景
- [ ] Boss Resource
- [ ] 5 分钟只生成一次
- [ ] Boss 死亡通知 GameSession

### P4-05 结算与重开

- [ ] 玩家死亡失败
- [ ] Boss 死亡胜利
- [ ] EndPanel
- [ ] 显示时间、等级、击杀
- [ ] 重新开始
- [ ] 清空全部单局状态
- [ ] 连续重开三次测试

最终验收：

- [ ] 可完整游玩一局
- [ ] 胜利流程完整
- [ ] 失败流程完整
- [ ] 重开无残留
- [ ] macOS 上稳定运行
- [ ] 文档与变更记录完整
- [ ] `main` 分支可运行
