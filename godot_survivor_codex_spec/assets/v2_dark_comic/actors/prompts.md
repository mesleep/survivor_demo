# 角色与敌人素材提示词及检查记录

风格统一参考：assets/v2_dark_comic/style/art_direction.png。所有角色均为三分之四俯视、朝右、单体透明 PNG，采用深蓝紫描边、赛璐璐块面、冷月光轮廓光和少量金红点缀。

## 本批输出与检查

| 编号 | 对象 | 文件 | 尺寸 | alpha 检查 |
| --- | --- | --- | --- | --- |
| B01 | 月光小法师 | actors/B01_月光小法师_单帧.png | 256×256 | PNG Format32bppArgb；四角 alpha=0，中心 alpha=253 |
| B03 | 虎妞 | actors/B03_虎妞_单帧.png | 256×256 | PNG Format32bppArgb；四角 alpha=0，中心 alpha=252 |
| B04 | 黑豹 | actors/B04_黑豹_单帧.png | 256×256 | PNG Format32bppArgb；四角 alpha=0，中心 alpha=253 |
| B05 | 小四 | actors/B05_小四_单帧.png | 256×256 | PNG Format32bppArgb；四角 alpha=0，中心 alpha=252 |
| B06 | 小七 | actors/B06_小七_单帧.png | 256×256 | PNG Format32bppArgb；四角 alpha=0，中心 alpha=253 |
| B09 | 月夜领主 | enemies/B09_月夜领主_单帧.png | 384×384 | PNG Format32bppArgb；四角 alpha=0，中心 alpha=253 |

图像生成原图均为 1254×1254 PNG，按角色规格高质量缩小到上表尺寸，透明通道保留。alpha=0 的角落与不透明主体像素同时存在，确认是真透明背景，不是棋盘格或纯色底图。当前交付为单帧静态姿态，可在接入时复用到 idle/walk 帧；未包含四帧动作序列、头像或 Boss 血条徽记。

## B01 月光小法师

参考：风格基准图。角色特征沿用画板：白发、深青蓝兜帽、红眼、深蓝披风、金色星形徽章、木质星杖。

~~~text
Use case: a standalone 2D game character sprite for a top-down survivor game.
Primary request: create one full-body sprite of the existing Moonlight Apprentice, preserving the identity shown in reference image 1: a young white-haired witch, oversized deep teal hood, bright red eyes, dark navy cloak with burgundy lining, gold star medallion, dark tunic, brown boots, and a wooden star-tipped staff. Keep the design recognizable and close to the mage depiction in reference image 1.
Style: match reference image 1's dark comic fantasy art direction exactly: thick clean midnight-blue ink outlines, bold cel-shaded color planes, restrained hand-inked shadow hatching, cool moonlit rim light, deep navy and teal shadows, pale silver hair, small warm-gold and crimson accents. Polished, crisp 2D game illustration, not photorealistic and not pixel art.
Composition: one complete character only, about 3.5 heads tall, three-quarter top-down view facing right, readable face and boots, centered in a square game-sprite frame, feet aligned near a consistent bottom baseline, occupying about 70 percent of the frame with transparent breathing room. Hold the star staff visibly in the right hand; no magic blast or extra particles.
Background: true transparent alpha; no floor, cast shadow, scenery, panel, or color backdrop.
Constraints: exact single sprite, clear silhouette, no text, no watermark, no border, no extra character, no alternate poses, no tiled checkerboard.
~~~

## B03 虎妞

参考：风格基准图作画风；虎妞绷脸版第一行作身份参考。保留宽圆脸、半眯眼、闭嘴稳重表情和罗威纳黑棕配色。

~~~text
Use case: a standalone 2D game pet sprite for a top-down survivor game.
Input references: reference image 1 supplies only the shared art style and palette. Reference image 2 is the existing four-frame sprite sheet; use the first-row dog as identity reference only, not as a layout to reproduce.
Primary request: create one complete full-body sprite of Hu Niu, the sturdy female Rottweiler pet. Preserve her broad round head, wide tan muzzle, small half-lidded eyes, dark black-brown coat, distinct tan eyebrow spots, tan muzzle and paws, and drooping ears. Her expression is calm, stern and gentle: closed mouth, no grin, eyes slightly narrowed. Keep her short-legged, robust quadruped build.
Style: match reference image 1's dark comic fantasy art direction: thick clean midnight-blue ink outlines, bold cel-shaded color planes, a little restrained ink hatching, cool moonlit rim light, dark navy shadows, warm tan and small gold accents. Crisp, readable 2D game illustration, not photorealistic, not pixel art.
Composition: exactly one four-legged dog, three-quarter top-down view facing right; show the whole body, four paws, face and tail, centered in a square sprite frame, with the paws near a consistent bottom baseline and about 15 percent transparent margin.
Background: true transparent alpha; no ground, cast shadow, scenery, panel, or color backdrop.
Constraints: use only Hu Niu's identity from reference image 2. Do not draw Hei Bao, cats, slime, costume, collar, clothing, props, text, watermark, border, extra poses, or a tiled checkerboard.
~~~

