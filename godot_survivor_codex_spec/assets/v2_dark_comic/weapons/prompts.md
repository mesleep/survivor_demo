# 当前武器与战斗素材生成记录

本批使用 Codex 内置 image_gen；每项独立生成，均以统一画风基准图作为参考：
assets/v2_dark_comic/style/art_direction.png

下表中的项目文件路径均相对 assets/v2_dark_comic/。

生成原图保留在 CODEX_HOME 的 generated_images 目录。项目交付图按游戏尺寸缩小，使用 System.Drawing HighQualityBicubic 处理；不裁切，透明背景保留。叶刃原图为横向 2:1，因此交付为 256×128，避免拉伸变形。其余交付为 256×256。所有交付文件均检查为 RGBA，alpha 范围 0–255（含完全透明像素和完全不透明像素）。

| 文件 | 用途 | 原图尺寸 | 项目尺寸 | Alpha | 原图路径 |
| --- | --- | ---: | ---: | --- | --- |
| weapons/starlight_wand.png | 星光魔杖贴身武器视觉；静态帧可重复用于当前发射动画 | 1254×1254 | 256×256 | RGBA，0–255 | C:\Users\tch\.codex\generated_images\01a0d290-a523-7531-ac4c-b0d95600f323\exec-451fb168-b95e-4560-9c67-e27832219839.png |
| projectiles/starlight_bolt.png | 当前星光弹 | 1254×1254 | 256×256 | RGBA，0–255 | C:\Users\tch\.codex\generated_images\01a0d290-a523-7531-ac4c-b0d95600f323\exec-1287ef73-8342-42e6-b39c-e58038500da2.png |
| projectiles/leaf_blade.png | 飞叶刃；同一图供武器视觉与飞行弹体复用 | 1774×887 | 256×128 | RGBA，0–255 | C:\Users\tch\.codex\generated_images\01a0d290-a523-7531-ac4c-b0d95600f323\exec-a90492c6-f11b-4d5a-bd45-29a51437fd1b.png |
| projectiles/bone_returner.png | 回旋骨棒；同一图供武器视觉与回旋弹体复用 | 1254×1254 | 256×256 | RGBA，0–255 | C:\Users\tch\.codex\generated_images\01a0d290-a523-7531-ac4c-b0d95600f323\exec-fbef0e9d-3804-4899-9be9-9f57d9de111a.png |
| projectiles/orbit_bell.png | 环绕铃铛；同一图供武器视觉与环绕弹体复用 | 1254×1254 | 256×256 | RGBA，0–255 | C:\Users\tch\.codex\generated_images\01a0d290-a523-7531-ac4c-b0d95600f323\exec-c6447476-f7bb-47eb-b230-3db379b52f9e.png |
| pickups/experience_gem.png | 地面经验宝石及界面小图标 | 1254×1254 | 256×256 | RGBA，0–255 | C:\Users\tch\.codex\generated_images\01a0d290-a523-7531-ac4c-b0d95600f323\exec-8fa941cd-4d12-4b17-b728-76c5f999a3ca.png |
| fx/hit_spark.png | 紧凑的通用命中特效静帧 | 1254×1254 | 256×256 | RGBA，0–255 | C:\Users\tch\.codex\generated_images\01a0d290-a523-7531-ac4c-b0d95600f323\exec-0a55e621-db59-4b43-b500-43b990d0653a.png |

## 星光魔杖

文件：assets/v2_dark_comic/weapons/starlight_wand.png
尺寸：原图 1254×1254；项目版 256×256。RGBA alpha 0–255。
用途：当前星光魔杖的贴身武器视觉；项目代码可将静帧重复用于 SpriteFrames。

**完整提示词**

