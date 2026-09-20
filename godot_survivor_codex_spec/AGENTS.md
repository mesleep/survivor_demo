# AGENTS.md

## 1. 项目目标

本仓库用于开发一个 Godot 4.7.1 + GDScript 的 2D 俯视角 Survivor-like 最小可玩 Demo，参考《吸血鬼幸存者》和《土豆兄弟》的基础循环。

核心循环：

`移动 → 自动攻击 → 击杀敌人 → 获取经验 → 升级三选一 → 敌人增强 → Boss/结算`

详细需求、架构和验收标准见：

- `docs/PROJECT_SPEC.md`
- `docs/TASKS.md`

开始工作前必须先阅读这三个文件。

---

## 2. Codex 工作规则

1. 每次只完成当前明确指定的阶段或任务，不得擅自实现后续阶段。
2. 修改前先检查现有目录、场景、脚本和 Git 状态，不要覆盖已有有效实现。
3. 始终保持项目可启动、可运行；禁止一次进行大范围不可验证重构。
4. 优先完成最小垂直功能切片，再补充细节。
5. 新增功能必须考虑可扩展性，但禁止为尚未出现的需求过度设计。
6. 角色、敌人、武器、子弹和升级配置必须数据驱动，优先使用自定义 `Resource`。
7. 可复用行为优先使用组件和组合，不通过复制脚本实现不同角色或敌人。
8. 模块之间优先通过信号、明确的方法和数据对象通信，避免跨场景硬编码节点路径。
9. 不要在多个脚本中重复维护同一份游戏状态。
10. 不要静默改变输入键位、碰撞层、目录规则、公共接口或数据格式。
11. 若必须做破坏性修改，先说明影响，并同步更新文档和所有调用方。
12. 禁止提交 `.godot/`、临时文件、日志、导出构建和系统文件。
13. 不引入第三方插件，除非任务明确要求。
14. 不生成复杂美术；无素材时使用项目内的占位 SVG、简单图形或默认字体。
15. 不修改与当前任务无关的文件。

---

## 3. 技术约束

- 引擎：Godot 4.7.1 stable
- 语言：GDScript
- 渲染：Godot 2D
- 基准分辨率：1280 × 720
- 目标帧率：60 FPS
- 代码必须尽量使用静态类型
- 可复用脚本使用 `class_name`
- 文件名、变量名、函数名使用 `snake_case`
- 类名、资源类型名使用 `PascalCase`
- 场景文件使用 `snake_case.tscn`
- 代码标识符使用英文
- 注释和开发文档使用中文

---

## 4. 架构原则

### 4.1 数据与行为分离

以下内容必须通过自定义 `Resource` 配置，而不是散落在节点脚本中：

- 角色基础属性
- 敌人基础属性
- 武器参数
- 子弹参数
- 升级选项
- 波次和难度参数

场景和节点负责运行时行为，Resource 负责可编辑数据。

### 4.2 组合优先

推荐组件：

- `HealthComponent`
- `HitboxComponent`
- `HurtboxComponent`
- `ExperienceComponent`
- `PickupComponent`
- `WeaponController`
- `StatusModifierComponent`

不同角色、敌人和武器通过“场景 + Resource + 组件组合”实现。

### 4.3 公共扩展接口

基础类必须保留清晰接口：

- Actor：`initialize(definition)`、`apply_damage(...)`、`die()`
- Weapon：`initialize(definition, owner_actor)`、`can_fire()`、`fire(target)`
- Projectile：`initialize(definition, context)`、`launch(direction)`、`on_hit(target)`
- Upgrade：`can_apply(context)`、`apply(context)`
- Enemy spawner：`spawn_enemy(definition, position)`
- Game session：`start_run()`、`end_run(result)`、`restart_run()`

GDScript 没有传统接口时，使用基类、约定方法和运行时校验实现。

---

## 5. 注释规则

公共基础类、自定义 Resource 和复杂算法必须包含文档注释：

```gdscript
## 负责管理角色生命值。
##
## 输入：最大生命值和伤害事件。
## 输出：health_changed、died 信号。
## 扩展点：护盾、减伤、持续伤害。
class_name HealthComponent
extends Node
```

函数注释重点说明：

- 为什么这样实现
- 输入和输出
- 边界条件
- 扩展点或性能影响

不要逐行翻译代码，不要保留大段注释掉的旧代码。

待办格式：

```gdscript
# TODO(P3): 支持带权重的升级选项池。
# FIXME: 对象回收后仍残留碰撞状态。
```

---

## 6. 验证要求

每次完成任务后：

1. 检查 GDScript 解析错误。
2. 启动主场景，确认无阻断性错误。
3. 按 `docs/TASKS.md` 执行当前任务的手动验收。
4. 检查 Godot Output 中是否出现新错误或重复警告。
5. 检查被修改的场景引用、信号连接和 Resource 路径。
6. 报告：
   - 完成内容
   - 修改文件
   - 验证结果
   - 已知问题
   - 下一步建议

可用时执行：

```bash
godot --headless --path . --editor --quit
```

若本机 Godot 命令名不是 `godot`，先定位实际可执行文件，不要猜测路径。

---

## 7. Git 规则

- `main` 必须保持可运行。
- 功能分支：`feat/p1-player-movement`
- 修复分支：`fix/projectile-collision`
- 重构分支：`refactor/combat-components`
- 每个提交只包含一个逻辑变更。
- 提交信息一律使用中文，类型前缀保留英文小写，格式为 `type: 中文说明`。
- 推荐提交格式：
  - `feat: 新增玩家移动`
  - `fix: 修复子弹复用时残留碰撞`
  - `refactor: 抽取生命组件`
  - `docs: 更新阶段二验收标准`
  - `test: 新增战斗冒烟场景`
- 不推荐：`update files`、`game changes`、`fix stuff`、`final version`、`p2完成` 等含糊或无类型前缀的信息。

完成一个可验证任务后再提交，不要提交无法启动的中间状态。
