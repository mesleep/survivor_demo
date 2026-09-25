## 玩家角色的移动行为。
##
## 输入：CharacterDefinition 和 InputMap 中的四个移动动作。
## 输出：经过归一化的 CharacterBody2D 速度与物理移动。
## 扩展点：后续将把运行时移速和攻击范围修正叠加到基础值上，不修改共享 Resource。
class_name PlayerActor
extends ActorBase

signal experience_changed(current_experience: int, gained_amount: int)
## 本局已拾取金币变化（T26）；结算金币不在此信号内。
signal coins_changed(current_coins: int)
signal level_progress_changed(current_level: int, current_experience: int, required_experience: int)
signal leveled_up(new_level: int, pending_upgrade_count: int)
signal upgrade_state_changed(upgrade_id: StringName, stack_count: int)
signal weapon_added(controller: WeaponController)
## 装备清单变化（含起始武器）；参数为当前装备 ID 副本，供 UI 只读展示。
signal equipment_changed(equipped_ids: Array[StringName])
## 单件装备成长状态变化；携带只读快照，UI 不直接修改运行时对象。
signal equipment_progress_changed(equipment_id: StringName, snapshot: EquipmentProgress)
## 获得防具；防具不创建 WeaponController，只登记清单与类别。
signal armor_acquired(definition: ArmorDefinition)
## 科技三件套激活/失活（T25）；只在状态真正变化时各发一次。
signal tech_set_activated()
signal tech_set_deactivated()

## D02：武器与防具共用六格，同一 ID 不重复装备；升级不占新格。
const MAX_EQUIPMENT_SLOTS := 6

var definition: CharacterDefinition
var weapon_controllers: Array[WeaponController] = []
var _move_speed: float = 0.0
var _base_attack_range: float = 0.0
var _current_experience: int = 0
## 本局内存金币余额（T26）；持久化由 T27 档案负责。
var _run_coins: int = 0
var _current_level_experience: int = 0
var _current_level: int = 1
var _pending_upgrade_count: int = 0
var _upgrade_stacks: Dictionary[StringName, int] = {}
var _move_speed_multiplier: float = 1.0
var _maximum_health_bonus: float = 0.0
var _pickup_range_multiplier: float = 1.0
var _all_weapon_range_multiplier: float = 1.0
var _upgrade_defense_bonus: float = 0.0
var _armor_defense_bonus: float = 0.0
var _knight_defense_bonus: float = 0.0
var _armor_move_penalty_ratio: float = 0.0
var _glove_cooldown_multiplier: float = 1.0
var _glove_range_multiplier: float = 1.0
var _tech_pieces: Dictionary[StringName, TechArmorDefinition] = {}
var _tech_experience_clock: float = 0.0
var _tech_set_definition: TechSetDefinition
var _tech_set_active: bool = false
var _tech_set_move_multiplier: float = 1.0
var _set_weapon_controller: WeaponController
var _regeneration: float = 0.0
var _regeneration_clock: float = 0.0
## 永久强化（T30）：开局从档案快照写入，运行中不再读取档案。
var _permanent_move_multiplier: float = 1.0
var _permanent_lifesteal_ratio: float = 0.0
var _permanent_defense: float = 0.0
var _permanent_regeneration: float = 0.0
## 角色被动（T31）：对带标签武器的伤害倍率与适用标签。
var _passive_damage_multiplier: float = 1.0
var _passive_weapon_tag: StringName = StringName()
var _weapon_modifier_history: Array[Dictionary] = []
var _projectile_parent: Node
var _targeting_service: TargetingService
var _candidate_weapon_ids: Array[StringName] = []
var _equipped_equipment_ids: Array[StringName] = []
var _equipment_categories: Dictionary[StringName, StringName] = {}
var _armor_definitions: Dictionary[StringName, ArmorDefinition] = {}
var _equipment_progress: Dictionary[StringName, EquipmentProgress] = {}
var _thorn_aura: ThornAuraComponent
var _thorn_aura_radius_multiplier: float = 1.0
var _berserk_definition: BerserkArmorDefinition
var _berserk_drain: BerserkDrainComponent
var _berserk_half_lifesteal_bonus: float = 0.0
var _berserk_drain_reduction: float = 0.0

@onready var camera: Camera2D = %Camera2D
@onready var pickup_component: PickupComponent = %PickupComponent
@onready var weapon_controller_parent: Node = %WeaponControllers


func _ready() -> void:
	super._ready()
	if not pickup_component.pickup_detected.is_connected(_on_pickup_detected):
		pickup_component.pickup_detected.connect(_on_pickup_detected)


