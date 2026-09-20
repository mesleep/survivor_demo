# 可爱像素美术包

2026-09-20 使用内置 imagegen 生成，未下载或复制第三方素材。PNG 保留透明通道及原始生成信息；本说明不将生成内容冒称为第三方 CC0 素材。

## 内容

- `characters.png`：小吸血鬼、史莱姆、小蝙蝠、魔王，共 16 张动作帧。
- `effects.png`：月牙魔杖、魔法弹、经验水晶、星光爆发，共 16 张动作帧。星光爆发提供 `impact_frames.tres`，当前预留给后续命中特效。
- `data/visuals/`：只读 SpriteFrames / AtlasTexture 配置。生成图集排版并非严格等格，角色帧使用独立裁切范围与统一透明边距对齐。

角色移动使用四帧循环，停止使用第零帧，左右朝向镜像；上下移动共用三分之四视角运动帧。武器具有四帧充能/发射过程，随实际发射触发；移动时附加两像素轻微起伏。子弹与经验水晶各四帧循环。

贴图使用 nearest 过滤、关闭 mipmap。原始 PNG 无需外部生成服务即可直接运行。

## 生成提示词

模式：内置 imagegen（非 CLI/API）。以下为最终提示词。

### characters.png

Use case: stylized-concept. Create a production game sprite atlas PNG on genuinely transparent background, exact square canvas, 4 columns by 4 rows equal cells, no margins between cells, no text no grid. Each sprite stays centered inside its cell with generous transparent padding, consistent scale and foot baseline per row. Cute cozy gothic pixel art, chunky crisp square pixels, limited palette, dark plum outlines, no blur no antialiasing. All facing front/right three-quarter. Row 1: same adorable ivory-haired vampire adventurer in teal hood and short navy cape, peach face rosy cheeks big eyes brown boots, four distinct WALK CYCLE poses (left step, passing, right step, passing), hands empty. Row 2: same mint green round slime with tiny leaf on head, four distinct hopping/squash/stretch motion frames. Row 3: same lavender baby bat with peach ears, four distinct wing-flap poses, open/half/down/half. Row 4: same chubby plum vampire king with tiny gold crown red cape and little horns, four distinct stomping walk poses. Exactly 16 separate sprites. No shadows beyond silhouettes, no backdrop, true alpha. Each sprite occupies about 65 percent cell height and width. Original designs suitable for top-down survivor game. Save output for project use.

### effects.png

Use case: stylized-concept. Production game sprite sheet, true transparent alpha background, square canvas, EXACT 4 columns x 4 rows equal cells. Original cute gothic pixel art with chunky crisp square pixel clusters, dark plum outlines, teal ivory lilac gold colors, no text no grid no background. All objects centered and fully contained within central 65% of their cell with large empty padding so frames can be cut on exact grid. Row 1: four frames of the SAME small golden crescent moon magic wand pointing horizontally RIGHT: resting wand, charging teal crystal, bright star muzzle flash on right, cooling little spark. Keep handle stationary across frames. Row 2: four frames of a cyan magical projectile traveling RIGHT, glowing bright core at right and short pixel trail left, changes shape each frame. Row 3: four frames of a mint green experience crystal floating/spinning, alternating facet widths and tiny sparkle. Row 4: four frames of a golden star impact burst growing then fading. Exactly 16 objects. Frame-to-frame consistent sizes and positions. No floor shadows. Suitable as actual Godot 2D animated sprites matching cute vampire adventurer game.
