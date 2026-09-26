## 数值/素材工作台的服务层：分类清单、资源加载、属性收集与保存。
##
## 与 UI 分离，可在 headless 测试中直接验证；只读写 Resource，不持有场景节点。
## 字段中文名从脚本源码里 `@export` 上方连续的 `##` 注释解析，避免两处维护。
class_name ConfigWorkbenchService
extends RefCounted

const CATEGORIES: Array[Dictionary] = [
	{"id": "characters", "name": "角色", "path": "res://data/characters"},
	{"id": "weapons", "name": "武器", "path": "res://data/weapons"},
	{"id": "projectiles", "name": "弹体", "path": "res://data/projectiles"},
	{"id": "upgrades", "name": "升级卡", "path": "res://data/upgrades"},
	{"id": "armor", "name": "防具与质变", "path": "res://data/armor"},
	{"id": "enemies", "name": "敌人", "path": "res://data/enemies"},
	{"id": "maps", "name": "地图", "path": "res://data/maps"},
	{"id": "waves", "name": "波次与难度", "path": "res://data/waves"},
	{"id": "combat", "name": "战斗规则与效果", "path": "res://data/combat"},
	{"id": "economy", "name": "经济", "path": "res://data/economy"},
	{"id": "progression", "name": "永久强化", "path": "res://data/progression"},
	{"id": "catalog", "name": "内容目录", "path": "res://data/catalog"},
	{"id": "ui_visuals", "name": "界面样式与贴图", "path": "res://data/visuals/v2_dark_comic"},
]

const SKIP_PROPERTIES: PackedStringArray = [
	"script",
	"resource_path",
	"resource_name",
	"resource_local_to_scene",
	"resource_scene_unique_id",
	"resource_uid",
]

static var _label_cache: Dictionary = {}
static var _comment_cache: Dictionary = {}


static func get_categories() -> Array[Dictionary]:
	return CATEGORIES.duplicate(true)


static func find_category(category_id: String) -> Dictionary:
	for category: Dictionary in CATEGORIES:
		if String(category["id"]) == category_id:
			return category
	return {}


## 分类下的 .tres 资源路径，按文件名排序。
static func list_resource_paths(category_id: String) -> Array[String]:
	var result: Array[String] = []
	var category: Dictionary = find_category(category_id)
	if category.is_empty():
		return result
	var folder: String = String(category["path"])
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.ends_with(".tres"):
			result.append("%s/%s" % [folder, file_name])
	result.sort()
	return result


static func load_resource(path: String) -> Resource:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path)


## 保存到资源自身路径；没有路径（内联子资源）时返回 ERR_UNCONFIGURED。
static func save_resource(resource: Resource) -> Error:
	if resource == null:
		return ERR_INVALID_PARAMETER
	if resource.resource_path.is_empty():
		return ERR_UNCONFIGURED
	return ResourceSaver.save(resource, resource.resource_path)


## 收集可编辑行：分组标题 + 属性。每行是字典：
## {kind, name, label, comment, type, hint, hint_string, class_name}
static func collect_rows(resource: Resource) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if resource == null:
		return rows
	var labels: Dictionary = _get_field_labels(resource)
	for property: Dictionary in resource.get_property_list():
		var usage: int = int(property.get("usage", 0))
		if usage == PROPERTY_USAGE_GROUP or usage == PROPERTY_USAGE_SUBGROUP:
			if String(property["name"]) in ["", "Resource"]:
				continue
			rows.append({
				"kind": "group",
				"name": String(property["name"]),
				"label": String(property["name"]),
			})
			continue
		if usage & PROPERTY_USAGE_EDITOR == 0:
			continue
		if usage & PROPERTY_USAGE_INTERNAL != 0:
			continue
		var property_name: String = String(property["name"])
		if property_name in SKIP_PROPERTIES or property_name.begins_with("_"):
			continue
		var comment: String = String(labels.get(property_name, ""))
		rows.append({
			"kind": "property",
			"name": property_name,
			"label": comment if not comment.is_empty() else property_name,
			"comment": comment,
			"type": int(property["type"]),
			"hint": int(property.get("hint", 0)),
			"hint_string": String(property.get("hint_string", "")),
			"class_name": String(property.get("class_name", "")),
		})
	return rows


static func is_texture_property(row: Dictionary) -> bool:
	return int(row.get("type", 0)) == TYPE_OBJECT \
		and String(row.get("class_name", "")) in ["Texture2D", "CompressedTexture2D", "ImageTexture", "AtlasTexture"]


static func is_sprite_frames_property(row: Dictionary) -> bool:
	return int(row.get("type", 0)) == TYPE_OBJECT and String(row.get("class_name", "")) == "SpriteFrames"


static func is_asset_row(row: Dictionary) -> bool:
	return is_texture_property(row) or is_sprite_frames_property(row)


## 其余 Resource / PackedScene 引用（弹体、升级目录、场景等），可导航编辑或更换引用。
static func is_resource_property(row: Dictionary) -> bool:
	if int(row.get("type", 0)) != TYPE_OBJECT:
		return false
	if is_asset_row(row):
		return false
	var type_name: String = resource_class_of(row)
	if type_name.is_empty():
		return false
	if not ClassDB.class_exists(type_name):
		return true
	var current: String = type_name
	while not current.is_empty():
		if current == "Resource":
			return true
		current = String(ClassDB.get_parent_class(current))
	return false


## 属性声明的目标类：优先 class_name，退回 hint_string。
static func resource_class_of(row: Dictionary) -> String:
	var type_name: String = String(row.get("class_name", ""))
	if type_name.is_empty():
		type_name = String(row.get("hint_string", ""))
	return type_name


## 数组元素数量；资源数组可展开查看元素。
static func is_array_property(row: Dictionary) -> bool:
	return int(row.get("type", 0)) == TYPE_ARRAY


static func get_field_label(resource: Resource, property_name: String) -> String:
	var labels: Dictionary = _get_field_labels(resource)
	return String(labels.get(property_name, property_name))


## 资源显示名：display_name / id / 文件名。
static func get_resource_display_name(resource: Resource, path: String = "") -> String:
	if resource != null:
		if "display_name" in resource and not String(resource.get("display_name")).is_empty():
			return String(resource.get("display_name"))
		if "id" in resource and not String(resource.get("id")).is_empty():
			return String(resource.get("id"))
	var source_path: String = path if not path.is_empty() else (resource.resource_path if resource != null else "")
	return source_path.get_file().get_basename()


## 解析脚本注释：@export 上方连续的 ## 行作为中文字段说明。
static func _get_field_labels(resource: Resource) -> Dictionary:
	var script: Script = resource.get_script() as Script
	if script == null:
		return {}
	var script_path: String = script.resource_path
	if script_path.is_empty():
		return {}
	if _label_cache.has(script_path):
		return _label_cache[script_path]
	var labels: Dictionary = {}
	var source: String = FileAccess.get_file_as_string(script_path)
	if not source.is_empty():
		var pending: Array[String] = []
		var regex := RegEx.new()
		regex.compile("var\\s+([A-Za-z_][A-Za-z0-9_]*)")
		for raw_line: String in source.split("\n"):
			var line: String = raw_line.strip_edges()
			if line.begins_with("##"):
				pending.append(line.substr(2).strip_edges())
				continue
			if line.begins_with("@") or line.begins_with("var "):
				var match_result: RegExMatch = regex.search(line)
				if match_result != null and not pending.is_empty():
					labels[match_result.get_string(1)] = " ".join(pending)
				pending.clear()
				continue
			pending.clear()
	_label_cache[script_path] = labels
	return labels