> Use case: stylized-concept
> Asset type: single standalone 2D game sprite, star wand visual attached beside a small wizard in a top-down survivor game
> Input images: Image 1 is the approved style reference; match its dark comic fantasy linework, cel-shaded color blocks, deep navy atmosphere, cool moonlit edges, amber-gold light and small scarlet accents. Do not reproduce its character, scene, or layout.
> Primary request: Create one original star-tipped magic wand, viewed from a three-quarter top-down game angle, pointing to the right. Match the reference board's simple golden star wand motif: a clean five-point amber-gold star head, slender dark bronze shaft, deep teal and muted gold grip details, a tiny restrained red accent gem. Keep the recognizable silhouette bold and readable when reduced to roughly 40 game pixels.
> Composition/framing: One complete object, diagonal from lower-left grip to upper-right star, centered and occupying about 70% of a square canvas; generous transparent padding, no crop.
> Lighting/mood: Cold moonlit rim along the lower edge; warm amber-gold core glow only around the star.
> Materials/textures: Crisp hand-painted comic illustration, thick dark plum outline, hard cel-shaded facets, restrained engraved detail.
> Constraints: Request a genuinely transparent background with real alpha; no floor, no cast shadow, no characters or hands, no projectile, no text, no grid, no checkerboard, no watermark. A single isolated sprite, not a sheet.

## 星光弹

文件：assets/v2_dark_comic/projectiles/starlight_bolt.png
尺寸：原图 1254×1254；项目版 256×256。RGBA alpha 0–255。
用途：当前基础星光弹；方向朝右，可由游戏旋转。

**完整提示词**

> Use case: stylized-concept
> Asset type: one standalone 2D projectile sprite for a top-down survivor game
> Input images: Image 1 is the approved style reference. Match its dark comic fantasy ink outline, clean cel-shaded blocks, cold moonlight highlights, amber-gold magic and restrained scarlet accents. Do not reproduce its character or environment.
> Primary request: A single star-light magical bolt flying to the right: a sharp small amber-gold five-point star core, bright ivory center, short tapered blue-white moonlit comet tail with two or three tiny gold sparks. Make it read clearly as a fast simple projectile when displayed at about 25 game pixels.
> Composition/framing: One isolated right-facing projectile centered on a square canvas, approximately 65% of canvas width, leave generous transparent padding; do not crop the tail or star.
> Style/medium: crisp 2D comic game sprite, bold dark plum outer contour, hard cel-shaded color planes, limited internal detail.
> Lighting/mood: luminous warm center against cool blue-white edge light.
> Constraints: genuinely transparent background with real alpha; no cast shadow, no wand, no character, no impact burst, no text, no grid, no checkerboard, no watermark. Single sprite, not a sheet.

## 飞叶刃

文件：assets/v2_dark_comic/projectiles/leaf_blade.png
尺寸：原图 1774×887；项目版 256×128。RGBA alpha 0–255；保持原图 2:1 比例。
用途：当前飞叶刃武器视觉与飞行弹体共用图。

**完整提示词**

> Use case: stylized-concept
> Asset type: single reusable weapon and flying projectile sprite for a top-down survivor game
> Input images: Image 1 is the approved style reference. Match the dark comic fantasy ink contours, hard cel-shaded planes, cold blue moonlight and restrained amber-gold/scarlet accents; do not reproduce its characters or setting.
> Primary request: One original leaf-shaped throwing blade, pointed to the right. Its body is a broad elegant dark jade leaf with a sharp gold-edged blade contour, a pale mint central vein, small amber vein details, and a tiny red-gold star glint at the base. It must read as both a light thrown weapon beside a character and a flying leaf projectile when reduced to game size.
> Composition/framing: One complete horizontal right-facing object, centered, occupying 75–85% of canvas width, isolated with transparent padding; no crop.
> Style/medium: crisp 2D dark-comic fantasy game illustration, strong dark plum outline, simple readable cel-shaded shapes, high contrast.
> Lighting/mood: cool moonlit edge on one side and a few restrained warm gold highlights.
> Constraints: genuine transparent background with real alpha; no hand, no character, no separate motion trail, no impact burst, no cast shadow, no text, no grid, no checkerboard, no watermark. One sprite only, not a sheet.

## 回旋骨棒

文件：assets/v2_dark_comic/projectiles/bone_returner.png
尺寸：原图 1254×1254；项目版 256×256。RGBA alpha 0–255。
用途：当前回旋骨棒武器视觉与回旋弹体共用图；旋转由游戏处理。

**完整提示词**