## 从共享配置初始化玩家的基础运行时数据。
##
## 该方法只读取 Resource；单局修正不得回写配置。
func initialize(new_definition: Resource) -> void:
	if new_definition is not CharacterDefinition:
		push_error("PlayerActor 初始化失败：Resource 必须是 CharacterDefinition。")
		set_physics_process(false)
		return

	definition = new_definition as CharacterDefinition
	super.initialize(new_definition)
	_move_speed = maxf(definition.move_speed, 0.0)
	_base_attack_range = maxf(definition.base_attack_range, 0.0)
	var camera_zoom_value: float = clampf(definition.camera_zoom, 0.25, 2.0)
	camera.zoom = Vector2.ONE * camera_zoom_value
	_current_experience = 0
	_run_coins = 0
	_current_level_experience = 0
	_current_level = 1
	_pending_upgrade_count = 0
	_upgrade_stacks.clear()
	_move_speed_multiplier = 1.0
	_maximum_health_bonus = 0.0
	_pickup_range_multiplier = 1.0
	_all_weapon_range_multiplier = 1.0
	_upgrade_defense_bonus = 0.0
	_armor_defense_bonus = 0.0
	_knight_defense_bonus = 0.0
	_armor_move_penalty_ratio = 0.0
	_glove_cooldown_multiplier = 1.0
	_glove_range_multiplier = 1.0
	_tech_pieces.clear()
	_tech_experience_clock = 0.0
	_tech_set_active = false
	_tech_set_move_multiplier = 1.0
	_set_weapon_controller = null
	set_defense(0.0)
	set_immune_chance(0.0)
	set_damage_reflect_ratio(0.0)
	set_death_immunity_available(false)
	_clear_thorn_aura()
	_thorn_aura_radius_multiplier = 1.0
	_clear_berserk_drain()
	_berserk_definition = null
	_berserk_half_lifesteal_bonus = 0.0
	_berserk_drain_reduction = 0.0
	_regeneration = 0.0
	_regeneration_clock = 0.0
	_permanent_move_multiplier = 1.0
	_permanent_lifesteal_ratio = 0.0
	_permanent_defense = 0.0
	_permanent_regeneration = 0.0
	_passive_damage_multiplier = 1.0 + maxf(definition.passive_damage_multiplier, 0.0)
	_passive_weapon_tag = definition.passive_weapon_tag
	_weapon_modifier_history.clear()
	_candidate_weapon_ids.clear()
	_equipped_equipment_ids.clear()
	_equipment_categories.clear()
	_armor_definitions.clear()
	_equipment_progress.clear()
	pickup_component.initialize(definition.pickup_radius)
	set_physics_process(true)
	level_progress_changed.emit(_current_level, _current_level_experience, get_required_experience())


## 使摄像机与场地边界使用同一份范围。
##
## Camera2D 的 limit 使用整数，因此在边界处向外取整，避免露出场地外的背景。
func configure_camera_bounds(bounds: Rect2) -> void:
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)


## 根据角色配置创建独立的武器控制器，并注入本局服务与容器。
##
## 重复配置会安全停用旧实例；每个起始武器对应一个控制器，支持未来多武器角色。
func configure_weapons(
		weapon_definitions: Array[WeaponDefinition],
		projectile_parent: Node,
		targeting_service: TargetingService
) -> void:
	clear_weapons()
	_equipped_equipment_ids.clear()
	_equipment_categories.clear()
	_armor_definitions.clear()
	_equipment_progress.clear()
	_projectile_parent = projectile_parent
	_targeting_service = targeting_service
	if not is_instance_valid(projectile_parent) or not is_instance_valid(targeting_service):
		push_error("PlayerActor 武器配置失败：缺少子弹容器或索敌服务。")
		return

	for weapon_definition: WeaponDefinition in weapon_definitions:
		add_weapon(weapon_definition, true)


## 新武器继承已选通用强化；只创建控制器，不重复加载角色或重置原武器。
func add_weapon(weapon_definition: WeaponDefinition, allow_duplicate: bool = false) -> bool:
	if weapon_definition == null or (not allow_duplicate and has_weapon(weapon_definition.id)):
		return false
	if not is_instance_valid(_projectile_parent) or not is_instance_valid(_targeting_service):
		return false
	var controller := WeaponController.new()
	controller.name = "WeaponController_%s" % weapon_definition.id
	controller.visual_slot = weapon_controllers.size()
	weapon_controller_parent.add_child(controller)
	controller.initialize(weapon_definition, self, _projectile_parent)
	controller.set_targeting_service(_targeting_service)
	for record: Dictionary in _weapon_modifier_history:
		if record.target == StringName() or record.target == weapon_definition.id:
			controller.apply_runtime_modifier(record.modifier as WeaponRuntimeModifier)
	# 角色被动：只对带指定标签的武器生效，晚获取同样继承（T31）。
	if _passive_weapon_tag != StringName() and weapon_definition.tags.has(_passive_weapon_tag):
		controller.apply_runtime_modifier(
			WeaponRuntimeModifier.new(1.0, 0, _passive_damage_multiplier)
		)
	weapon_controllers.append(controller)
	_register_equipment(weapon_definition.id, &"weapon")
	weapon_added.emit(controller)
	return true


func has_weapon(weapon_id: StringName) -> bool:
	for controller: WeaponController in weapon_controllers:
		if is_instance_valid(controller) and controller.definition.id == weapon_id:
			return true
	return false


## 注入本局候选武器 ID（来自 RunLoadout）；空数组表示不限制，保持旧直启兼容。
func configure_equipment(candidate_weapon_ids: Array[StringName]) -> void:
	_candidate_weapon_ids = candidate_weapon_ids.duplicate()


func get_candidate_weapon_ids() -> Array[StringName]:
	return _candidate_weapon_ids.duplicate()


