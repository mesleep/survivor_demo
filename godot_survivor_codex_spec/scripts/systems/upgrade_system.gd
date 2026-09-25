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


func _ready() -> void:
	_random.randomize()


func initialize(new_player: PlayerActor) -> void:
	reset()
	player = new_player
	if not is_instance_valid(player):
		push_error("UpgradeSystem 初始化失败：缺少 PlayerActor。")


## 从未达层数上限的定义中随机返回不重复选项。
func request_choices(count: int = 3) -> void:
	_current_choices.clear()
	if not is_instance_valid(player):
		choices_ready.emit(_current_choices)
		return

	var available: Array[UpgradeDefinition] = []
	for definition: UpgradeDefinition in upgrade_pool:
		if can_offer(definition):
			available.append(definition)
	_shuffle_available(available)
	var choice_count: int = mini(maxi(count, 0), available.size())
	for index: int in range(choice_count):
		_current_choices.append(available[index])
	_awaiting_choice = not _current_choices.is_empty()
	choices_ready.emit(_current_choices.duplicate())


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