## B04 黑豹

参考：风格基准图作画风；虎妞与黑豹图第二行作身份参考。保留较修长身形、黑棕与暖棕配色、吐舌笑脸和翘尾。

~~~text
Use case: a standalone 2D game pet sprite for a top-down survivor game.
Input references: reference image 1 supplies only the shared art style and palette. Reference image 2 is a two-dog four-frame sprite sheet; use the black-and-tan dog in the second row as Hei Bao's identity reference only, not as a layout to reproduce.
Primary request: create one complete full-body sprite of Hei Bao, a friendly male Rottweiler pet. Preserve his longer, leaner body and slightly longer muzzle compared with Hu Niu, dark black-brown coat, warm tan eyebrow spots, tan muzzle and paws, floppy ears, bright eyes, open happy mouth with a visible pink tongue, and a gently raised tail. Keep him clearly Rottweiler-like and distinct from a generic black dog.
Style: match reference image 1's dark comic fantasy art direction: thick clean midnight-blue ink outlines, bold cel-shaded color planes, restrained hand-inked shadow hatching, cool moonlit rim light, deep navy shadows, warm tan and small gold accents. Crisp, readable 2D game illustration, not photorealistic, not pixel art.
Composition: exactly one four-legged dog, three-quarter top-down view facing right; show the whole body, four paws, face, tongue and raised tail. Center the character in a square sprite frame, paws near a consistent bottom baseline, with about 15 percent transparent margin.
Background: true transparent alpha; no ground, cast shadow, scenery, panel, or color backdrop.
Constraints: use Hei Bao's identity from the second row of reference image 2 only. Do not draw Hu Niu, cats, slime, costume, collar, clothing, props, text, watermark, border, extra poses, or a tiled checkerboard.
~~~

## B05 小四

参考：风格基准图作画风；小四与小七图第一行作身份参考。保留白底、灰褐狸花头耳和身斑、白鼻梁、粉鼻及黄眼。

~~~text
Use case: a standalone 2D game pet sprite for a top-down survivor game.
Input references: reference image 1 supplies only the shared art style and palette. Reference image 2 is a two-cat four-frame sprite sheet; use the white-based cat in the first row as Xiao Si's identity reference only, not as a layout to reproduce.
Primary request: create one complete full-body sprite of Xiao Si, a small white cat. Preserve the white coat, round face, gray-brown tabby markings on the crown and ears, white blaze down the center of the face, several distinct dark patches on the body, warm yellow eyes and small pink nose. Keep the cat cute and compact with short legs and a visible tail; do not turn the patches into a tuxedo pattern.
Style: match reference image 1's dark comic fantasy art direction: thick clean midnight-blue ink outlines, bold cel-shaded color planes, restrained ink hatching, cool moonlit rim light, dark navy shadows, soft cream-white fur and small warm-gold accents. Crisp, readable 2D game illustration, not photorealistic, not pixel art.
Composition: exactly one four-legged cat, three-quarter top-down view facing right; show the full body, four paws, face and tail. Center in a square sprite frame with paws near a consistent bottom baseline and about 15 percent transparent margin.
Background: true transparent alpha; no ground, cast shadow, scenery, panel, or color backdrop.
Constraints: use only Xiao Si's identity from the first row of reference image 2. Do not draw Xiao Qi, dogs, slime, collar, clothing, props, text, watermark, border, extra poses, or a tiled checkerboard.
~~~

## B06 小七

参考：风格基准图作画风；小四与小七图第二行作身份参考。明确保留深灰褐底色、全身细黑条纹和浅棕口鼻，避免纯黑。

