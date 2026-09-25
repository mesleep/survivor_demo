## 负责筛选升级选项并提交玩家选择。
##
## 输入：只读升级池、PlayerActor 与请求数量。
## 输出：无重复可用选项和成功应用事件；不负责暂停或 UI 展示。
class_name UpgradeSystem
extends Node

signal choices_ready(choices: Array[UpgradeDefinition])
signal upgrade_applied(definition: UpgradeDefinition)

@export var upgrade_pool: Array[UpgradeDefinition] = []
## 当池中没有任何可用升级时使用的兜底选项（如金币奖励）。
@export var fallback_upgrades: Array[UpgradeDefinition] = []
## 装备成长保底：优先质变，否则给一张已持有装备的基础升级。
@export var guarantee_progression_choice: bool = true
@export_range(1.0, 30.0, 0.5) var ascension_weight_multiplier: float = 8.0
@export_range(1.0, 10.0, 0.5) var base_upgrade_weight_multiplier: float = 3.0
## 单局过半进入后期；降低普通卡权重，并提高质变占据第二、三卡位的机会。
@export_range(0.0, 1.0, 0.05) var late_game_start_ratio: float = 0.5
@export_range(0.0, 1.0, 0.05) var late_base_guarantee_chance: float = 0.5
@export_range(0.0, 1.0, 0.05) var late_base_weight_multiplier: float = 0.25
@export_range(0.0, 1.0, 0.05) var late_generic_weight_multiplier: float = 0.5
@export_range(1.0, 10.0, 0.5) var late_ascension_weight_multiplier: float = 2.5

var player: PlayerActor
var _current_choices: Array[UpgradeDefinition] = []
var _awaiting_choice: bool = false
var _random := RandomNumberGenerator.new()
## 本局剩余刷新次数（T28）；跨升级保留，重开由新场景归零。
var _remaining_refreshes: int = 0
var _run_progress_ratio: float = 0.0


func _ready() -> void:
	_random.randomize()


func initialize(new_player: PlayerActor) -> void:
	reset()
	player = new_player
	if not is_instance_valid(player):
		push_error("UpgradeSystem 初始化失败：缺少 PlayerActor。")


## 注入当前单局进度；只影响抽卡，不修改玩家或共享升级 Resource。
func set_run_progress_ratio(progress_ratio: float) -> void:
	_run_progress_ratio = clampf(progress_ratio, 0.0, 1.0)


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
	# 所有装备都满级且质变/专属都加满时，给出兜底奖励（金币），避免升级空转。
	if available.is_empty() and not fallback_upgrades.is_empty():
		for definition: UpgradeDefinition in fallback_upgrades:
			if can_offer(definition):
				available.append(definition)
	var choice_count: int = mini(requested, available.size())
	if choice_count > 0 and guarantee_progression_choice:
		var progression: Array[UpgradeDefinition] = []
		for definition: UpgradeDefinition in available:
			if definition.category == UpgradeDefinition.UpgradeCategory.ASCENSION:
				progression.append(definition)
		# 后期仍给未满级装备一条可达的质变路径，但不再每次强占卡位。
		if progression.is_empty() and (not _is_late_game() \
				or _random.randf() < late_base_guarantee_chance):
			for definition: UpgradeDefinition in available:
				if definition.category == UpgradeDefinition.UpgradeCategory.BASE_UPGRADE:
					progression.append(definition)
		if not progression.is_empty():
			var guaranteed: UpgradeDefinition = _take_weighted(progression)
			_current_choices.append(guaranteed)
			available.erase(guaranteed)
	while _current_choices.size() < choice_count:
		_current_choices.append(_take_weighted(available))
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
	# 通用卡也可能声明目标装备；任何未持有装备的专属效果都不能提前进入候选。
	if definition.category != UpgradeDefinition.UpgradeCategory.ACQUIRE_EQUIPMENT \
			and definition.get_target_equipment_id() != StringName() \
			and not player.has_equipment(definition.get_target_equipment_id()):
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
	_run_progress_ratio = 0.0
	player = null


func is_awaiting_choice() -> bool:
	return _awaiting_choice


func get_current_choices() -> Array[UpgradeDefinition]:
	return _current_choices.duplicate()


## 不放回加权抽取；质变一旦可用便提高权重，且不会重复出现在同轮三选一。
func _take_weighted(available: Array[UpgradeDefinition]) -> UpgradeDefinition:
	var total_weight: float = 0.0
	for definition: UpgradeDefinition in available:
		total_weight += _effective_weight(definition)
	if total_weight <= 0.0:
		return available.pop_at(_random.randi_range(0, available.size() - 1))
	var roll: float = _random.randf() * total_weight
	for index: int in range(available.size()):
		roll -= _effective_weight(available[index])
		if roll < 0.0:
			return available.pop_at(index)
	return available.pop_back()


func _effective_weight(definition: UpgradeDefinition) -> float:
	var result: float = maxf(definition.weight, 0.0)
	match definition.category:
		UpgradeDefinition.UpgradeCategory.ASCENSION:
			result *= ascension_weight_multiplier
			if _is_late_game():
				result *= late_ascension_weight_multiplier
		UpgradeDefinition.UpgradeCategory.BASE_UPGRADE:
			result *= base_upgrade_weight_multiplier
			if _is_late_game():
				result *= late_base_weight_multiplier
		UpgradeDefinition.UpgradeCategory.GENERIC:
			if _is_late_game():
				result *= late_generic_weight_multiplier
	return result


func _is_late_game() -> bool:
	return _run_progress_ratio >= late_game_start_ratio
