## 游戏核心数据定义
class_name GameData

# ── 常量 ──
const MAX_WEEKS := 12
const INITIAL_CASH := 2000
const WEEKLY_LIVING_COST := 500
const ENERGY_PER_WEEK := 7
const MAX_SKILL_LEVEL := 10
const GIG_INCOME_PARTTIME := 280   # 兼职零工收入（消耗 3 能量）
const GIG_INCOME_FULLTIME := 520   # 全职零工收入（消耗 5 能量）
const GIG_ENERGY_PARTTIME := 3
const GIG_ENERGY_FULLTIME := 5
const OFFER_VALIDITY_WEEKS := 2
const MARKET_REFRESH_WEEKS := [1, 4, 7, 10]  # 岗位市场刷新的周次
const LISTINGS_PER_REFRESH := 5               # 每次刷新生成的岗位数

# ── 公司名池 ──
const COMPANIES: Array[String] = [
	"赛博科技", "码农互联", "极客云", "量子前端", "深渊后端",
	"无限循环", "栈溢出", "指针工坊", "字节飞扬", "代码农场",
	"算法园", "二叉树科技", "哈希工业", "递归传媒", "泛型集团",
	"接口科技", "类型擦除", "虚函数", "内存泄漏", "段错误",
]

# ── 技能枚举 ──
enum SkillType { SYSTEM, APPLICATION, INTERVIEW }

# ── 市场偏向 ──
enum MarketBias {
	BALANCED,      # 均衡：系统 / 应用各约 50%
	SYSTEM_HEAVY,  # 系统偏：系统岗位占约 70%
	APP_HEAVY,     # 应用偏：应用岗位占约 70%
}

# ── 求职状态 ──
enum ApplicationStatus {
	NONE,
	APPLIED,          # 已投递，等待下周结果
	HAS_INTERVIEW,    # 获得面试机会
	INTERVIEWED,      # 已面试，等待下周结果
	OFFER,            # 拿到 offer
	REJECTED,         # 被拒
}

# ── 岗位定义（模板） ──
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

# ── 所有岗位模板 ──
static func get_all_jobs() -> Array[JobDef]:
	return [
		# 系统开发方向
		JobDef.new("outsource_test", "外包测试", SkillType.SYSTEM, 3, 780, 4),
		JobDef.new("junior_backend", "初级后端", SkillType.SYSTEM, 5, 1100, 5),
		JobDef.new("senior_system", "高级系统工程师", SkillType.SYSTEM, 8, 1800, 5),
		# 应用开发方向
		JobDef.new("parttime_frontend", "兼职前端", SkillType.APPLICATION, 3, 680, 3),
		JobDef.new("fullstack_dev", "全栈开发", SkillType.APPLICATION, 5, 1000, 5),
		JobDef.new("senior_product", "高级产品工程师", SkillType.APPLICATION, 8, 1700, 5),
	]

# ── 岗位实例（市场上的具体职位：模板 + 公司名 + 唯一 ID） ──
class JobListing:
	var listing_id: String
	var job: JobDef
	var company: String

	func _init(p_listing_id: String, p_job: JobDef, p_company: String) -> void:
		listing_id = p_listing_id
		job = p_job
		company = p_company

# ── 求职申请 ──
class JobApplication:
	var listing: JobListing
	var status: ApplicationStatus
	var offer_weeks_left: int  # offer 剩余有效周数

	func _init(p_listing: JobListing) -> void:
		listing = p_listing
		status = ApplicationStatus.APPLIED
		offer_weeks_left = 0

# ── 技能升级所需 XP（每两级递增一次） ──
# 升到第 N 级需要 ceil(N/2) 点 XP：1,2级→1；3,4级→2；5,6级→3；7,8级→4；9,10级→5
static func xp_needed_for_level(target_level: int) -> int:
	return (target_level + 1) / 2