~~~text
Use case: a standalone 2D game pet sprite for a top-down survivor game.
Input references: reference image 1 supplies only the shared art style and palette. Reference image 2 is a two-cat four-frame sprite sheet; use the dark tabby cat in the second row as Xiao Qi's identity reference only, not as a layout to reproduce.
Primary request: create one complete full-body sprite of Xiao Qi, a small dark brown-gray tabby cat. Preserve the medium gray-brown coat, many clearly visible narrow charcoal stripes across forehead, cheeks, back, legs and ringed tail, lighter warm-brown muzzle, amber-yellow eyes, and compact round face. He must read as a striped tabby cat, not a solid black cat; keep his coat visibly lighter than the darkest ink outlines.
Style: match reference image 1's dark comic fantasy art direction: thick clean midnight-blue ink outlines, bold cel-shaded color planes, restrained ink hatching, cool moonlit rim light, deep navy shadows, warm gray-brown fur with small amber highlights. Crisp, readable 2D game illustration, not photorealistic, not pixel art.
Composition: exactly one four-legged cat, three-quarter top-down view facing right; show the full body, four paws, face and striped tail. Center in a square sprite frame with paws near a consistent bottom baseline and about 15 percent transparent margin.
Background: true transparent alpha; no ground, cast shadow, scenery, panel, or color backdrop.
Constraints: use only Xiao Qi's identity from the second row of reference image 2. Do not draw Xiao Si, dogs, slime, collar, clothing, props, text, watermark, border, extra poses, or a tiled checkerboard.
~~~

## B09 月夜领主

参考：风格基准图下方中央的领主造型。保留冠冕红宝石、白色毛领、绯红披风、紫色面部、深靛服饰和金色徽章。

~~~text
Use case: a standalone 2D game boss sprite for a top-down survivor game.
Input reference: reference image 1 supplies the shared dark comic fantasy design and specifically the Moonlit Lord character shown near the lower center. Follow that boss's silhouette and color identity.
Primary request: create one full-body sprite of the Moonlit Lord, a regal night ruler and clearly larger boss than the player or pets. Preserve the identifying gold crown with a red jewel, broad white fur collar, flowing deep crimson cape, violet face and hair, dark indigo tunic/armor, gold medallion and heavy boots. Keep an intimidating but readable stern expression and a powerful broad silhouette; do not add horns or weapons that are absent from the reference.
Style: match reference image 1 exactly: thick clean midnight-blue outlines, bold cel-shaded color planes, controlled ink hatching, cool moonlit rim light, deep navy and violet shadows, crimson and warm-gold accents. Crisp, polished 2D game illustration, not photorealistic and not pixel art.
Composition: one complete boss only, about 4 heads tall and visibly bulkier/larger than the mage, three-quarter top-down view facing right. Show the whole crown, cape, both arms and boots; center it in a square boss-sprite frame with feet on a stable bottom baseline and about 12 percent transparent margin.
Background: true transparent alpha; no ground, cast shadow, scenery, panel, blood bar, or color backdrop.
Constraints: one pose only, no text, no watermark, no border, no UI, no extra figures, no tiled checkerboard.
~~~

史莱姆与蝙蝠未在本批生成，按当前优先级待后续任务安排；旧版图片没有覆盖。
## B01 月光小法师行走循环

文件：B01_月光小法师_walk_01.png、B01_月光小法师_walk_02.png、B01_月光小法师_walk_03.png、B01_月光小法师_walk_04.png。生成源为 1254×1254 的 2×2 序列，每格 627×627，顺序为左上、右上、左下、右下；逐格规范化为 256×256 PNG。根据可见像素边界统一水平中心和脚底线；四图均为 Format32bppArgb，四角 alpha=0。目视：交替迈步和过渡帧可读，星杖始终在右手，衣披小幅摆动，无裁切或格线。

~~~text
Use case: a transparent 2D game walk-cycle sprite sheet for the same Moonlight Apprentice in reference image 2.
Input references: reference image 1 is the approved shared style board; reference image 2 is the approved final mage sprite and is the identity anchor. Preserve her exact face, white hair, oversized deep teal hood, navy cloak with burgundy lining, gold star medallion, dark tunic, brown boots, and wooden star staff.
Primary request: create exactly four consecutive full-body frames of a gentle walk cycle, all showing this same mage in place, facing right in a three-quarter top-down game view. Keep the staff in her right hand, continuously visible, with no spell effect. Walking phases in reading order: top-left near/left boot forward; top-right feet passing under the body; bottom-left opposite/right boot forward; bottom-right feet passing back toward frame one. Add only slight cloak and hair sway.
Layout: one square transparent canvas divided into an exact 2-by-2 grid of four equal square cells, reading top-left, top-right, bottom-left, bottom-right. Place exactly one complete character centered inside each cell. Keep identical character scale, head position, centerline, camera, facing direction, and foot baseline in all cells; boots land on the same horizontal baseline. Keep at least 15 percent empty transparent margin within each cell so no figure crosses a cell edge. No cell borders, gutters, labels, or overlapping figures.
Style: match reference image 1 exactly: thick midnight-blue outlines, bold cel-shaded planes, cool moonlight rim light, dark navy/teal shadows, warm gold and small crimson accents. Crisp dark comic fantasy, not photorealistic and not pixel art.
Background: true transparent alpha in every empty area; no ground, cast shadow, scenery, panel, or backdrop.
Constraints: no extra characters, no idle/attack pose, no text, watermark, logo, grid lines, checkerboard, or cropped limbs.
~~~
## B03 虎妞跑动循环