> Use case: stylized-concept
> Asset type: one reusable weapon and returning projectile sprite for a top-down survivor game
> Input images: Image 1 is the approved style reference; match its bold dark-comic outline, cel-shaded blocks, moonlit cool edge and restrained amber-gold/red accents without copying its scene or characters.
> Primary request: One original spinning bone club/boomerang, pointing right and tilted slightly upward. Use an unmistakable ivory femur silhouette with a thicker rounded knuckle head and two lobes at the handle end; wrap its center with two slim amber-gold bands and a tiny dark crimson rune inset. Keep it compact and chunky, readable when displayed small, with bone-white facets and blue moonlit shadows.
> Composition/framing: One complete isolated object, centered and filling 75–85% of a square canvas, diagonal from lower-left to upper-right; preserve transparent padding around all ends.
> Style/medium: crisp illustrated game sprite, dark plum ink outline, hard simple cel-shaded facets, limited fine detail.
> Lighting/mood: cool moonlight rim, warm gold bands.
> Constraints: genuinely transparent background with real alpha; no hand or character, no rotation duplicates, no motion trail or circle, no impact burst, no cast shadow, no text, no grid, no checkerboard, no watermark. Single sprite only, not a sheet.

## 环绕铃铛

文件：assets/v2_dark_comic/projectiles/orbit_bell.png
尺寸：原图 1254×1254；项目版 256×256。RGBA alpha 0–255。
用途：当前环绕铃铛武器视觉与环绕弹体共用图；环绕轨迹由游戏处理。

**完整提示词**

> Use case: stylized-concept
> Asset type: one reusable orbiting weapon and projectile sprite for a top-down survivor game
> Input images: Image 1 is the approved style reference; match its dark comic fantasy silhouette, bold plum outline, crisp cel shading, cold blue moonlight and amber-gold with a restrained red accent. Do not copy characters or setting.
> Primary request: One original magical cat bell, viewed from a three-quarter top-down angle. Make a rounded polished amber-gold bell with a deep teal shadow plane, a tiny clapper cutout, an original dark crimson-pink ribbon bow above the bell, and a small ivory star engraved on the front. The bell must be instantly recognizable and readable when reduced to a small orbiting game sprite.
> Composition/framing: One complete object centered on a square canvas, occupying about 75% of its height; bow and clapper fully visible with transparent margin.
> Style/medium: clean hand-painted comic game sprite, thick dark-plum outline, flat cel-shaded color blocks and only a few high-contrast details.
> Lighting/mood: cool moonlit rim and a soft amber glint; avoid a large glow that would obscure the bell outline.
> Constraints: genuine transparent background with real alpha; no character, no hand, no orbit ring, no sound waves, no detached sparkles, no shadow, no text, no grid, no checkerboard, no watermark. One isolated sprite, not a sheet.

## 经验宝石

文件：assets/v2_dark_comic/pickups/experience_gem.png
尺寸：原图 1254×1254；项目版 256×256。RGBA alpha 0–255。
用途：场内经验掉落和界面小图标共用。

**完整提示词**

> Use case: stylized-concept
> Asset type: one experience pickup and small HUD icon for a top-down survivor game
> Input images: Image 1 is the approved style reference; match its dark-comic outline, clean cel-shaded blocks, cold moonlit blue/teal and small amber-gold highlights without copying its scene or characters.
> Primary request: A single floating experience crystal: a compact faceted diamond-shaped shard, bright pale-cyan core, deep teal and midnight-blue facets, a thin amber-gold edge along two facets, and one small ivory star glint. Keep the shape simple, instantly recognizable as a valuable pickup, and legible against dark grass when reduced to a tiny game icon.
> Composition/framing: One whole gem, centered on a square canvas, filling 75–80% of canvas height with transparent margin; slight three-quarter top-down angle, no crop.
> Style/medium: polished 2D comic fantasy game icon, bold deep-plum outline, high-contrast hard cel shading and a small number of broad facets.
> Lighting/mood: cool moonlit rim, luminous icy center, restrained warm-gold glint.
> Constraints: genuinely transparent background with real alpha; no base, floor, shadow, hand, character, extra gems, detached particles, text, symbols with letters, grid, checkerboard, or watermark. Single icon only, not a sheet.

