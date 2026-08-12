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

接触阻挡修复记录：

```text
日期：2026-07-18
原因：玩家和敌人双向实体碰撞，敌人又在每个物理帧持续朝玩家中心移动，move_and_slide() 的贴边滑动使敌人持续压住玩家。
修复：PlayerBody 与 EnemyBody 仅保留识别层，双方实体碰撞掩码只检测 World；接触伤害继续由 ContactHitbox/Hurtbox 处理；双方使用俯视角 MOTION_MODE_FLOATING。
验收：专项测试确认敌人接触仍只造成一次伤害，玩家持续移动 36 个物理帧后可移动超过 100 像素，并与敌人拉开超过 56 像素。
```

### P2-02 索敌

- [x] 创建 TargetingService
- [x] 支持最近敌人查询
- [x] 支持范围限制
- [x] 固定间隔刷新
- [x] 无效目标自动过滤

验证记录：

```text
日期：2026-07-19
代码审查：TargetingService 由 GameSession 注入 Enemies 容器，每 0.1 秒只遍历该容器的直接子 Actor 并缓存候选；查询只遍历缓存，不搜索场景树，也不保存武器或 Resource 运行时状态。
执行命令：/Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/targeting_service_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/input_map_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/player_movement_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_tracking_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_spawner_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/health_damage_smoke_test.gd
手动验收：创建距离原点 100、220、520 像素的受控敌人，验证 300 范围返回 100 像素目标、50 范围无目标、player 阵营无目标；新增 60 像素目标后验证刷新前不进入缓存、0.15 秒后成为最近目标；再依次验证死亡、queue_free、stop 和候选容器离树。
结果：最近目标、范围、阵营、固定间隔刷新均正确；死亡或已释放目标在下一次定时刷新前也不会被返回；容器离树后 Timer 停止且引用清空；解析、300 帧启动和 P1/P2-01 快速回归全部通过。
修复：内部失效对象校验先接收 Variant，再在 is_instance_valid() 后转换 ActorBase，避免强类型参数在方法体执行前拒绝已释放对象；查询时同步清除失效缓存。
已知问题：未执行 GUI 窗口人工游玩；P2-03 尚无 WeaponController 消费索敌结果，因此当前无可视化自动攻击表现。
```

### P2-03 自动武器

- [x] 创建 WeaponDefinition
- [x] 创建 WeaponController
- [x] 默认武器配置
- [x] 自动攻击最近敌人
- [x] 运行时状态与 Resource 分离

验证记录：

```text
日期：2026-08-12
实现：新增强类型 WeaponDefinition 和 starter_weapon.tres；CharacterDefinition 使用 Array[WeaponDefinition] 配置起始武器；PlayerActor 为每个配置创建独立 WeaponController，并由 GameSession 注入 Projectiles 容器和 TargetingService。
执行命令：/Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/weapon_definition_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/weapon_controller_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/automatic_weapon_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/targeting_service_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/health_damage_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/input_map_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/player_movement_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_tracking_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_spawner_smoke_test.gd
分步验收：先验证默认 Resource 的强类型引用与约 1 秒冷却；再验证手动发射请求、冷却、失败请求、运行时修正、重置和所属 Actor 离树；最后验证无目标不请求、900 射程过滤、最近目标、0.4 秒内不重复、约 1.1 秒后再次请求，以及同一玩家两个控制器状态相互独立。
结果：三个 P2-03 专项测试、解析、300 帧启动及 P1/P2-01/P2-02 快速回归全部通过；自动武器只发布 P2-04 可消费的 fire_requested，不提前创建子弹节点。
修复：首次 Resource 测试发现 player_default.tres 的强类型数组误引用 CharacterDefinition 脚本，已改为显式 WeaponDefinition 类型并增加越界保护；重试后解析输出无错误。
已知问题：未执行 GUI 窗口人工游玩；P2-04 尚未实现 ProjectileDefinition 和 ProjectileBase，因此当前只有自动发射请求，没有可见子弹或实际远程伤害。
```