func get_equipped_ids() -> Array[StringName]:
	return _equipped_equipment_ids.duplicate()


func get_equipped_count() -> int:
	return _equipped_equipment_ids.size()


func has_equipment(equipment_id: StringName) -> bool:
	return _equipped_equipment_ids.has(equipment_id)


func is_equipment_full() -> bool:
	return _equipped_equipment_ids.size() >= MAX_EQUIPMENT_SLOTS


## 判断一件武器是否可作为新装备获取：未持有、未满格、且在候选池内。
##
## 只读查询，不修改任何状态；UpgradeSystem 与测试都通过它统一过滤 D02/D03。
func can_acquire(weapon_definition: WeaponDefinition) -> bool:
	if weapon_definition == null or weapon_definition.id == StringName():
		return false
	if has_equipment(weapon_definition.id):
		return false
	if is_equipment_full():
		return false
	if not _candidate_weapon_ids.is_empty() and not _candidate_weapon_ids.has(weapon_definition.id):
		return false
	return true


## 新武器获取的唯一入口：先校验槽位/候选/重复，再创建控制器。
func try_acquire_weapon(weapon_definition: WeaponDefinition) -> bool:
	if not can_acquire(weapon_definition):
		return false
	return add_weapon(weapon_definition, false)


func _register_equipment(equipment_id: StringName, category: StringName = &"weapon") -> void:
	if equipment_id == StringName() or _equipped_equipment_ids.has(equipment_id):
		return
	if _equipped_equipment_ids.size() >= MAX_EQUIPMENT_SLOTS:
		return
	if not _equipment_progress.has(equipment_id):
		_equipment_progress[equipment_id] = EquipmentProgress.new(equipment_id)
	_equipment_categories[equipment_id] = category
	_equipped_equipment_ids.append(equipment_id)
	equipment_changed.emit(_equipped_equipment_ids.duplicate())
	_emit_equipment_progress(equipment_id)


## 防具获取：与武器共用格数/重复/满格规则，但不创建武器控制器。
func can_acquire_armor(armor_definition: ArmorDefinition) -> bool:
	if armor_definition == null or armor_definition.id == StringName():
		return false
	if has_equipment(armor_definition.id):
		return false
	if is_equipment_full():
		return false
	return true


func try_acquire_armor(armor_definition: ArmorDefinition) -> bool:
	if not can_acquire_armor(armor_definition):
		return false
	_armor_definitions[armor_definition.id] = armor_definition
	_register_equipment(armor_definition.id, &"armor")
	_refresh_armor_bonuses()
	armor_acquired.emit(armor_definition)
	return true


## 按已装备防具与其基础等级重算防御与移速惩罚，只改运行时属性。
func _refresh_armor_bonuses() -> void:
	var defense_total: float = 0.0
	var move_multiplier: float = 1.0
	var cooldown_multiplier: float = 1.0
	var range_multiplier: float = 1.0
	for armor_id: StringName in _armor_definitions.keys():
		var armor: ArmorDefinition = _armor_definitions[armor_id]
		if armor == null:
			continue
		var level: int = 1
		var progress: EquipmentProgress = _equipment_progress.get(armor_id)
		if progress != null:
			level = progress.base_level
		defense_total += armor.get_defense_for_level(level)
		move_multiplier *= 1.0 - armor.get_move_penalty_for_level(level)
		cooldown_multiplier *= armor.get_cooldown_multiplier_for_level(level)
		range_multiplier *= armor.get_range_multiplier_for_level(level)
	_armor_defense_bonus = defense_total
	_armor_move_penalty_ratio = clampf(1.0 - move_multiplier, 0.0, 1.0)
	_glove_cooldown_multiplier = clampf(cooldown_multiplier, 0.05, 1.0)
	_glove_range_multiplier = maxf(range_multiplier, 0.0)
	_refresh_defense()


func _refresh_defense() -> void:
	set_defense(
		_upgrade_defense_bonus + _armor_defense_bonus + _knight_defense_bonus + _permanent_defense
	)


func get_armor_move_penalty_ratio() -> float:
	return _armor_move_penalty_ratio


## 手套等装备提供的全武器冷却倍率（T24）。
func get_bonus_cooldown_multiplier() -> float:
	return _glove_cooldown_multiplier


## 手套等装备提供的全武器射程倍率（T24）。
func get_bonus_range_multiplier() -> float:
	return _glove_range_multiplier


## 已选科技质变的单件汇总每秒经验（T24）。
func get_tech_experience_per_second() -> float:
	var total: float = 0.0
	for definition: TechArmorDefinition in _tech_pieces.values():
		if definition != null:
			total += definition.experience_per_second
	return total


## 宝石经验倍率：各科技单件相乘（T24）。
func get_experience_gain_multiplier() -> float:
	var multiplier: float = 1.0
	for definition: TechArmorDefinition in _tech_pieces.values():
		if definition != null:
			multiplier *= maxf(definition.gem_experience_multiplier, 0.0)
	return multiplier


