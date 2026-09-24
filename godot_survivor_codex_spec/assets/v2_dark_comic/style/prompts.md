# 新版暗色漫画奇幻美术提示词记录

- 文件：art_direction.png
- 尺寸：1672×941 px（约 16:9）
- 格式：PNG，RGB 真彩色，无 alpha 通道（风格概念板为不透明图）
- 生成方式：Codex 内置 image_gen；参考现有角色图集 assets/sprites/cute_pixel/characters.png 与庭院图 assets/backgrounds/月光庭院.png
- 用途：A01 统一画风基准概念板，不作为游戏精灵切图

## 最终采用的生成提示词

Use case: stylized-concept
Asset type: A01 art direction style board for a 2D survivor-like fantasy game; visual production reference, not a game sprite sheet.
Input images: Image 1 is an identity reference for the existing game cast (white-haired hooded wand mage, green slime, purple bat, crowned red-caped moon lord); preserve their recognizable roles and signature shapes while completely redrawing them. Image 2 is an identity and setting reference for the existing moonlit courtyard (broad open grass, pale winding stone paths, low shrubs and flowers under a full moon); preserve the location's calm open-play-area identity.
Primary request: create one polished landscape style guide board that establishes a unified dark comic fantasy art direction. Show a representative 3.5-head-tall white-haired childlike wizard with an oversized deep-teal hood, short cape and small star wand, seen in three-quarter top-down view facing right. Around that main sample, include compact visual samples of the courtyard ground, a readable green slime and purple bat threat silhouette, a larger crowned red-caped lord silhouette, ink line weight, cel-shadow shapes, stone/cloth/metal surface treatment, a gold-red hit spark, and a controlled magical glow.
Style/medium: hand-drawn dark comic fantasy illustration, crisp confident dark indigo ink outlines with slight line-weight variation, clean cel-shaded color blocks, selective restrained crosshatching and textured brush accents; polished game art, not photorealistic and not pixel art.
Composition/framing: landscape 16:9 visual guide board with clear separated illustrative studies and small palette/material swatches; the wizard is the largest central focal sample. The board should be immediately scannable and useful to other artists.
Lighting/mood: cool moonlit blue-white rim light over deep night shadows; warm magical glow is localized.
Color palette: deep indigo and violet shadows, muted ink-green courtyard, cool moon-silver highlights, small deliberate amber-gold and vermilion-red accents.
Readability: strong silhouettes and simple value grouping that stay clear at small in-game sizes; combat effects are brief, compact, and never obscure the character silhouettes.
Constraints: no text, no letters, no labels, no numbers, no UI, no watermark, no borders that resemble an interface, no additional characters or props beyond the listed game identities and small material samples.

## F01 月光庭院背景

- 文件：`backgrounds/F01_moonlit_courtyard.png`
- 最终尺寸：2560×1440 px；16:9
- 格式：PNG，RGB 真彩色，无 alpha 通道（完整场地背景）
- 生成源：Codex 内置 image_gen 输出 1672×941 px；为匹配游戏场地做高质量双三次缩放，无裁切
- 用途：完整月夜庭院场地底图；中央战斗区域留空，装饰收于边缘

### 最终采用的生成提示词

Use case: stylized-concept
Asset type: F01 finished 2D game-play field background, 2560x1440 target canvas, 16:9.
Input images: Image 1 is the approved dark comic fantasy style reference; match its restrained inked outlines, cel-shaded surfaces, cool moonlit palette, and small amber accents. Image 2 is the existing location identity reference; keep the recognizable open moonlit garden courtyard with grass, pale winding stone paths, low shrubs, small flowers, and calm full-moon night.
Primary request: create only a clean full-canvas courtyard ground background for a 2D survivor-like game map. The full 16:9 canvas is a flat orthographic top-down ground plane with no horizon. Preserve a very broad, safe, readable walkable area across the center. Keep the central 70% mostly uninterrupted muted grass with only faint low-contrast texture. Put all decorative details, sparse low flowers, little grass tufts, tiny pale stones, and small dark shrubs along the outer 15% margins; a few narrow, pale broken-stone path traces may curve near the edges, never forming walls or obstacles.
Style/medium: hand-painted dark comic fantasy game environment, crisp but restrained ink contours, clean cel-shaded value groups, subtle textured brush grain, polished 2D game background, not pixel art, not photorealistic.
Composition/framing: exact wide 16:9 orthographic field view designed to fill a 2560x1440 play area; no perspective depth, no horizon, no central focal object, center stays visually open.
Lighting/mood: quiet moonlit night, soft cool silver-blue illumination and gentle teal ambient bounce; keep ground values low contrast so dark and bright character sprites remain readable.
Color palette: muted ink green and deep blue-green grass, cool slate-blue stone, indigo-violet shadows, tiny isolated pale flowers and very restrained warm-gold glints.
Constraints: no characters, creatures, enemies, pets, weapons, projectiles, pickups, text, UI, borders, buildings, walls, fences, large rocks, stumps, logs, water, bridges, dense vegetation, or any object that could read as a gameplay obstacle. No watermark.

