# Godot Survivor Demo

使用 Godot 4.7.1 和 GDScript 分阶段开发的 2D 俯视角 Survivor-like 最小 Demo。阶段一已验收：可控制玩家在基础场地内移动，数据驱动的基础敌人会在屏幕外持续生成并追踪玩家。

## 环境

- Godot 4.7.1 stable
- 基准分辨率：1280 × 720
- 渲染器：GL Compatibility

## 运行

1. 用 Godot 4.7.1 打开本目录中的 `project.godot`。
2. 点击“运行项目”或按 `F5`。

也可从命令行启动：

```bash
/path/to/Godot --path .
```

## 输入

| 动作 | 按键 |
|---|---|
| 向上 | `W` / 上方向键 |
| 向下 | `S` / 下方向键 |
| 向左 | `A` / 左方向键 |
| 向右 | `D` / 右方向键 |

玩家支持八方向移动，斜向输入会归一化，不会比水平或垂直移动更快。

当前约每秒生成一个敌人，场上敌人数上限为 30；生命值、伤害和死亡属于阶段二。

## 开发文档

- `AGENTS.md`：Codex 工作约束。
- `docs/PROJECT_SPEC.md`：产品、架构、接口、目录和验收规范。
- `docs/TASKS.md`：分阶段任务清单与验证记录。
- `docs/CHANGELOG.md`：已完成变更。
- `CODEX_FIRST_PROMPT.md`：项目初始化指令留档。

详细要求以 `docs/PROJECT_SPEC.md` 为准。