## 推进科技经验计时；暂停时不由 _process 调用，因此暂停不计时（T24）。
func advance_tech_time(delta: float) -> void:
	if _tech_pieces.is_empty() or delta <= 0.0:
		return
	_tech_experience_clock += delta
	var xp_per_second: float = get_tech_experience_per_second()
	if xp_per_second <= 0.0:
		return
	while _tech_experience_clock >= 1.0:
		_tech_experience_clock -= 1.0
		add_experience(roundi(xp_per_second))


func _process(delta: float) -> void:
	advance_tech_time(delta)


func has_armor(armor_id: StringName) -> bool:
	return _armor_definitions.has(armor_id)


func get_armor_definition(armor_id: StringName) -> ArmorDefinition:
	return _armor_definitions.get(armor_id)


## 返回装备类别：&"weapon" / &"armor"；未持有时返回空 StringName。
func get_equipped_category(equipment_id: StringName) -> StringName:
	return _equipment_categories.get(equipment_id, StringName())


func get_equipped_weapon_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for equipment_id: StringName in _equipped_equipment_ids:
		if _equipment_categories.get(equipment_id, &"") == &"weapon":
			ids.append(equipment_id)
	return ids


func get_equipped_armor_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for equipment_id: StringName in _equipped_equipment_ids:
		if _equipment_categories.get(equipment_id, &"") == &"armor":
			ids.append(equipment_id)
	return ids


## 返回单件装备成长的只读快照；未持有时返回 null。
func get_progress(equipment_id: StringName) -> EquipmentProgress:
	if not _equipment_progress.has(equipment_id):
		return null
	return _equipment_progress[equipment_id].copy()


func has_equipment_progress(equipment_id: StringName) -> bool:
	return _equipment_progress.has(equipment_id)


## 提升基础等级，每件装备独立，达到上限后返回 false。
func add_equipment_base_level(equipment_id: StringName) -> bool:
	if not _equipment_progress.has(equipment_id):
		return false
	if not _equipment_progress[equipment_id].add_base_level():
		return false
	_emit_equipment_progress(equipment_id)
	return true


## 质变资格：已持有、基础满级且尚未选择分支，且分支 ID 非空。
func can_choose_equipment_branch(equipment_id: StringName, branch_id: StringName) -> bool:
	if branch_id == StringName() or not _equipment_progress.has(equipment_id):
		return false
	return _equipment_progress[equipment_id].can_choose_branch()


## 选择一次互斥质变；已有分支后再次调用返回 false。
func choose_equipment_branch(equipment_id: StringName, branch_id: StringName) -> bool:
	if not can_choose_equipment_branch(equipment_id, branch_id):
		return false
	if not _equipment_progress[equipment_id].choose_branch(branch_id):
		return false
	_emit_equipment_progress(equipment_id)
	return true


## 提升质变专属升级层数；需先选分支且未达专属上限。
func add_equipment_branch_upgrade(equipment_id: StringName, upgrade_id: StringName) -> bool:
	if not _equipment_progress.has(equipment_id):
		return false
	if not _equipment_progress[equipment_id].add_branch_upgrade(upgrade_id):
		return false
	_emit_equipment_progress(equipment_id)
	return true


func _emit_equipment_progress(equipment_id: StringName) -> void:
	if not _equipment_progress.has(equipment_id):
		return
	equipment_progress_changed.emit(equipment_id, _equipment_progress[equipment_id].copy())


func clear_weapons() -> void:
	for controller: WeaponController in weapon_controllers:
		if not is_instance_valid(controller):
			continue
		controller.set_process(false)
		controller.queue_free()
	weapon_controllers.clear()
	_set_weapon_controller = null


## 增加本局经验，并将跨越的每个等级转化为一项待选择升级。
##
## `_current_experience` 保留本局累计值供统计；HUD 使用独立的等级内经验。
func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	_current_experience += amount
	_current_level_experience += amount
	while _current_level_experience >= get_required_experience():
		_current_level_experience -= get_required_experience()
		_current_level += 1
		_pending_upgrade_count += 1
		leveled_up.emit(_current_level, _pending_upgrade_count)
	experience_changed.emit(_current_experience, amount)
	level_progress_changed.emit(_current_level, _current_level_experience, get_required_experience())


func get_current_experience() -> int:
	return _current_experience


## 累加本局拾取金币（T26）；只写运行时，不接触存档。
func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	_run_coins += amount
	coins_changed.emit(_run_coins)


func get_run_coins() -> int:
	return _run_coins


func get_current_level_experience() -> int:
	return _current_level_experience


func get_current_level() -> int:
	return _current_level


## 返回当前等级升至下一级所需经验，经验曲线只在此处维护。
func get_required_experience(level: int = _current_level) -> int:
	return 5 + maxi(level, 1) * 3


func get_pending_upgrade_count() -> int:
	return _pending_upgrade_count


func consume_pending_upgrade() -> bool:
	if _pending_upgrade_count <= 0:
		return false
	_pending_upgrade_count -= 1
	return true


func get_upgrade_stack(upgrade_id: StringName) -> int:
	return _upgrade_stacks.get(upgrade_id, 0)


