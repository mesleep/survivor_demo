## 负责筛选升级选项并提交玩家选择。
##
## 输入：只读升级池、PlayerActor 与请求数量。
## 输出：无重复可用选项和成功应用事件；不负责暂停或 UI 展示。
class_name UpgradeSystem
extends Node

signal choices_ready(choices: Array[UpgradeDefinition])
signal upgrade_applied(definition: UpgradeDefinition)

@export var upgrade_pool: Array[UpgradeDefinition] = []

var player: PlayerActor
var _current_choices: Array[UpgradeDefinition] = []
var _awaiting_choice: bool = false
var _random := RandomNumberGenerator.new()
## 本局剩余刷新次数（T28）；跨升级保留，重开由新场景归零。
var _remaining_refreshes: int = 0


func _ready() -> void:
	_random.randomize()


func initialize(new_player: PlayerActor) -> void:
	reset()
	player = new_player
	if not is_instance_valid(player):
		push_error("UpgradeSystem 初始化失败：缺少 PlayerActor。")


## 设置本局刷新次数（开局由 GameSession/Profile 注入，T28）。
func set_refresh_count(count: int) -> void:
	_remaining_refreshes = maxi(count, 0)


func get_remaining_refreshes() -> int:
	return _remaining_refreshes


## 是否可刷新：正在选择、还有次数且当前池有可用卡。
func can_refresh() -> bool:
	return _awaiting_choice and _remaining_refreshes > 0 and not _collect_available().is_empty()


## 消耗一次刷新并重新抽取可用卡；优先排除本次已展示的卡，保证刷新可见变化。
## 不改变已选升级层数，也不自动应用。
func refresh_choices(count: int = 3) -> bool:
	if not can_refresh():
		return false
	_remaining_refreshes -= 1
	_draw_choices(_current_choices.duplicate(), count)
	return true


## 从未达层数上限的定义中随机返回不重复选项。
func request_choices(count: int = 3) -> void:
	_draw_choices([], count)


func _draw_choices(exclude: Array[UpgradeDefinition], count: int) -> void:
	_current_choices.clear()
	if not is_instance_valid(player):
		choices_ready.emit(_current_choices)
		return

	var available: Array[UpgradeDefinition] = _collect_available()
	var requested: int = maxi(count, 0)
	# 池子足够时才排除旧卡，避免可用数量不足。
	if not exclude.is_empty() and available.size() >= exclude.size() + requested:
		var filtered: Array[UpgradeDefinition] = []
		for definition: UpgradeDefinition in available:
			if not exclude.has(definition):
				filtered.append(definition)
		available = filtered
	_shuffle_available(available)
	var choice_count: int = mini(requested, available.size())
	for index: int in range(choice_count):
		_current_choices.append(available[index])
	_awaiting_choice = not _current_choices.is_empty()
	choices_ready.emit(_current_choices.duplicate())


## 固定随机种子，供测试确定抽取结果。
func set_random_seed(seed_value: int) -> void:
	_random.seed = seed_value


## 当前可用（未达上限、满足前置）的升级卡，不含本次已展示的三张之外的限制。
func _collect_available() -> Array[UpgradeDefinition]:
	var available: Array[UpgradeDefinition] = []
	for definition: UpgradeDefinition in upgrade_pool:
		if can_offer(definition):
			available.append(definition)
	return available


## 只接受当前展示列表中的一次有效选择。
func apply_choice(definition: UpgradeDefinition) -> bool:
	if not _awaiting_choice or definition == null or not _current_choices.has(definition):
		return false
	if not can_offer(definition) or not player.apply_upgrade(definition):
		return false
	_awaiting_choice = false
	_current_choices.clear()
	upgrade_applied.emit(definition)
	return true


func can_offer(definition: UpgradeDefinition) -> bool:
	if definition == null or not is_instance_valid(player):
		return false
	if definition.id == StringName() or definition.max_stacks <= 0:
		return false
	if player.get_upgrade_stack(definition.id) >= definition.max_stacks:
		return false
	if definition.required_weapon_id != StringName() and not player.has_weapon(definition.required_weapon_id):
		return false
	if definition.required_equipment_id != StringName():
		var required_progress: EquipmentProgress = player.get_progress(definition.required_equipment_id)
		if required_progress == null:
			return false
		if definition.required_equipment_branch_id != StringName() \
				and required_progress.branch_id != definition.required_equipment_branch_id:
			return false

	var category: UpgradeDefinition.UpgradeCategory = definition.category
	if category == UpgradeDefinition.UpgradeCategory.GENERIC \
			and definition.type == UpgradeDefinition.UpgradeType.ACQUIRE_WEAPON:
		category = UpgradeDefinition.UpgradeCategory.ACQUIRE_EQUIPMENT

	match category:
		UpgradeDefinition.UpgradeCategory.ACQUIRE_EQUIPMENT:
			if definition.armor_definition != null:
				return player.can_acquire_armor(definition.armor_definition)
			return definition.weapon_definition != null and player.can_acquire(definition.weapon_definition)
		UpgradeDefinition.UpgradeCategory.BASE_UPGRADE:
			var base_progress: EquipmentProgress = player.get_progress(definition.get_target_equipment_id())
			return base_progress != null and base_progress.can_add_base_level()
		UpgradeDefinition.UpgradeCategory.ASCENSION:
			var ascension_progress: EquipmentProgress = player.get_progress(definition.get_target_equipment_id())
			return ascension_progress != null and ascension_progress.can_choose_branch()
		UpgradeDefinition.UpgradeCategory.BRANCH_UPGRADE:
			var branch_progress: EquipmentProgress = player.get_progress(definition.get_target_equipment_id())
			if branch_progress == null or not branch_progress.has_branch():
				return false
			if definition.branch_id != StringName() and branch_progress.branch_id != definition.branch_id:
				return false
			return branch_progress.can_add_branch_upgrade(definition.id)
		_:
			return true


func reset() -> void:
	_current_choices.clear()
	_awaiting_choice = false
	player = null


func is_awaiting_choice() -> bool:
	return _awaiting_choice


func get_current_choices() -> Array[UpgradeDefinition]:
	return _current_choices.duplicate()


## 使用系统自己的随机源洗牌，为后续按 weight 抽取保留单一入口。
func _shuffle_available(available: Array[UpgradeDefinition]) -> void:
	for index: int in range(available.size() - 1, 0, -1):
		var swap_index: int = _random.randi_range(0, index)
		var temporary: UpgradeDefinition = available[index]
		available[index] = available[swap_index]
		available[swap_index] = temporary