### P2-04 子弹

- [x] 创建 ProjectileDefinition
- [x] 创建 ProjectileSpawnContext
- [x] 创建 ProjectileBase
- [x] 实现直线移动
- [x] 实现伤害
- [x] 实现生命周期
- [x] 保留穿透接口
- [x] 防止重复命中

验证记录：

```text
日期：2026-08-12
实现：新增强类型 ProjectileDefinition、basic_projectile.tres、ProjectileSpawnContext 和 ProjectileBase；默认子弹为 10 伤害、600 速度、2 秒寿命、8 像素命中半径、pierce_count=0。WeaponController 按运行时弹数和总扩散角实例化子弹到注入的 Projectiles 容器。
执行命令：/Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 1800
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/projectile_definition_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/projectile_base_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/projectile_weapon_integration_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/weapon_definition_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/weapon_controller_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/automatic_weapon_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/targeting_service_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/health_damage_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/input_map_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/player_movement_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_tracking_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/enemy_spawner_smoke_test.gd
分步验收：先验证默认子弹 Resource 和 SpawnContext；再验证直线位移、伤害倍率、默认一次命中、pierce_count=1 命中两个目标、同物理帧同目标去重、寿命超时与重置；最后验证自动武器实际生成、物理命中击杀、命中后释放、运行时三发与 -10/0/10 度扩散。
结果：三个 P2-04 专项测试、解析、300 帧启动及 P1 至 P2-03 快速回归全部通过；共享武器与子弹 `.tres` 未保存单局运行状态。
修复：ProjectileBase 在 Area 查询回调中延迟关闭 monitoring，避免物理服务器状态修改错误；发射者离树时清空来源引用但保留阵营和飞行；旧索敌、生命和刷怪测试显式停用自动武器，避免新战斗逻辑污染专项测试。
已知问题：未执行 GUI 窗口人工游玩；当前没有伤害数字或 HUD；P2-05 经验掉落与拾取尚未实现。
```

攻击范围前置设计记录：

```text
日期：2026-08-12
实现：CharacterDefinition 新增 base_attack_range，默认玩家为 1000；WeaponDefinition.target_range 保持武器独立射程，默认武器为 900；WeaponController.get_effective_target_range() 取角色当前攻击范围与武器射程的较小值，并将结果用于 TargetingService 查询。
执行命令：/Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/attack_range_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/weapon_definition_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/automatic_weapon_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/projectile_weapon_integration_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/targeting_service_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/player_movement_smoke_test.gd
专项验收：角色范围 320 时排除 350 像素目标并攻击 250 像素目标；角色范围 1000、武器射程 180 时排除 200 像素目标并攻击 150 像素目标；共享角色和武器 Resource 均保持原值。
结果：角色与武器可以分别数据驱动有效索敌范围，解析、300 帧启动、专项测试和战斗/移动快速回归全部通过；本记录不改变 P2-05 状态。
已知问题：当前没有攻击范围可视化；范围只约束索敌，弹体实际可达距离仍由速度和生命周期决定。
```

### P2-05 经验

- [x] 创建经验宝石
- [x] 敌人死亡掉落
- [x] 玩家拾取范围
- [x] 经验只结算一次
- [x] UI 可监听经验变化

验证记录：