## 将一个升级效果写入玩家和武器的单局状态，不回写任何共享 Resource。
func apply_upgrade(upgrade: UpgradeDefinition) -> bool:
	if upgrade == null or upgrade.id == StringName():
		return false
	if get_upgrade_stack(upgrade.id) >= upgrade.max_stacks:
		return false
	if upgrade.required_weapon_id != StringName() and not has_weapon(upgrade.required_weapon_id):
		return false
	if upgrade.category == UpgradeDefinition.UpgradeCategory.BASE_UPGRADE:
		var base_target: StringName = upgrade.get_target_equipment_id()
		if not add_equipment_base_level(base_target):
			return false
		_refresh_armor_bonuses()
		if has_armor(base_target):
			return _finalize_upgrade(upgrade)
	elif upgrade.category == UpgradeDefinition.UpgradeCategory.ASCENSION:
		if not choose_equipment_branch(upgrade.get_target_equipment_id(), upgrade.branch_id):
			return false
	elif upgrade.category == UpgradeDefinition.UpgradeCategory.BRANCH_UPGRADE:
		if not add_equipment_branch_upgrade(upgrade.get_target_equipment_id(), upgrade.id):
			return false
	# 捆绑修正（如威能质变一次性提高伤害/攻速/射程）；先于 type 效果应用。
	if upgrade.weapon_modifier != null:
		_apply_weapon_modifier(upgrade.weapon_modifier, upgrade.required_weapon_id)
	match upgrade.type:
		UpgradeDefinition.UpgradeType.DAMAGE_MULTIPLIER:
			_apply_weapon_modifier(WeaponRuntimeModifier.new(1.0, 0, 1.0 + upgrade.value), upgrade.required_weapon_id)
		UpgradeDefinition.UpgradeType.FIRE_RATE_MULTIPLIER:
			_apply_weapon_modifier(WeaponRuntimeModifier.new(maxf(1.0 - upgrade.value, 0.05), 0, 1.0), upgrade.required_weapon_id)
		UpgradeDefinition.UpgradeType.PROJECTILE_COUNT:
			_apply_weapon_modifier(WeaponRuntimeModifier.new(1.0, roundi(upgrade.value), 1.0), upgrade.required_weapon_id)
		UpgradeDefinition.UpgradeType.MOVE_SPEED_MULTIPLIER:
			_move_speed_multiplier *= maxf(1.0 + upgrade.value, 0.0)
		UpgradeDefinition.UpgradeType.MAX_HEALTH:
			_maximum_health_bonus += upgrade.value
			health_component.set_maximum_health(get_effective_maximum_health(), true)
		UpgradeDefinition.UpgradeType.HEAL:
			health_component.heal(upgrade.value)
		UpgradeDefinition.UpgradeType.BONUS_PROJECTILE_CHANCE:
			_apply_weapon_modifier(WeaponRuntimeModifier.new(1.0, 0, 1.0, upgrade.value, 0.0), upgrade.required_weapon_id)
		UpgradeDefinition.UpgradeType.PROJECTILE_LIFESTEAL:
			_apply_weapon_modifier(WeaponRuntimeModifier.new(1.0, 0, 1.0, 0.0, upgrade.value), upgrade.required_weapon_id)
		UpgradeDefinition.UpgradeType.PICKUP_RANGE_MULTIPLIER:
			_pickup_range_multiplier *= maxf(1.0 + upgrade.value, 0.0)
			pickup_component.initialize(get_effective_pickup_radius())
		UpgradeDefinition.UpgradeType.ALL_WEAPON_RANGE:
			_all_weapon_range_multiplier *= maxf(1.0 + upgrade.value, 0.0)
		UpgradeDefinition.UpgradeType.DEFENSE:
			_upgrade_defense_bonus += upgrade.value
			_refresh_defense()
		UpgradeDefinition.UpgradeType.DODGE_CHANCE:
			add_dodge_chance(upgrade.value)
		UpgradeDefinition.UpgradeType.IMMUNE_CHANCE:
			add_immune_chance(upgrade.value)
		UpgradeDefinition.UpgradeType.REPEAT_SHOT_CHANCE:
			_apply_weapon_modifier(WeaponRuntimeModifier.new(1.0, 0, 1.0, 0.0, 0.0, upgrade.value), upgrade.required_weapon_id)
		UpgradeDefinition.UpgradeType.PIERCE_COUNT, UpgradeDefinition.UpgradeType.PROJECTILE_SPEED, UpgradeDefinition.UpgradeType.PROJECTILE_SIZE, UpgradeDefinition.UpgradeType.CRITICAL_CHANCE, UpgradeDefinition.UpgradeType.VOLLEY_COUNT:
			var modifier := WeaponRuntimeModifier.new()
			match upgrade.type:
				UpgradeDefinition.UpgradeType.PIERCE_COUNT:
					modifier.pierce_bonus = roundi(upgrade.value)
				UpgradeDefinition.UpgradeType.PROJECTILE_SPEED:
					modifier.speed_multiplier = 1.0 + upgrade.value
				UpgradeDefinition.UpgradeType.PROJECTILE_SIZE:
					modifier.size_multiplier = 1.0 + upgrade.value
				UpgradeDefinition.UpgradeType.CRITICAL_CHANCE:
					modifier.critical_chance = upgrade.value
				UpgradeDefinition.UpgradeType.VOLLEY_COUNT:
					modifier.volley_count_bonus = roundi(upgrade.value)
			_apply_weapon_modifier(modifier, upgrade.required_weapon_id)
		UpgradeDefinition.UpgradeType.EXPLOSION, UpgradeDefinition.UpgradeType.FLAME, UpgradeDefinition.UpgradeType.ICE:
			_apply_projectile_override(upgrade.projectile_definition, upgrade.get_target_equipment_id())
		UpgradeDefinition.UpgradeType.AREA_DURATION:
			var area_duration_modifier := WeaponRuntimeModifier.new()
			area_duration_modifier.ground_area_duration_multiplier = maxf(1.0 + upgrade.value, 0.0)
			_apply_weapon_modifier(area_duration_modifier, upgrade.required_weapon_id)
		UpgradeDefinition.UpgradeType.WEAPON_RANGE:
			var range_modifier := WeaponRuntimeModifier.new()
			range_modifier.range_multiplier = maxf(1.0 + upgrade.value, 0.0)
			_apply_weapon_modifier(range_modifier, upgrade.required_weapon_id)
		UpgradeDefinition.UpgradeType.FREEZE_DURATION:
			var freeze_modifier := WeaponRuntimeModifier.new()
			freeze_modifier.freeze_duration_multiplier = maxf(1.0 + upgrade.value, 0.0)
			_apply_weapon_modifier(freeze_modifier, upgrade.required_weapon_id)
		UpgradeDefinition.UpgradeType.SPLIT_COUNT:
			var split_modifier := WeaponRuntimeModifier.new()
			split_modifier.split_count_bonus = roundi(upgrade.value)
			_apply_weapon_modifier(split_modifier, upgrade.required_weapon_id)
		UpgradeDefinition.UpgradeType.ENCHANT_ARROW:
			_apply_projectile_override(upgrade.projectile_definition, upgrade.get_target_equipment_id())
		UpgradeDefinition.UpgradeType.THORN_AURA:
			_enable_thorn_aura(upgrade.thorn_armor)
		UpgradeDefinition.UpgradeType.THORN_RADIUS:
			_thorn_aura_radius_multiplier *= maxf(1.0 + upgrade.value, 0.0)
			if is_instance_valid(_thorn_aura):
				_thorn_aura.set_radius_multiplier(_thorn_aura_radius_multiplier)
		UpgradeDefinition.UpgradeType.REFLECT_RATIO:
			add_damage_reflect_ratio(upgrade.value)
		UpgradeDefinition.UpgradeType.KNIGHT_ARMOR:
			_enable_knight_armor(upgrade.knight_armor)
		UpgradeDefinition.UpgradeType.KNIGHT_DEFENSE:
			_knight_defense_bonus += upgrade.value
			_refresh_defense()
		UpgradeDefinition.UpgradeType.KNIGHT_IMMUNE:
			add_immune_chance(upgrade.value)
		UpgradeDefinition.UpgradeType.BERSERK_ARMOR:
			_enable_berserk_armor(upgrade.berserk_armor)
		UpgradeDefinition.UpgradeType.BERSERK_DRAIN:
			_berserk_drain_reduction += upgrade.value
			if is_instance_valid(_berserk_drain):
				_berserk_drain.set_drain_reduction(_berserk_drain_reduction)
		UpgradeDefinition.UpgradeType.BERSERK_LIFESTEAL:
			_berserk_half_lifesteal_bonus += upgrade.value
		UpgradeDefinition.UpgradeType.BERSERK_IMMUNITY:
			set_death_immunity_available(true)
		UpgradeDefinition.UpgradeType.TECH_ASCENSION:
			_enable_tech_armor(upgrade.get_target_equipment_id(), upgrade.tech_armor)
		UpgradeDefinition.UpgradeType.WEAPON_MODIFIER:
			pass
		UpgradeDefinition.UpgradeType.EXPLOSION_RADIUS:
			var radius_modifier := WeaponRuntimeModifier.new()
			radius_modifier.explosion_radius_multiplier = maxf(1.0 + upgrade.value, 0.0)
			_apply_weapon_modifier(radius_modifier, upgrade.required_weapon_id)
		UpgradeDefinition.UpgradeType.EXPLOSION_DAMAGE:
			var explosion_damage_modifier := WeaponRuntimeModifier.new()
			explosion_damage_modifier.explosion_damage_multiplier = maxf(1.0 + upgrade.value, 0.0)
			_apply_weapon_modifier(explosion_damage_modifier, upgrade.required_weapon_id)
		UpgradeDefinition.UpgradeType.REGENERATION:
			_regeneration += upgrade.value
		UpgradeDefinition.UpgradeType.ACQUIRE_WEAPON:
			if not try_acquire_weapon(upgrade.weapon_definition):
				return false
		UpgradeDefinition.UpgradeType.ACQUIRE_ARMOR:
			if not try_acquire_armor(upgrade.armor_definition):
				return false
		_:
			return false

	var new_stack_count: int = get_upgrade_stack(upgrade.id) + 1
	_upgrade_stacks[upgrade.id] = new_stack_count
	upgrade_state_changed.emit(upgrade.id, new_stack_count)
	return true