## 命中特效

文件：assets/v2_dark_comic/fx/hit_spark.png
尺寸：原图 1254×1254；项目版 256×256。RGBA alpha 0–255。
用途：短促通用命中反馈静帧，需与程序闪色/后续 SpriteFrames 配合；旧版项目当前尚未引用此新图。视觉复核：中心闪光清楚、外缘留白充分，无不透明底色或大范围遮挡元素。

**完整提示词**

> Use case: stylized-concept
> Asset type: compact reusable hit feedback sprite for a top-down survivor game
> Input images: Image 1 is the approved style reference. Match the dark comic fantasy palette, clean cel shading, amber-gold light, cold moonlight and tiny restrained scarlet accents; do not reproduce the characters or scene.
> Primary request: A single brief readable impact spark: a small ivory-white four-point center flash, four short jagged amber-gold slash rays, and only a few tiny deep red and pale-blue chips. This should communicate a weapon hit without becoming a large explosion or hiding an enemy, dropped item, or health display.
> Composition/framing: One compact burst centered on a square canvas, occupying about 55% of the canvas diameter with generous transparent padding and no crop.
> Style/medium: polished 2D comic game effect, crisp angular shapes, strong contrast, dark plum outline around the center flash and simple color planes; no soft blur.
> Lighting/mood: warm gold at the center, brief cool moonlit tips, very small scarlet accents.
> Constraints: genuine transparent background with real alpha; no ring, no fireball, no smoke, no ground, no character, no weapon, no detached trail, no text, no grid, no checkerboard, no watermark. Single static effect sprite, not a sheet.
## 星光魔杖 4 帧发射动画

四帧均为 256×256 RGBA PNG，alpha 范围 0–255。底层均复用完整的 starlight_wand.png；因此魔杖轮廓、轴心、基线、像素尺寸和透明边界逐帧完全相同。第 01 帧是 idle 图的逐字节副本；第 02–04 帧将 image_gen 单独生成的透明光效叠层裁切、缩小并定位到星杖头部。整帧最终 alpha 边界均为 (42, 28, 240, 224)。

| 文件 | 原始来源 | 处理后效果区域 | 项目尺寸 | Alpha |
| --- | --- | ---: | ---: | --- |
| weapons/starlight_wand_fire_01.png | 复用 weapons/starlight_wand.png，无新生成 | 无叠层 | 256×256 | RGBA，0–255 |
| weapons/starlight_wand_fire_02.png | image_gen 叠层 exec-afe7bed3-2dc0-4bc7-90ca-9d581c23a84f.png，原图 1254×1254 | 48×57 | 256×256 | RGBA，0–255 |
| weapons/starlight_wand_fire_03.png | image_gen 叠层 exec-1afb3556-53d5-418f-902f-be6b3d1b6978.png，原图 1254×1254 | 60×67 | 256×256 | RGBA，0–255 |
| weapons/starlight_wand_fire_04.png | image_gen 叠层 exec-71ffc062-9b50-4efb-8ac6-d74edffc6ff0.png，原图 1254×1254 | 34×29 | 256×256 | RGBA，0–255 |

用于全部叠层生成的参考图仍为 assets/v2_dark_comic/style/art_direction.png 与 assets/v2_dark_comic/weapons/starlight_wand.png。完整原始叠层保留于 CODEX_HOME/generated_images/01a0d290-a523-7531-ac4c-b0d95600f323/。

### 发射帧 01

复用已交付的 starlight_wand.png，不新增生成提示词。与 idle/回退图相同，作为发射动作的起始姿势。

### 发射帧 02

完整提示词（用于单独生成透明光效叠层）：

