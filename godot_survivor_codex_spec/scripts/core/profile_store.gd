## 版本化档案的安全读写（T27）。
##
## 输入：存档路径、已知 ID 列表与默认解锁。
## 输出：Profile 或加载错误状态；写入采用“临时文件 → 校验 → 替换 → 备份恢复”。
## 边界：只序列化 Profile.to_dict() 的标量与稳定 ID，不保存 Node/Resource/场景。
class_name ProfileStore
extends RefCounted

const DEFAULT_SAVE_PATH := "user://profile.json"

var save_path: String = DEFAULT_SAVE_PATH
var last_error: String = ""
## 测试注入：为 true 时 save_profile 直接失败且不触碰任何文件。
var write_failure_injected: bool = false
var known_character_ids: Array[StringName] = []
var known_weapon_ids: Array[StringName] = []
var default_character_ids: Array[StringName] = []
var default_weapon_ids: Array[StringName] = []


func _init(new_save_path: String = DEFAULT_SAVE_PATH) -> void:
	save_path = new_save_path


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## 读取档案；无档、损坏或版本不支持时返回默认档案并把原因写入 last_error。
func load_profile() -> Profile:
	last_error = ""
	if not has_save():
		return _create_default()
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		last_error = "无法读取存档。"
		return _create_default()
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = _parse_json(text)
	if parsed == null or not (parsed is Dictionary):
		last_error = "存档损坏，已使用默认档案。"
		return _create_default()
	var profile: Profile = Profile.from_dict(parsed, known_character_ids, known_weapon_ids)
	if profile == null:
		last_error = "存档版本不受支持，已使用默认档案。"
		return _create_default()
	return profile


## 原子写入：先写 .tmp 并回读校验，再备份旧档并替换；任一步失败都保留旧档。
func save_profile(profile: Profile) -> bool:
	last_error = ""
	if profile == null:
		last_error = "档案为空，无法保存。"
		return false
	if write_failure_injected:
		last_error = "写入失败（测试注入）。"
		return false

	var base_dir: String = save_path.get_base_dir()
	if base_dir != "" and not DirAccess.dir_exists_absolute(base_dir):
		if DirAccess.make_dir_recursive_absolute(base_dir) != OK:
			last_error = "无法创建存档目录。"
			return false

	var tmp_path: String = save_path + ".tmp"
	var tmp_file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null:
		last_error = "无法写入临时存档。"
		return false
	tmp_file.store_string(JSON.stringify(profile.to_dict(), "  "))
	tmp_file.close()

	var verify_file: FileAccess = FileAccess.open(tmp_path, FileAccess.READ)
	if verify_file == null:
		last_error = "无法校验临时存档。"
		return false
	var verify_parsed: Variant = _parse_json(verify_file.get_as_text())
	verify_file.close()
	if verify_parsed == null or not (verify_parsed is Dictionary):
		last_error = "临时存档校验失败。"
		return false

	var directory: DirAccess = DirAccess.open(base_dir)
	if directory == null:
		last_error = "无法打开存档目录。"
		return false
	var bak_path: String = save_path + ".bak"
	if has_save():
		if FileAccess.file_exists(bak_path):
			directory.remove(bak_path.get_file())
		if directory.rename(save_path.get_file(), bak_path.get_file()) != OK:
			last_error = "无法备份旧存档。"
			return false
	if directory.rename(tmp_path.get_file(), save_path.get_file()) != OK:
		if FileAccess.file_exists(bak_path):
			directory.rename(bak_path.get_file(), save_path.get_file())
		last_error = "无法替换存档。"
		return false
	if FileAccess.file_exists(bak_path):
		directory.remove(bak_path.get_file())
	return true


## 删除正式/临时/备份档，仅测试与“重置进度”使用。
func delete_save() -> void:
	for path: String in [save_path, save_path + ".tmp", save_path + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 用 JSON 实例解析，避免 parse_string 在损坏档上打印引擎错误。
static func _parse_json(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.get_data()


func _create_default() -> Profile:
	var profile := Profile.new()
	profile.version = Profile.CURRENT_VERSION
	profile.unlocked_character_ids = default_character_ids.duplicate()
	profile.unlocked_weapon_ids = default_weapon_ids.duplicate()
	return profile