## 统一记录升级层数并发布信号，供各分类的 apply 分支复用。
func _finalize_upgrade(upgrade: UpgradeDefinition) -> bool:
	var new_stack_count: int = get_upgrade_stack(upgrade.id) + 1
	_upgrade_stacks[upgrade.id] = new_stack_count
	upgrade_state_changed.emit(upgrade.id, new_stack_count)
	return true


func get_effective_move_speed() -> float:
	return (
		_move_speed
		* _move_speed_multiplier
		* (1.0 - _armor_move_penalty_ratio)
		* _tech_set_move_multiplier
		* _permanent_move_multiplier
	)


func get_effective_maximum_health() -> float:
	var base_health: float = definition.max_health if definition != null else 0.0
	return maxf(base_health + _maximum_health_bonus, 0.0)


func get_effective_pickup_radius() -> float:
	var base_radius: float = definition.pickup_radius if definition != null else 0.0
	return maxf(base_radius * _pickup_range_multiplier, 0.0)


func _physics_process(_delta: float) -> void:
	_regeneration_clock += _delta
	if _regeneration_clock >= 1.0:
		_regeneration_clock -= 1.0
		var regeneration_total: float = _regeneration + _permanent_regeneration
		if regeneration_total > 0.0:
			health_component.heal(regeneration_total)
	var input_direction: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down"
	)
	velocity = input_direction * get_effective_move_speed()
	move_and_slide()