## F04 通用空白面板

- 文件：`ui/ui_panel_frame.png`
- 最终尺寸：600×364 px（约 5:3；适合 600×360 面板使用）
- 格式：PNG，RGBA 真 alpha；透明外角 alpha=0，面板中心 alpha≈252
- 生成方式：Codex 内置 image_gen；alpha 边界阈值 4 并保留约16 px 安全透明边，再按高质量双三次缩放至最终尺寸。适合 Godot NinePatchRect / StyleBoxTexture；九宫格边缘参考约40–60 px。
- 用途：HUD、升级、结算等通用空白面板，文字由 Godot 绘制

### 最终采用的生成提示词

Use case: stylized-concept
Asset type: one reusable transparent 2D game UI sprite: generic large rectangular panel frame for HUD, upgrade, and result screens.
Input images: Image 1 is only a style and palette reference for the approved dark comic fantasy game; do not copy its layout or characters.
Primary request: create one isolated front-facing blank rectangular fantasy panel. The panel has a very dark midnight-indigo inner plate with a clean empty center for game-drawn text, a bold dark ink outer contour, restrained cool moon-silver double trim, and small muted amber-gold rivets or corner marks. Keep the design quiet and readable at small sizes, suitable for nine-slice scaling.
Style/medium: polished hand-painted 2D dark comic fantasy game UI, crisp clean shapes, restrained cel shading, subtle material texture; consistent with dark indigo, moon-silver, ink-teal, and tiny gold accents.
Composition/framing: centered wide 4:3 rectangular panel on a 1024x1024 canvas, straight horizontal and vertical edges, no perspective, generous transparent padding around the whole panel; ornament only at the four corners, long sides kept simple.
Lighting/mood: subtle cool rim highlights, no bloom.
Constraints: genuinely transparent background outside the panel; preserve the alpha. Exactly one isolated panel asset, no screen mockup, no text, letters, numbers, labels, icons, emblems, characters, scenery, shadow cast onto a background, watermark, or checkerboard pattern.

## F04 升级选择卡

- 文件：`ui/ui_upgrade_card.png`
- 最终尺寸：1020×1482 px
- 格式：PNG，RGBA 真 alpha；透明外角 alpha=0，卡片中心 alpha≈253
- 用途：竖版升级卡备用；上方留图标空间，卡内留白给游戏文字

### 最终采用的生成提示词

Use case: stylized-concept
Asset type: one reusable transparent 2D game UI upgrade-choice card frame.
Input images: Image 1 is the approved dark comic fantasy style and palette reference. Image 2 is the approved generic panel frame; match its dark indigo contour, cool silver trim, and restrained gold fasteners.
Primary request: create one isolated portrait fantasy card for a three-choice level-up menu. It is a sturdy blank card frame with a dark midnight-indigo face, clear empty space for game-drawn title/body text, and a reserved quiet area near the top for a separately drawn icon. Do not draw an icon or text.
Style/medium: polished hand-painted dark comic fantasy game UI, clean cel-shaded metal bevel, subtle inked edges and restrained surface texture.
Composition/framing: single front-facing vertical card on a 2:3 transparent canvas, nearly filling the canvas with safe transparent padding; straight sides and consistent border thickness suitable for scaling. Small corner details only; no perspective.
Lighting/mood: cool moon-silver edge glints with one or two tiny muted amber-gold studs; subdued overall.
Constraints: genuinely transparent background outside the card; preserve the alpha. Exactly one isolated blank card asset, no screen mockup, no text, letters, numbers, labels, icon, emblem, characters, scenery, cast shadow, watermark, or checkerboard pattern.

## F04 横向操作按钮

- 文件：`ui/ui_action_button.png`
- 最终尺寸：420×64 px
- 格式：PNG，RGBA 真 alpha；透明角 alpha=0，按钮面中心 alpha≈253
- 用途：升级选项、继续、重开等操作按钮；无字，标签由 Godot 绘制

### 最终采用的生成提示词

Use case: stylized-concept
Asset type: one production-ready transparent game UI button sprite, designed to display at approximately 420x64 pixels.
Input images: Image 1 is the approved dark comic fantasy palette and ink style reference. Image 2 is the approved generic panel frame; match its midnight-indigo surface, silver-blue trim, and restrained amber-gold hardware.
Primary request: create a single blank horizontal action button with a low-profile silhouette whose visible button body has an approximately 6.5:1 width-to-height ratio. The center face is a calm deep blue-teal enamel surface with generous room for a label drawn by Godot. Use only a thin clean dark outline, a compact silver-blue bevel, and tiny understated gold end fasteners.
Style/medium: polished hand-painted dark comic fantasy 2D game UI; crisp cel-shaded edges, subtle material texture, visually consistent with the panel reference.
Composition/framing: 16:9 transparent canvas with exactly one long, narrow button centered; the button body spans most of the width and about one fifth of the canvas height, with comfortable clear transparency above and below. Straight-on orthographic view, no perspective, no deep end caps or tall corner ornaments.
Lighting/mood: soft cool moonlit highlight on the upper edge, subdued and readable.
Constraints: genuinely transparent outside the button; preserve the alpha. No screen mockup, no text, letters, numbers, symbols, icons, emblems, characters, scenery, cast shadow, watermark, or checkerboard pattern.