文件：B03_虎妞_walk_01.png、B03_虎妞_walk_02.png、B03_虎妞_walk_03.png、B03_虎妞_walk_04.png。生成源 1254×1254，为 2×2 序列（单格 627×627，顺序左上、右上、左下、右下），逐格输出为 256×256 PNG。四帧均为 Format32bppArgb、四角 alpha=0；边界 alpha 最大值仅 1，主体未触及格边。统一了可见轮廓中心和脚底基线。目视：前后腿交替迈步可辨，绷脸和罗威纳花色稳定；没有裁切或额外对象。

~~~text
Use case: a transparent 2D game run-cycle sprite sheet for the same Hu Niu in reference image 2.
Input references: reference image 1 is the approved shared style board; reference image 2 is the approved final Hu Niu sprite and is the exact identity anchor. Preserve her broad round Rottweiler head, short sturdy body, dark black-brown coat, distinct tan eyebrows, wide tan muzzle and paws, drooping ears, half-lidded eyes, calm stern expression and closed mouth.
Primary request: create exactly four consecutive full-body frames of a small quadruped running cycle in place, all showing Hu Niu facing right in a three-quarter top-down game view. The running phases in reading order: top-left near foreleg and opposite hind leg reach forward; top-right paws pass under the body; bottom-left the opposite foreleg and hind leg reach forward; bottom-right paws pass back toward frame one. Give the body a slight vertical bounce and a small tail sway, but keep her closed-mouth stern face.
Layout: one square transparent canvas divided into an exact 2-by-2 grid of four equal square cells, reading top-left, top-right, bottom-left, bottom-right. One complete dog in every cell. Use a smaller subject scale with at least 20 percent empty transparent margin inside every cell, especially at the center dividers. Keep identical dog size, head position, body centerline, camera, facing direction, and paw-ground baseline across all frames. Paws must not cross a cell edge. No cell borders, gutters, labels, or overlapping figures.
Style: match reference image 1 exactly: thick midnight-blue outlines, bold cel-shaded planes, cool moonlight rim light, deep navy shadows and warm tan highlights. Crisp dark comic fantasy, not photorealistic and not pixel art.
Background: true transparent alpha in every empty area; no ground, cast shadow, scenery, panel, or backdrop.
Constraints: only Hu Niu, no Hei Bao, cats, slime, collar, clothing, props, text, watermark, logo, grid lines, checkerboard, or cropped paws.
~~~
## B04 黑豹跑动循环

文件：B04_黑豹_walk_01.png、B04_黑豹_walk_02.png、B04_黑豹_walk_03.png、B04_黑豹_walk_04.png。生成源 1254×1254，为 2×2 序列（单格 627×627，顺序左上、右上、左下、右下），逐格输出为 256×256 PNG。四帧均为 Format32bppArgb、四角 alpha=0；格边 alpha 最大值 1，未见裁切。统一可见轮廓中心和脚底线。目视：交替伸腿与收腿、尾巴/舌头保持；部分过渡姿态相近，但没有完全重复帧，长身、棕色眉口与吐舌笑脸稳定。