func get_team_id() -> StringName:
	return &"player"


func get_attack_range() -> float:
	return _base_attack_range


## 全武器索敌射程倍率（D06）：已持有与晚获取的武器都读取同一局内值。
func get_weapon_range_multiplier() -> float:
	return _all_weapon_range_multiplier


func get_passive_damage_multiplier() -> float:
	return _passive_damage_multiplier


func get_passive_weapon_tag() -> StringName:
	return _passive_weapon_tag


func _on_pickup_detected(pickup: Area2D) -> void:
	if pickup is ExperienceGem:
		(pickup as ExperienceGem).collect(self)
	elif pickup is CoinPickup:
		(pickup as CoinPickup).collect(self)


func _get_base_max_health() -> float:
	return definition.max_health if definition != null else 1.0


## 启用反伤刺甲：设置受击返还比例并挂载持续刺圈（T21）。
func _enable_thorn_aura(definition: ThornArmorDefinition) -> void:
	if definition == null:
		return
	_clear_thorn_aura()
	add_damage_reflect_ratio(definition.hit_reflect_ratio)
	_thorn_aura = ThornAuraComponent.new()
	_thorn_aura.name = "ThornAura"
	add_child(_thorn_aura)
	_thorn_aura.initialize(self, definition)
	_thorn_aura.set_radius_multiplier(_thorn_aura_radius_multiplier)


## 启用骑士盔甲：写入固定减伤并叠加完全免伤概率（T22）。
func _enable_knight_armor(definition: KnightArmorDefinition) -> void:
	if definition == null:
		return
	_knight_defense_bonus = definition.bonus_defense
	_refresh_defense()
	add_immune_chance(definition.immune_chance)


## 启用狂战盔甲：挂载持续失血组件并记录档案（T23）。
func _enable_berserk_armor(definition: BerserkArmorDefinition) -> void:
	if definition == null:
		return
	_clear_berserk_drain()
	_berserk_definition = definition
	_berserk_drain = BerserkDrainComponent.new()
	_berserk_drain.name = "BerserkDrain"
	add_child(_berserk_drain)
	_berserk_drain.initialize(self, definition)
	_berserk_drain.set_drain_reduction(_berserk_drain_reduction)


## 记录某件装备已选择科技质变；单件即可获得自身每秒经验与宝石倍率（T24）。
func _enable_tech_armor(equipment_id: StringName, definition: TechArmorDefinition) -> void:
	if equipment_id == StringName() or definition == null:
		return
	_tech_pieces[equipment_id] = definition
	_evaluate_tech_set()


## 注入科技三件套配置（T25）；可在装备/分支变化前调用，之后自动重算。
func configure_tech_set(definition: TechSetDefinition) -> void:
	_tech_set_definition = definition
	_evaluate_tech_set()


func is_tech_set_active() -> bool:
	return _tech_set_active


func get_set_weapon() -> WeaponController:
	return _set_weapon_controller


## 只在套装状态真正变化时应用/撤销一次，避免重复叠加移速或生成多个发射器。
func _evaluate_tech_set() -> void:
	var should_active: bool = _is_tech_set_satisfied()
	if should_active == _tech_set_active:
		return
	if should_active:
		_apply_tech_set()
	else:
		_remove_tech_set()


func _is_tech_set_satisfied() -> bool:
	if _tech_set_definition == null or _tech_set_definition.required_equipment_ids.is_empty():
		return false
	for equipment_id: StringName in _tech_set_definition.required_equipment_ids:
		var progress: EquipmentProgress = _equipment_progress.get(equipment_id)
		if progress == null or progress.branch_id != _tech_set_definition.required_branch_id:
			return false
	return true


func _apply_tech_set() -> void:
	_tech_set_active = true
	_tech_set_move_multiplier = maxf(_tech_set_definition.move_speed_multiplier, 1.0)
	_apply_float_visual(true)
	grant_set_weapon(_tech_set_definition.launcher_weapon)
	tech_set_activated.emit()