```text
日期：2026-08-12
实现：新增 PickupComponent 和 ExperienceGem；玩家从 CharacterDefinition.pickup_radius 初始化拾取范围，并通过 experience_changed(current_experience, gained_amount) 发布本局经验变化。GameSession 监听 EnemySpawner.enemy_spawned，为每个敌人连接单次 actor_died，并从 EnemyDefinition.experience_value 在死亡位置生成宝石。
执行命令：/Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/experience_gem_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/experience_flow_smoke_test.gd
          /Users/taochenhui/codesource/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke/projectile_definition_smoke_test.gd
          以及 tests/smoke 下除 120 秒 soak 外的全部快速烟雾测试
分步验收：先验证 96 像素真实 Area 拾取、经验累加、信号参数、重复 collect 拒绝和共享 Resource 隔离；再验证敌人死亡位置、单次掉落与自动拾取；最后连续执行 100 次生成、击杀、掉落和拾取，经验与信号均为 101 次，Enemies 与 Pickups 容器最终均为 0。
结果：解析、300 帧启动、两个 P2-05 专项测试、第二种 ProjectileDefinition 和全部快速回归通过；阶段二功能验收通过。
修复：首次集成测试为瞬移后的物理重叠刷新增加明确物理帧等待；完整回归发现子弹 Area 回调内死亡时立即添加宝石会在物理查询刷新期间启用形状，已将宝石入树延迟到安全时机，重试后无错误或重复警告。
已知问题：未执行 GUI 窗口人工游玩；当前只累计经验，不计算等级或经验阈值，属于 P3-01。
```

阶段二验收：

- [x] 自动攻击完整
- [x] 敌人可被击杀
- [x] 掉落和拾取完整
- [x] 连续击杀 100 个敌人无明显错误
- [x] 可通过新 Resource 创建第二种子弹

---

## 阶段 3：成长系统

### P3-01 等级与经验

- [x] 玩家运行时状态
- [x] 经验阈值方法
- [x] 升级信号
- [x] 支持连续升级
- [x] HUD 等级和经验条

### P3-02 升级系统

- [x] 创建 UpgradeDefinition
- [x] 创建 UpgradeSystem
- [x] 随机无重复三选一
- [x] 最大层数过滤
- [x] 权重字段预留

### P3-03 升级 UI

- [x] LevelUpPanel
- [x] 升级时暂停
- [x] UI 暂停时可操作
- [x] 防止重复点击
- [x] 选择后恢复

### P3-04 属性修正

- [x] 伤害升级
- [x] 攻速升级
- [x] 子弹数量升级
- [x] 移速升级
- [x] 最大生命升级
- [x] 治疗升级
- [x] 不修改共享 Resource

阶段三验收：

- [x] 拾取经验可升级
- [x] 三选一无重复
- [x] 强化效果生效
- [x] 连续升级不丢失
- [x] UI 不承担规则逻辑

验证记录：

```text
日期：2026-08-12
实现：PlayerActor 新增本局累计经验、等级内经验、等级阈值、待升级队列、升级栈与运行时属性修正；经验曲线统一为 required_xp(level) = 5 + level × 3。新增 UpgradeDefinition、UpgradeSystem、六种升级 Resource、HUD 和 LevelUpPanel；GameSession 串行消费待升级次数并统一暂停/恢复，UI 只展示选项和提交选择。
执行命令：D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --editor --quit
          D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 300
          D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/smoke/level_progression_smoke_test.gd
          D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/smoke/upgrade_system_smoke_test.gd
          D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/smoke/level_up_flow_smoke_test.gd
          以及 tests/smoke 下除 120 秒 soak 外的全部快速烟雾测试
分步验收：验证一级阈值、跨两级经验溢出与待选择队列；验证随机三选一无重复、最大层数过滤、重复提交拒绝；验证暂停态按钮可操作、连续两次选择和结束恢复；验证伤害、攻速、弹数、移速、最大生命与治疗效果，并核对共享角色和武器 Resource 原值不变。
结果：Godot 4.7.1 解析、主场景 300 帧启动、三个阶段三专项测试及阶段一至阶段二全部快速回归通过；阶段三所有验收项完成。
修复：P2-05 连续拾取测试在阶段三接入后会被升级暂停阻断，测试改为自动提交升级以保持原有 100 次掉落拾取覆盖；升级属性测试重置随机选择造成的状态后再做精确数值断言。
已知问题：未执行 GUI 窗口人工游玩；Windows headless 每次启动会报告系统根证书库读取错误，但不影响项目解析、运行或测试退出码；升级权重字段已预留，第一版仍采用均匀随机。
```