## F04 HUD 进度条轨道

- 文件：`ui/ui_progress_track.png`
- 最终尺寸：420×24 px
- 格式：PNG，RGBA 真 alpha；透明外角 alpha=0，轨道中心 alpha≈252
- 用途：生命与经验条共用的暗色凹槽；预留约348×6 px 内槽叠加填充条

### 最终采用的生成提示词

Use case: stylized-concept
Asset type: one production-ready transparent 2D game HUD progress-bar track sprite, intended final size about 420x24 pixels.
Input images: Image 1 is the approved dark comic fantasy style reference. Image 2 is the approved panel trim reference; match its dark indigo ink contour and thin cool silver-blue bevel.
Primary request: create only one empty horizontal progress track: a very slim, flat, long 17.5:1 bar with a dark midnight-indigo recessed channel where a separate fill sprite will be drawn. Give it a crisp narrow cool silver-blue rim and only tiny amber marks at the far ends.
Style/medium: polished hand-painted dark comic fantasy 2D game UI, restrained clean cel shading and subtle metal texture, no heavy ornament.
Composition/framing: centered on a 16:9 transparent canvas; the bar itself spans about 85% of the canvas width and only about 6% of its height, maintaining a very slender HUD-bar shape. Straight-on view with square-safe horizontal center alignment.
Lighting/mood: low intensity moonlit highlights, readable against dark game scenery.
Constraints: genuinely transparent background outside the track; preserve the alpha. No fill overlay, no text, numbers, ticks, labels, icons, emblems, buttons, panels, characters, scenery, cast shadow, watermark, or checkerboard pattern.

## F04 HUD 经验条填充

- 文件：`ui/ui_progress_fill_xp.png`
- 最终尺寸：348×6 px
- 格式：PNG，RGBA 真 alpha；边缘透明像素保留，填充本体中心 alpha≈252
- 用途：叠加在进度条内槽（约 x+36, y+9）；适合按经验比例水平缩放

### 最终采用的生成提示词

Use case: stylized-concept
Asset type: one production-ready transparent 2D HUD experience progress-fill sprite, to overlay the approved empty track.
Input images: Image 1 is the approved dark comic fantasy palette reference. Image 2 is the approved progress-track geometry reference; fit inside its recessed center channel and do not repeat its frame or end details.
Primary request: create only a full-length narrow fill strip for an experience bar. The fill is cool moonlit teal-cyan energy with a pale silver-blue top glint and a darker teal lower edge; saturated enough to read on the dark indigo track but restrained and clean.
Style/medium: polished hand-painted dark comic fantasy game UI, crisp cel-shaded color, tiny controlled highlight, no painterly particles.
Composition/framing: a single straight horizontal strip with a flush flat left edge and a gently chamfered right end; approximately 17.5:1 width-to-height. Center it on a 16:9 transparent canvas; strip spans about 85% of canvas width and about 6% of its height, matching the track's channel scale.
Lighting/mood: cool moonlight glow kept within the fill shape, no bloom outside it.
Constraints: genuinely transparent background outside the fill strip; preserve the alpha. No track, frame, border, text, numbers, ticks, labels, icons, symbols, emblems, characters, scenery, watermark, or checkerboard pattern.

## F04 HUD 生命条填充

- 文件：`ui/ui_progress_fill_health.png`
- 最终尺寸：348×6 px
- 格式：PNG，RGBA 真 alpha；边缘透明像素保留，填充本体中心 alpha≈253
- 用途：叠加在进度条内槽（约 x+36, y+9）；适合按生命比例水平缩放

### 最终采用的生成提示词

Use case: stylized-concept
Asset type: one production-ready transparent 2D HUD health progress-fill sprite, to overlay the approved empty track.
Input images: Image 1 is the approved dark comic fantasy palette reference. Image 2 is the approved progress-track geometry reference; fit inside its recessed center channel and do not repeat its frame or end details.
Primary request: create only a full-length narrow fill strip for a health bar. The fill is deep vermilion-crimson with a restrained warm coral highlight across the upper edge and a darker garnet lower edge; strong enough to read clearly on the dark indigo track.
Style/medium: polished hand-painted dark comic fantasy game UI, crisp cel-shaded color, controlled sheen, no flames or particles.
Composition/framing: a single straight horizontal strip with a flush flat left edge and a gently chamfered right end; approximately 17.5:1 width-to-height. Center it on a 16:9 transparent canvas; strip spans about 85% of canvas width and about 6% of its height, matching the track channel scale.
Lighting/mood: localized warm highlight contained within the strip, no bloom outside it.
Constraints: genuinely transparent background outside the fill strip; preserve the alpha. No track, frame, border, text, numbers, ticks, labels, icons, symbols, emblems, characters, scenery, watermark, or checkerboard pattern.