func _remove_tech_set() -> void:
	_tech_set_active = false
	_tech_set_move_multiplier = 1.0
	_apply_float_visual(false)
	remove_set_weapon()
	tech_set_deactivated.emit()


## 飞行仅改视觉高度，不绕过 World 碰撞（T25）。
func _apply_float_visual(active: bool) -> void:
	if not is_instance_valid(visual):
		return
	var offset: float = _tech_set_definition.float_visual_offset if active else 0.0
	visual.position.y = -offset


## 授予套装武器：不占六格、不登记装备，仅供套装的发射器使用。
func grant_set_weapon(definition: WeaponDefinition) -> bool:
	if definition == null or definition.id == StringName():
		return false
	if is_instance_valid(_set_weapon_controller):
		return false
	if not is_instance_valid(_projectile_parent) or not is_instance_valid(_targeting_service):
		return false
	var controller := WeaponController.new()
	controller.name = "SetWeapon_%s" % definition.id
	controller.visual_slot = weapon_controllers.size()
	weapon_controller_parent.add_child(controller)
	controller.initialize(definition, self, _projectile_parent)
	controller.set_targeting_service(_targeting_service)
	weapon_controllers.append(controller)
	_set_weapon_controller = controller
	weapon_added.emit(controller)
	return true


func remove_set_weapon() -> void:
	if not is_instance_valid(_set_weapon_controller):
		_set_weapon_controller = null
		return
	weapon_controllers.erase(_set_weapon_controller)
	_set_weapon_controller.set_process(false)
	_set_weapon_controller.queue_free()
	_set_weapon_controller = null


func _clear_berserk_drain() -> void:
	if is_instance_valid(_berserk_drain):
		_berserk_drain.queue_free()
	_berserk_drain = null


func get_berserk_drain() -> BerserkDrainComponent:
	return _berserk_drain


## 狂战盔甲提供的额外吸血：基础值，半血以下再加成（T23）。
func get_bonus_lifesteal_ratio() -> float:
	var bonus: float = _permanent_lifesteal_ratio
	if _berserk_definition != null:
		bonus += _berserk_definition.base_lifesteal_ratio
		var maximum_health: float = get_effective_maximum_health()
		if maximum_health > 0.0 \
				and health_component.current_health <= maximum_health * _berserk_definition.half_health_ratio:
			bonus += _berserk_definition.half_health_lifesteal_bonus + _berserk_half_lifesteal_bonus
	return clampf(bonus, 0.0, 1.0)


## 应用开局永久强化快照（T30）：一次性写入，运行中不再读取档案。
func apply_permanent_upgrades(
		levels: Dictionary, catalog: PermanentUpgradeCatalog
) -> void:
	if catalog == null or levels == null:
		return
	for definition: PermanentUpgradeDefinition in catalog.upgrades:
		if definition == null:
			continue
		var level: int = int(levels.get(definition.id, 0))
		if level <= 0:
			continue
		var value: float = definition.per_level_value * float(level)
		match definition.attribute:
			PermanentUpgradeDefinition.Attribute.MOVE_SPEED:
				_permanent_move_multiplier *= maxf(1.0 + value, 0.0)
			PermanentUpgradeDefinition.Attribute.DAMAGE:
				_apply_weapon_modifier(WeaponRuntimeModifier.new(1.0, 0, 1.0 + value), &"")
			PermanentUpgradeDefinition.Attribute.REGENERATION:
				_permanent_regeneration += value
			PermanentUpgradeDefinition.Attribute.LIFESTEAL:
				_permanent_lifesteal_ratio += value
			PermanentUpgradeDefinition.Attribute.DEFENSE:
				_permanent_defense += value
	_refresh_defense()


func get_permanent_move_multiplier() -> float:
	return _permanent_move_multiplier


func get_permanent_lifesteal_ratio() -> float:
	return _permanent_lifesteal_ratio


func get_permanent_defense() -> float:
	return _permanent_defense


func get_permanent_regeneration() -> float:
	return _permanent_regeneration


func _clear_thorn_aura() -> void:
	if is_instance_valid(_thorn_aura):
		_thorn_aura.queue_free()
	_thorn_aura = null


func get_thorn_aura() -> ThornAuraComponent:
	return _thorn_aura


func _apply_weapon_modifier(modifier: WeaponRuntimeModifier, target_weapon_id: StringName = &"") -> void:
	_weapon_modifier_history.append({"modifier": modifier, "target": target_weapon_id})
	for controller: WeaponController in weapon_controllers:
		if is_instance_valid(controller) and (target_weapon_id == StringName() or controller.definition.id == target_weapon_id):
			controller.apply_runtime_modifier(modifier)


## 质变切换目标武器的弹体（如爆炸法球）；只改运行时覆盖，不写共享 Resource。
func _apply_projectile_override(
		projectile_definition: ProjectileDefinition, target_weapon_id: StringName = &""
) -> void:
	if projectile_definition == null:
		return
	for controller: WeaponController in weapon_controllers:
		if is_instance_valid(controller) and (target_weapon_id == StringName() or controller.definition.id == target_weapon_id):
			controller.set_projectile_definition_override(projectile_definition)