~~~text
Use case: a transparent 2D game run-cycle sprite sheet for the same Hei Bao in reference image 2.
Input references: reference image 1 is the approved shared style board; reference image 2 is the approved final Hei Bao sprite and is the exact identity anchor. Preserve his longer, leaner Rottweiler body, black-brown coat, warm tan eyebrows, muzzle and paws, floppy ears, bright eyes, cheerful open mouth with pink tongue, and gently raised tail.
Primary request: create exactly four consecutive full-body frames of a small quadruped running cycle in place, all showing Hei Bao facing right in a three-quarter top-down game view. The running phases in reading order: top-left near foreleg and opposite hind leg reach forward; top-right paws pass under the body; bottom-left the opposite foreleg and hind leg reach forward; bottom-right paws pass back toward frame one. Add a slight body bounce and alternating tail sway. Keep his happy tongue-out expression consistent.
Layout: one square transparent canvas divided into an exact 2-by-2 grid of four equal square cells, reading top-left, top-right, bottom-left, bottom-right. One complete dog in every cell. Keep at least 20 percent empty transparent margin inside each cell, especially at the center dividers. Keep identical dog size, head position, body centerline, camera, facing direction, and paw-ground baseline across all frames. Paws and tail must not cross a cell edge. No cell borders, gutters, labels, or overlapping figures.
Style: match reference image 1 exactly: thick midnight-blue outlines, bold cel-shaded planes, cool moonlight rim light, deep navy shadows and warm tan highlights. Crisp dark comic fantasy, not photorealistic and not pixel art.
Background: true transparent alpha in every empty area; no ground, cast shadow, scenery, panel, or backdrop.
Constraints: only Hei Bao, no Hu Niu, cats, slime, collar, clothing, props, text, watermark, logo, grid lines, checkerboard, or cropped paws.
~~~
## B05 小四跑动循环

文件：B05_小四_walk_01.png、B05_小四_walk_02.png、B05_小四_walk_03.png、B05_小四_walk_04.png。生成源 1254×1254，为 2×2 序列（单格 627×627，顺序左上、右上、左下、右下），逐格输出为 256×256 PNG。四帧均为 Format32bppArgb、四角 alpha=0；格边 alpha 最大值 1，未见裁切。统一可见轮廓中心和脚底线。目视：收腿与伸腿交替、尾巴轻摆；白底、灰褐狸花头耳/身斑、白鼻梁和黄眼保持一致，无额外对象。

~~~text
Use case: a transparent 2D game run-cycle sprite sheet for the same Xiao Si in reference image 2.
Input references: reference image 1 is the approved shared style board; reference image 2 is the approved final Xiao Si sprite and is the exact identity anchor. Preserve the compact white cat, round face, gray-brown tabby crown and ears, white face blaze, gray-brown body patches, yellow eyes and small pink nose.
Primary request: create exactly four consecutive full-body frames of a small cat running in place, all showing Xiao Si facing right in a three-quarter top-down game view. The running phases in reading order: top-left near forepaw and opposite hind paw reach forward; top-right the paws pass under the body; bottom-left the opposite forepaw and hind paw reach forward; bottom-right paws pass back toward frame one. Give the body a tiny bounce and a soft tail sway; preserve the white coat and distinct markings in every frame.
Layout: one square transparent canvas divided into an exact 2-by-2 grid of four equal square cells, reading top-left, top-right, bottom-left, bottom-right. One complete cat in every cell. Keep at least 20 percent empty transparent margin inside each cell, especially at the center dividers. Keep identical cat size, head position, body centerline, camera, facing direction, and paw-ground baseline across all frames. Paws and tail must not cross a cell edge. No cell borders, gutters, labels, or overlapping figures.
Style: match reference image 1 exactly: thick midnight-blue outlines, bold cel-shaded planes, cool moonlight rim light, dark navy shadows, soft white fur, warm gray-brown markings and small amber accents. Crisp dark comic fantasy, not photorealistic and not pixel art.
Background: true transparent alpha in every empty area; no ground, cast shadow, scenery, panel, or backdrop.
Constraints: only Xiao Si, no Xiao Qi, dogs, slime, collar, clothing, props, text, watermark, logo, grid lines, checkerboard, or cropped paws.
~~~
## B06/B09 动作帧状态更新
- B06 小七四帧已生成并通过主智能体验收。
- B09 月夜领主四帧已在额度恢复后生成并通过主智能体逐张验收；旧版单帧未覆盖。

## B06 小七跑动循环

文件：B06_小七_walk_01.png、B06_小七_walk_02.png、B06_小七_walk_03.png、B06_小七_walk_04.png。生成源 1254×1254，为 2×2 序列（单格 627×627，顺序左上、右上、左下、右下），逐格输出为 256×256 PNG。四帧均为 Format32bppArgb、四角 alpha=0；格边 alpha 最大值 1，未见裁切。统一可见轮廓中心和脚底线。目视：伸腿/收腿相位清晰，深灰褐底色和额头、背部、四肢、尾部条纹保持一致，小七没有变成纯黑猫。

