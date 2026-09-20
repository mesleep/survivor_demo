# Godot Survivor Demo

使用 Godot 4.7.1 和 GDScript 分阶段开发的 2D 俯视角 Survivor-like 最小 Demo。四个开发阶段均已实现：玩家移动并自动攻击，击杀后拾取经验和三选一成长，敌人随时间增强，5 分钟后迎战 Boss，最终进入胜利或失败结算并可重新开始。

## 环境

- Godot 4.7.1 stable
- 基准分辨率：1280 × 720
- 渲染器：GL Compatibility

## 运行

1. 用 Godot 4.7.1 打开本目录中的 `project.godot`。
2. 点击“运行项目”或按 `F5`。

也可从命令行启动。下面路径均为**示例占位**，请替换为本机实际的 Godot 可执行文件路径：

macOS：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Windows（PowerShell 或 CMD，路径含空格时必须加引号）：

```powershell
"C:\Godot\Godot_v4.7.1-stable_win64.exe" --path .
```

Windows 若需要控制台输出，改用同目录下的 `Godot_v4.7.1-stable_win64_console.exe`。

提示：在 `project.godot` 所在目录执行时 `--path .` 即当前目录；不要在项目根目录之外运行。

## 输入

| 动作 | 按键 |
|---|---|
| 向上 | `W` / 上方向键 |
| 向下 | `S` / 下方向键 |
| 向左 | `A` / 左方向键 |
| 向右 | `D` / 右方向键 |
| 暂停 / 继续 | `Esc`（升级或结算时不能跳过） |
| 声音开关 | `M` |

玩家支持八方向移动，斜向输入会归一化，不会比水平或垂直移动更快。

开局约每秒生成一个基础敌人，随后按时间提高密度和强度，2 分 30 秒后加入快速敌人，5 分钟时停止普通生成并生成 Boss。HUD 显示生命、等级、经验和倒计时；升级和结算时游戏暂停。

玩家和敌人受伤时都会闪红并短促抖动；受伤音效只在玩家受到伤害时播放，攻击敌人不会误播玩家受伤音。升级池除基础属性外，还包含每层 15% 同波额外一颗子弹的“幸运射击”、每层 15% 在当前攻击间隔追加一颗延迟子弹的“追加射击”、每层 3% 实际伤害吸血，以及每层扩大 25% 经验拾取半径的升级。

开发时可在 `player_default.tres` 调整 `camera_zoom`（越小视野越大），在 `game_session.tscn` 的根节点调整 `ui_scale`（越大界面越大）。

## 开发文档

### 四宠庭院扩展

- 虎妞（小眼睛、绷脸）、黑豹（吐舌笑脸）、小四（白底狸花）、小七（深色虎斑）均使用四帧跑动图。两只猫从 2:30 的混合波次加入。
- 开局持有星光魔杖；升级三选一可获得飞叶刃、回旋骨棒、环绕铃铛，同时持有并自动攻击。
- 弹数升级现在可见扇形散射；穿透为独立选项。另外新增弹速、体积、暴击、自然恢复与三种武器专属强化。
- 庭院背景、循环芯片乐、发射/拾取/击退/升级/Boss/胜负音效均存放在项目内。新增素材文件名、界面与说明为中文，代码和 Resource 标识符保留英文命名规范。
- 完整素材清单与生成提示词见 `assets/素材说明.md`；验证与限制见 `docs/PET_PLAYTEST.md`。

- `AGENTS.md`：Codex 工作约束。
- `docs/PROJECT_SPEC.md`：产品、架构、接口、目录和验收规范。
- `docs/ARCHITECTURE.md`：当前实现的架构基线（as-built，含场景树、接口、数据流和碰撞层）。
- `docs/BASELINE.md`：项目基线快照（需求追踪、资源清单、测试矩阵、已知偏差）。
- `docs/TASKS.md`：分阶段任务清单与验证记录。
- `docs/CHANGELOG.md`：已完成变更。
- `CODEX_FIRST_PROMPT.md`：项目初始化指令留档。

详细要求以 `docs/PROJECT_SPEC.md` 为准；当前可交付状态以 `docs/BASELINE.md` 为准。

## 基线与提交约定

- 基线版本：`baseline-1.0`，对应提交 `447a787`（2026-09-20）。
- 变更前先更新 `docs/PROJECT_SPEC.md` 或 `docs/TASKS.md`，再实现、验证、更新 `docs/CHANGELOG.md`。
- 提交信息一律使用中文，类型前缀保留英文小写，格式为 `type: 中文说明`，例如 `docs: 新增架构与项目基线文档`。
