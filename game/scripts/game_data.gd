## 游戏核心数据定义
class_name GameData

# ── 常量 ──
const MAX_WEEKS := 12
const INITIAL_CASH := 2000
const WEEKLY_LIVING_COST := 500
const ENERGY_PER_WEEK := 7
const MAX_SKILL_LEVEL := 10
const GIG_INCOME_PARTTIME := 280
const GIG_INCOME_FULLTIME := 520
const GIG_ENERGY_PARTTIME := 3
const GIG_ENERGY_FULLTIME := 5
const OFFER_VALIDITY_WEEKS := 2
const MARKET_REFRESH_WEEKS := [1, 4, 7, 10]
const LISTINGS_PER_REFRESH := 5

# 批量投递惩罚系数
const BATCH_PENALTY_2 := 0.80
const BATCH_PENALTY_3 := 0.65

# 人脉与作品集
const MAX_NETWORKING_POINTS := 10
const PORTFOLIO_ENERGY_COST := 3
const MAX_PORTFOLIO_POINTS := 3

# ── 公司名池 ──
const COMPANIES: Array[String] = [
	"赛博科技", "码农互联", "极客云", "量子前端", "深渊后端",
	"无限循环", "栈溢出", "指针工坊", "字节飞扬", "代码农场",
	"算法园", "二叉树科技", "哈希工业", "递归传媒", "泛型集团",
	"接口科技", "类型擦除", "虚函数", "内存泄漏", "段错误",
]

# ── 技能枚举 ──
enum SkillType {
	SYSTEM,       # 系统开发（专业，系统方向）
	APPLICATION,  # 应用开发（专业，应用方向）
	INTERVIEW,    # 面试技巧（通用）
	ENGLISH,      # 英语（通用，影响所有岗位简历匹配）
	CPP,          # C++（专业，仅影响系统方向岗位）
}

# ── 市场偏向 ──
enum MarketBias {
	BALANCED,
	SYSTEM_HEAVY,
	APP_HEAVY,
}

# ── 求职状态 ──
enum ApplicationStatus {
	NONE,
	APPLIED,
	HAS_INTERVIEW,
	INTERVIEWED,
	OFFER,
	REJECTED,
}

# ── 岗位定义（模板） ──
class JobDef:
	var id: String
	var title: String
	var skill_type: SkillType
	var skill_required: int
	var english_required: int
	var cpp_required: int     # 仅系统方向有效
	var weekly_salary: int
	var energy_cost: int

	func _init(p_id: String, p_title: String, p_skill_type: SkillType,
			p_skill_req: int, p_english_req: int, p_cpp_req: int,
			p_salary: int, p_energy: int) -> void:
		id = p_id
		title = p_title
		skill_type = p_skill_type
		skill_required = p_skill_req
		english_required = p_english_req
		cpp_required = p_cpp_req
		weekly_salary = p_salary
		energy_cost = p_energy

# ── 所有岗位模板 ──
#                                         主技能  英语  C++  周薪   能量
static func get_all_jobs() -> Array[JobDef]:
	return [
		JobDef.new("outsource_test",   "外包测试",     SkillType.SYSTEM,       3, 1, 1,  780, 4),
		JobDef.new("junior_backend",   "初级后端",     SkillType.SYSTEM,       5, 2, 2, 1100, 5),
		JobDef.new("senior_system",    "高级系统工程师", SkillType.SYSTEM,      8, 3, 4, 1800, 5),
		JobDef.new("parttime_frontend","兼职前端",     SkillType.APPLICATION,  3, 1, 0,  680, 3),
		JobDef.new("fullstack_dev",    "全栈开发",     SkillType.APPLICATION,  5, 2, 0, 1000, 5),
		JobDef.new("senior_product",   "高级产品工程师", SkillType.APPLICATION, 8, 3, 0, 1700, 5),
	]

# ── 岗位实例 ──
class JobListing:
	var listing_id: String
	var job: JobDef
	var company: String
	var actual_salary: int           # 随机化后的实际周薪（基础 ±15%，取整到10）
	var actual_skill_required: int   # 随机化后的主技能需求（基础 ±1，最低1）
	var actual_english_required: int
	var actual_cpp_required: int     # APPLICATION岗位始终为0

	func _init(p_listing_id: String, p_job: JobDef, p_company: String,
			p_salary: int, p_skill_req: int, p_eng_req: int, p_cpp_req: int) -> void:
		listing_id = p_listing_id
		job = p_job
		company = p_company
		actual_salary = p_salary
		actual_skill_required = p_skill_req
		actual_english_required = p_eng_req
		actual_cpp_required = p_cpp_req

# ── 求职申请 ──
class JobApplication:
	var listing: JobListing
	var status: ApplicationStatus
	var offer_weeks_left: int
	var apply_penalty: float  # 批量投递惩罚系数（1.0 = 无惩罚）

	func _init(p_listing: JobListing, p_penalty: float = 1.0) -> void:
		listing = p_listing
		status = ApplicationStatus.APPLIED
		offer_weeks_left = 0
		apply_penalty = p_penalty

# ── 技能升级 XP 需求（每两级递增一次）──
# 升到第 N 级需要 ceil(N/2) 点：1,2级→1；3,4级→2；5,6级→3；7,8级→4；9,10级→5
static func xp_needed_for_level(target_level: int) -> int:
	return (target_level + 1) / 2