阶段三验收前可视性调整：

```text
日期：2026-08-12
实现：CharacterDefinition 新增可编辑 camera_zoom，默认 0.75，以扩大玩家可见世界范围；GameSession 新增可编辑 ui_scale，默认 1.3，统一放大 HUD 字体、进度条以及升级面板标题、边距和按钮。两项设置互不影响，屏幕外刷怪继续根据 Camera2D 实际 zoom 计算可见范围。
验证：Godot 4.7.1 解析、玩家移动/摄像机、敌人屏幕外生成、升级暂停 UI 专项测试全部通过。
已知问题：参数通过 Godot Inspector 调节，修改后需重新启动当前运行场景才能完整应用。
```

---

## 阶段 4：完整 Demo

### P4-01 游戏计时

- [x] GameSession 唯一维护时间
- [x] 5 分钟倒计时
- [x] 暂停时停止计时
- [x] HUD 显示时间

### P4-02 难度导演

- [x] DifficultyDirector
- [x] 分段生成配置
- [x] 生成速度增长
- [x] 敌人倍率增长
- [x] 最大敌人数控制

### P4-03 敌人类型

- [x] 基础敌人
- [x] 快速敌人
- [x] 通过 Resource 区分
- [x] 不复制基础行为代码

### P4-04 Boss

- [x] Boss 场景
- [x] Boss Resource
- [x] 5 分钟只生成一次
- [x] Boss 死亡通知 GameSession

### P4-05 结算与重开

- [x] 玩家死亡失败
- [x] Boss 死亡胜利
- [x] EndPanel
- [x] 显示时间、等级、击杀
- [x] 重新开始
- [x] 清空全部单局状态
- [x] 连续重开三次测试

最终验收：

- [x] 可完整游玩一局
- [x] 胜利流程完整
- [x] 失败流程完整
- [x] 重开无残留
- [ ] macOS 上稳定运行
- [x] 文档与变更记录完整
- [x] `main` 分支可运行

验证记录：

```text
日期：2026-08-12
实现：GameSession 唯一维护 300 秒经过时间、剩余时间、击杀数、Boss 状态和结算状态；HUD 显示倒计时。新增 RunDefinition、DifficultyStage 与 DifficultyDirector，默认按 0:00、1:00、2:30、4:00 四段提高生成频率、批量、敌人倍率和数量上限。新增快速敌人和 Boss 的独立场景/Resource，二者复用 EnemyActor、HealthComponent、HurtboxComponent 和 HitboxComponent。5:00 停止普通生成并只生成一次 Boss；玩家死亡失败、Boss 死亡胜利。EndPanel 显示存活时间、等级、击杀并通过重新加载当前场景重开。
执行命令：D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --editor --quit
          D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 300
          D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/smoke/difficulty_director_smoke_test.gd
          D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/smoke/difficulty_density_smoke_test.gd
          D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/smoke/boss_victory_smoke_test.gd
          D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/smoke/ending_restart_smoke_test.gd
          D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/smoke/enemy_spawner_soak_test.gd
          以及 tests/smoke 下全部 22 项快速烟雾测试
分步验收：验证 5:00 权威倒计时与暂停停止；验证四段难度、2:30 混合敌人池、4:00 三只一批和 140 动态上限；验证实例生命/移速/伤害倍率且共享 Resource 不变；验证 Boss 独立场景、单次生成、死亡胜利；验证玩家死亡失败、统计显示和连续重开三次无旧节点 ID、等级、经验、计时、击杀、Boss 或 UI 状态残留。
结果：Godot 4.7.1 解析与 300 帧启动通过；阶段一至阶段四 22 项快速测试全部通过；基础生成器 120 秒测试在四个采样点均稳定为 30；第四阶段快速压力测试稳定在 140 个敌人上限。
修复：EnemySpawner 初始化顺序调整为先建立基础敌人运行时池再校验依赖；旧 P1-04 soak 固定关闭阶段四时间推进，避免把动态上限增长误判为基础生成器泄漏，并新增独立高密度压力测试覆盖阶段四动态上限。
已知问题：未执行 GUI 窗口完整 5 分钟人工游玩；当前 Windows headless 会报告系统根证书库读取警告，但不影响项目解析、运行或测试退出码；macOS 稳定性仍需在目标机器验收。
```

