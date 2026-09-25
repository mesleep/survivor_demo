## 单次伤害结算结果（运行时对象）。
##
## 输入：由 ActorBase 在扣血前计算。
## 输出：原始伤害、实际扣血、被防御减免、是否闪避/免疫、是否击杀与来源标签。
## 扩展点：暴击结果、元素反应、伤害浮字数值可继续加入。
class_name DamageResult
extends RefCounted

var raw_amount: float = 0.0
var applied_amount: float = 0.0
var blocked_amount: float = 0.0
var is_dodged: bool = false
var is_immune: bool = false
var killed: bool = false
var source: Node
var tags: Array[StringName] = []