~~~text
Use case: a transparent 2D game run-cycle sprite sheet for the same Xiao Qi in reference image 2.
Input references: reference image 1 is the approved shared style board; reference image 2 is the approved final Xiao Qi sprite and is the exact identity anchor. Preserve the small cat's visibly medium gray-brown coat, narrow charcoal tabby stripes on forehead, cheeks, back, legs and ringed tail, warm lighter muzzle, amber-yellow eyes and compact face. Do not darken him into a black cat.
Primary request: create exactly four consecutive full-body frames of a small cat running in place, all showing Xiao Qi facing right in a three-quarter top-down game view. The running phases in reading order: top-left near forepaw and opposite hind paw reach forward; top-right paws pass under the body; bottom-left the opposite forepaw and hind paw reach forward; bottom-right paws pass back toward frame one. Give the body a small bounce and make the striped tail sway to alternating sides while preserving the tabby markings in every frame.
Layout: one square transparent canvas divided into an exact 2-by-2 grid of four equal square cells, reading top-left, top-right, bottom-left, bottom-right. One complete cat in every cell. Keep at least 20 percent empty transparent margin inside each cell, especially at the center dividers. Keep identical cat size, head position, body centerline, camera, facing direction, and paw-ground baseline across all frames. Paws and tail must not cross a cell edge. No cell borders, gutters, labels, or overlapping figures.
Style: match reference image 1 exactly: thick midnight-blue outlines, bold cel-shaded planes, cool moonlight rim light, dark navy shadows, warm gray-brown fur, clearly visible charcoal stripes and small amber highlights. Crisp dark comic fantasy, not photorealistic and not pixel art.
Background: true transparent alpha in every empty area; no ground, cast shadow, scenery, panel, or backdrop.
Constraints: only Xiao Qi, no Xiao Si, dogs, slime, collar, clothing, props, text, watermark, logo, grid lines, checkerboard, or cropped paws.
~~~
## B09 月夜领主行走循环

文件：B09_月夜领主_walk_01.png、B09_月夜领主_walk_02.png、B09_月夜领主_walk_03.png、B09_月夜领主_walk_04.png。生成源为 1254×1254 的 2×2 序列，每格 627×627，顺序左上、右上、左下、右下；逐格规整为 384×384 PNG。四帧均为 Format32bppArgb；四角 alpha 均为 0，四周边缘像素 alpha 最大值均为 0。统一可见轮廓中心和脚底基线。目视并经主智能体验收：王冠、红宝石、白毛领、绯红披风、紫色脸部和服饰身份稳定，迈步相位清楚，四帧均无裁切。

~~~text
Use case: a transparent 2D game walk-cycle sprite sheet for the same Moonlit Lord in reference image 2.
Input references: reference image 1 is the approved shared dark comic fantasy style board; reference image 2 is the approved final Moonlit Lord single sprite and is the exact identity anchor. Preserve his gold crown with a red jewel, purple face and hair, broad white spotted fur collar, flowing deep crimson cape, dark indigo tunic and armor, gold medallion and heavy brown boots. Keep his stern fanged expression and powerful broad silhouette; do not add horns or weapons.
Primary request: create exactly four consecutive full-body frames of a slow, heavy walking cycle in place, all showing this same boss facing right in a three-quarter top-down game view. Show a readable alternating step: top-left the near boot reaches forward; top-right both boots pass under the body; bottom-left the opposite boot reaches forward; bottom-right the boots pass back toward frame one. Add a restrained shoulder and arm bounce and small alternating cape sway. Keep the head, crown, arms, collar, costume, face and medallion consistent, with only subtle body motion beyond the walking limbs.
Layout: one square transparent canvas divided into an exact 2-by-2 grid of four equal square cells, reading top-left, top-right, bottom-left, bottom-right. One complete boss in every cell. Keep identical boss scale, head position, body centerline, camera, facing direction and boot-ground baseline across all frames. Leave generous transparent margin around the crown, cape and boots; no body part may cross a cell edge. No cell borders, gutters, labels or overlapping figures.
Style: match reference image 1 exactly: thick clean midnight-blue outlines, bold cel-shaded color planes, controlled ink hatching, cool moonlit rim light, deep navy and violet shadows, crimson and warm-gold accents. Crisp, polished 2D dark comic fantasy, not photorealistic and not pixel art.
Background: true transparent alpha in every empty area; no ground, cast shadow, scenery, panel, blood bar or color backdrop.
Constraints: only the Moonlit Lord, no extra characters, text, watermark, logo, grid lines, checkerboard, cropped crown, cape or boots.
~~~