## 游戏核心数据定义
class_name GameData

# ── 常量 ──
const MAX_WEEKS := 52
const INITIAL_CASH := 3000
const WEEKLY_LIVING_COST := 400
const ENERGY_PER_WEEK := 7
const MAX_SKILL_LEVEL := 10
const GIG_INCOME := 150
const OFFER_VALIDITY_WEEKS := 2

# ── 技能枚举 ──
enum SkillType { SYSTEM, APPLICATION, INTERVIEW }

# ── 求职状态 ──
enum ApplicationStatus {
	NONE,
	APPLIED,          # 已投递，等待下周结果
	HAS_INTERVIEW,    # 获得面试机会
	INTERVIEWED,      # 已面试，等待下周结果
	OFFER,            # 拿到 offer
	REJECTED,         # 被拒
}

# ── 岗位定义 ──
class JobDef:
	var id: String
	var title: String
	var skill_type: SkillType
	var skill_required: int
	var weekly_salary: int
	var energy_cost: int

	func _init(p_id: String, p_title: String, p_skill_type: SkillType,
			p_skill_req: int, p_salary: int, p_energy: int) -> void:
		id = p_id
		title = p_title
		skill_type = p_skill_type
		skill_required = p_skill_req
		weekly_salary = p_salary
		energy_cost = p_energy

# ── 所有岗位 ──
static func get_all_jobs() -> Array[JobDef]:
	return [
		# 系统开发方向
		JobDef.new("outsource_test", "外包测试", SkillType.SYSTEM, 2, 250, 4),
		JobDef.new("junior_backend", "初级后端", SkillType.SYSTEM, 5, 550, 5),
		JobDef.new("senior_system", "高级系统工程师", SkillType.SYSTEM, 8, 950, 5),
		# 应用开发方向
		JobDef.new("parttime_frontend", "兼职前端", SkillType.APPLICATION, 2, 200, 3),
		JobDef.new("fullstack_dev", "全栈开发", SkillType.APPLICATION, 5, 500, 5),
		JobDef.new("senior_product", "高级产品工程师", SkillType.APPLICATION, 8, 900, 5),
	]

# ── 求职申请 ──
class JobApplication:
	var job: JobDef
	var status: ApplicationStatus
	var offer_weeks_left: int  # offer 剩余有效周数

	func _init(p_job: JobDef) -> void:
		job = p_job
		status = ApplicationStatus.APPLIED
		offer_weeks_left = 0