---

## 阶段四后体验扩展：受伤反馈与进阶升级

- [x] 玩家与全部敌人复用视觉受伤反馈
- [x] 受伤时播放运行时合成音效
- [x] 每层 15% 概率额外发射一颗子弹
- [x] 子弹按实际伤害提供每层 3% 吸血
- [x] 每层扩大 25% 经验拾取半径
- [x] 升级通过 `UpgradeDefinition` Resource 加入随机池
- [x] 运行时效果不回写共享 Resource
- [x] 新增专项测试并完成全部快速回归
- [x] 敌人受伤仅保留视觉反馈，不误播玩家受伤音
- [x] 每层 15% 概率在一次发射间隔内追加一颗延迟子弹

验证记录：

```text
日期：2026-08-12
实现：新增 DamageFeedbackComponent，并组合到玩家、基础敌人、快速敌人和 Boss 场景；HealthComponent.damaged 统一触发红色闪烁、缩放位移和 0.09 秒运行时合成音效。UpgradeDefinition 新增额外子弹概率、子弹吸血、拾取范围倍率三类效果及对应 Resource。WeaponController 独立维护每局概率与吸血状态；额外子弹每次发射只进行一次概率判定，命中吸血按目标实际损失生命结算。PlayerActor 独立维护拾取倍率并刷新 PickupComponent 的运行时 Shape。
执行命令：D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --editor --quit
          D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 300
          D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/smoke/damage_feedback_smoke_test.gd
          D:\code\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/smoke/advanced_upgrade_smoke_test.gd
          以及 tests/smoke 下除 120 秒 soak 外的全部 24 项快速烟雾测试
分步验收：验证受伤信号只触发一次、视觉立即变化并在 0.14 秒恢复、玩家和敌人共享合成音频流；以 100% 测试概率确认每轮多生成一颗子弹；验证吸血只按实际伤害治疗；验证拾取半径和独立运行时碰撞 Shape 同步扩大；核对角色、武器和升级共享 Resource 未被回写。
结果：Godot 4.7.1 解析、主场景 300 帧启动和全部 24 项快速烟雾测试通过，未发现新增解析错误、重复警告或对象泄漏。
已知问题：未执行 GUI 窗口人工听感和手感验收；Windows headless 每次启动会报告系统根证书库读取错误，但不影响项目解析、运行或测试退出码；运行时合成音效当前为统一占位命中音，后续有正式音频素材时可直接替换组件的音频流生成方式。
```

补充修正与验收：

```text
日期：2026-08-12
修正：DamageFeedbackComponent 新增 play_sound 配置，玩家保持开启，基础敌人、快速敌人和 Boss 关闭；敌人继续闪红和抖动，但子弹命中敌人不再播放玩家受伤音。
扩展：新增“追加射击”UpgradeDefinition Resource，每层增加 15% 概率；命中概率时在当前有效冷却的 35% 时间点追加一颗子弹。追加弹继承当前伤害与吸血，不消耗或重置冷却，也不会递归触发下一次追加射击。该效果与“幸运射击”的同波额外弹数独立叠加。
验证：Godot 4.7.1 编辑器解析、主场景 300 帧启动、受伤反馈专项、进阶升级专项和全部 24 项快速烟雾测试通过；失败 0，对象泄漏 0。
已知问题：尚未进行 GUI 人工听感与追加射击节奏验收；Windows headless 仍有系统根证书库读取错误，不影响退出码和游戏逻辑。
```