> Use case: stylized-concept
> Asset type: transparent magic-light overlay layer for frame 02 of the existing star wand fire animation
> Input images: Image 1 is the approved dark-comic style reference. Image 2 is only a design and scale reference for the star wand; do not include the wand itself.
> Primary request: Generate only a small charge-up effect overlay: one crisp pale-blue four-point sparkle with a thin amber-gold crescent and two tiny ivory pin sparks. It should feel like a restrained spell charge, not an explosion.
> Composition/framing: One effect cluster centered on a square transparent canvas, occupying about 18% of canvas width. It will be placed over the existing wand's star head as a separate alpha layer; leave the rest of the canvas empty.
> Style/medium: clean angular cel-shaded light shapes, dark-plum contour only on the central spark, matching the reference palette.
> Lighting/mood: cool moonlit blue-white with a small warm gold accent.
> Constraints: true transparent alpha; effect overlay only, no wand, no star wand, no projectile, no beam, no ring, no diffuse haze, no large glow, no background, no floor, no cast shadow, no text, no grid, no checkerboard, no watermark. Single overlay sprite only.

### 发射帧 03

完整提示词（用于单独生成透明光效叠层）：

> Use case: stylized-concept
> Asset type: transparent peak-release magic overlay layer for frame 03 of the existing star wand fire animation
> Input images: Image 1 is the approved dark-comic style reference. Image 2 is only a wand design and scale reference; do not include the wand itself.
> Primary request: Generate only the brightest moment of a star-spell effect as a compact overlay: one small ivory-gold four-point flash with three angular amber rays and two tiny cool-blue motes. The flare should feel crisp and energetic, with the star as the clear center.
> Composition/framing: One effect cluster centered on a square transparent canvas, occupying about 24% of canvas width. It will be placed directly over the existing wand star head as an alpha layer; leave the rest completely empty.
> Style/medium: clean angular cel-shaded comic magic, dark-plum contour on the flash, matching the reference's simple bold shapes.
> Lighting/mood: warm gold-white peak with a little moonlit blue at the tips.
> Constraints: true transparent alpha; effect overlay only, no wand, no projectile, no beam, no ring, no diffuse haze, no oversized glow, no background, no floor, no cast shadow, no text, no grid, no checkerboard, no watermark. Single overlay sprite only.

### 发射帧 04

完整提示词（用于单独生成透明光效叠层）：

> Use case: stylized-concept
> Asset type: transparent fading magic-light overlay layer for frame 04 of the existing star wand fire animation
> Input images: Image 1 is the approved dark-comic style reference. Image 2 is only a wand design and scale reference; do not depict the wand.
> Primary request: Create only the spell's afterglow overlay: a small dim ivory-gold four-point glint and one faint cool-blue mote, with one short fading amber streak. This final frame must be much quieter than a firing flash and suggest the light settling back toward the wand.
> Composition/framing: One small centered effect cluster on a square transparent canvas, occupying about 12–15% of canvas width; leave the rest empty.
> Style/medium: crisp simple cel-shaded comic magic shapes, consistent with the reference; minimal detail.
> Lighting/mood: faint cool moonlit edge and muted warm gold, lower brightness than the earlier pulse.
> Constraints: true transparent alpha; effect overlay only, no wand, no projectile, no beam, no ring, no wide glow, no haze, no background, no floor, no shadow, no text, no grid, no checkerboard, no watermark. One overlay sprite only.

### 帧检查

四张成图逐帧目视检查通过：图幅一致，魔杖完全复用同一底图，未发生帧间跳位；光效从起始静帧、轻微蓄能到短促强闪、余辉回落。早期整帧生成候选有 10–15% 物体缩放/轴线偏移，另一个候选出现过宽橙色漫射光；均未纳入交付。

## 星光弹脉冲四帧动画

用途：当前星光弹的四帧脉冲动画素材；静态原图 projectiles/starlight_bolt.png 保留为 idle/回退。只新增 PNG，不改代码。四帧均为 256×256 RGBA PNG，alpha 范围 0–255，非透明 alpha 外接框一致为 (45,87)–(223,165)。帧 01 与原始弹体 PNG 字节完全相同；帧 02–04 以原弹体为像素级底图，只在星头附近叠加效果，框外底图逐像素保持不变。所有效果参考 style/art_direction.png 与 projectiles/starlight_bolt.png。

| 文件 | 来源与处理 | 效果叠层位置 / 改动区 | 画布 | Alpha |
| --- | --- | --- | --- | --- |
| projectiles/starlight_bolt_pulse_01.png | 直接复制 projectiles/starlight_bolt.png；不做重采样 | 无叠层，起始/回退帧 | 256×256 | RGBA，0–255 |
| projectiles/starlight_bolt_pulse_02.png | image_gen 透明叠层 exec-e60bc4e0-654a-4d87-8286-3eac7e605590.png，原生 1254×1254 RGBA；alpha >32 裁剪框 (686,512)–(917,731)，高质量缩放至 43×41 | 放置于 (168,100)，只形成星头附近的蓝白收束微光与琥珀小闪；像素变化框 (168,100)–(210,140) | 256×256 | RGBA，0–255 |
| projectiles/starlight_bolt_pulse_03.png | image_gen 透明叠层 exec-f82665ba-7b33-46c5-9616-cdde28452d4b.png，原生 1254×1254 RGBA；alpha >32 裁剪框 (384,312)–(917,887)，高质量缩放至 56×60 | 放置于 (162,90)，峰值蓝白星芒与短促射线；像素变化框 (162,90)–(217,149) | 256×256 | RGBA，0–255 |
| projectiles/starlight_bolt_pulse_04.png | image_gen 透明叠层 exec-ca6e35e1-2e2d-4b11-ba7c-b263f3447c77.png，原生 1254×1254 RGBA；alpha >32 裁剪框 (556,544)–(689,702)，高质量缩放至 30×36 | 放置于 (175,102)，小幅冷蓝余辉与微弱琥珀光点；像素变化框 (175,102)–(204,137) | 256×256 | RGBA，0–255 |

### 脉冲帧 02 完整提示词

> Make one isolated visual-effect overlay for a 2D sprite animation. Use the supplied art direction board for style and the supplied starlight bolt only to determine position and scale. Square 256x256 transparent PNG with genuine transparent alpha. Entire canvas transparent except a small icy blue-white pulse at the projectile's bright golden star head, approximately centered x=195,y=128 in the 256px reference sprite. Do not redraw/include the bolt, background, text, frame, shadow, or any other object. Pulse phase 02 of 04: restrained cool glow tightening around the star core, one tiny amber glint, crisp dark-comic cel-shaded strokes, no more than 48x48px footprint. Keep the effect centered and compact so it can be composited over the unchanged bolt.

### 脉冲帧 03 完整提示词

> Create one isolated transparent impact-free pulse overlay for the provided 2D star bolt sprite. Use the dark comic fantasy board as style reference and the supplied bolt solely for scale and facing direction. Square transparent PNG with real alpha; nothing visible except a compact flare effect, no bolt body and no background or text. This is phase 03/04, the peak of a magical pulse: crisp icy cyan and white four-point starburst with a small amber-gold core glint and a few short comic rays, high contrast cel-shading with a clean dark outline, energetic but tightly contained. Keep all marks within a compact roughly 55x55 pixel footprint when reduced to 256x256. It will be manually centered over the bolt's existing gold star head; leave the rest of the canvas transparent. No long streaks, no extra projectile, no separate large stars.

### 脉冲帧 04 完整提示词

> Create one isolated transparent overlay for phase 04/04 of the supplied 2D starlight bolt pulse animation. Use the dark comic fantasy style board for visual style and the bolt only for scale/facing. Square PNG with real transparency; show only a small fading afterglow effect, no bolt body, no backdrop, no text, no frame. Make a compact dim icy-blue-white shimmer with two tiny fading amber motes and short soft-edged cel-shaded rays, much weaker and smaller than a peak starburst. Keep all visible marks within about a 34x34 pixel footprint when scaled to 256x256, so it can be centered over the bolt's gold star head. Leave the rest fully transparent. No long streaks or extra stars.

### 帧检查

四帧逐张目视通过：发射弹体朝向、星头和尾迹稳定；亮度从静止、微脉冲到峰值星芒，再回落为余辉。四张最终画布均为 256×256、RGBA alpha 0–255，非透明外接框一致。与原图逐像素比较，帧 01 无改动，帧 02–04 的像素变化均局限于星头附近，弹体其余区域完全相同。
