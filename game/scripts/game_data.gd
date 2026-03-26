## 游戏核心数据定义 (V4: 公司系统、市场环境与角色技能重构)
class_name GameData

# ══════════════════════════════════════════
#  常量
# ══════════════════════════════════════════

const MAX_WEEKS := 12
const INITIAL_CASH := 3500
const WEEKLY_LIVING_COST := 500
const ENERGY_PER_WEEK := 7
const MAX_SKILL_LEVEL := 10
const OFFER_VALIDITY_WEEKS := 3

# 零工
const GIG_INCOME_PARTTIME := 280
const GIG_INCOME_FULLTIME := 520
const GIG_ENERGY_PARTTIME := 3
const GIG_ENERGY_FULLTIME := 5

# 市场风向 & 事件
const MARKET_WIND_CYCLE := 3          # 每3周判定一次新风向
const MARKET_WIND_CHANCE := 0.50      # 50%概率产生风向
const MARKET_EVENT_CHANCE := 0.25     # 每周25%概率产生市场事件

# 学习疲劳：同一技能每周第4次起XP减半
const STUDY_FATIGUE_THRESHOLD := 4

# 人际关系
const MAX_NETWORKING_POINTS := 10

# 个人作品
const PERSONAL_PROJECT_COST := 5       # 完成需累计5点行动力
const PERSONAL_PROJECT_MAX_PER_WEEK := 3  # 每周最多投入3次
const PERSONAL_PROJECT_MIN_SKILL := 5  # 需要至少一个专业技能>4 (即>=5)
const PERSONAL_PROJECT_RESUME_BONUS := 0.15
const PERSONAL_PROJECT_INTERVIEW_BONUS := 0.10

# 外包
const OUTSOURCE_BASE_REFRESH_CHANCE := 0.30
const OUTSOURCE_REFRESH_PER_COMPLETION := 0.05
const OUTSOURCE_REFRESH_MAX := 0.60
const OUTSOURCE_FAIL_CHANCE := 0.15   # 刚好满足门槛时失败概率

# 包装简历
const RESUME_FAKE_CATCH_CHANCE := 0.30  # 面试被拆穿概率

# 内推
const REFERRAL_BASE_CHANCE := 0.05
const REFERRAL_NETWORKING_MULT := 0.3
const REFERRAL_RESUME_MULT := 1.5

# 工具系统 (V3保留)
const MAX_TOOLS := 3
const SHOP_DISPLAY_COUNT := 3
const SHOP_ENERGY_COST := 1

# 起始技能方向特色加成
const SKILL_BONUS_BACKEND_SALARY := 0.10       # 后端：相关岗位薪资+10%
const SKILL_BONUS_FRONTEND_INTERVIEW := 0.08   # 前端：面试通过率+8%
const SKILL_BONUS_ALGORITHM_BIGCO := 0.15      # 算法：大厂简历通过率+15%
const SKILL_BONUS_DATA_OUTSOURCE := 0.15       # 数据工程：外包刷新率+15%
const SKILL_BONUS_DATA_OUTSOURCE_INCOME := 0.20 # 数据工程：外包收入+20%
const SKILL_BONUS_INFRA_INTERVIEW_COST := 1    # 基础设施：面试消耗1AP（原2AP）

# 海投
const MASS_APPLY_COUNT := 5           # 海投随机选5个岗位

# 岗位职级分布 — 前半程 (week 1-6)
const TIER_CHANCE_JUNIOR_EARLY := 0.60
const TIER_CHANCE_MID_EARLY := 0.30
const TIER_CHANCE_SENIOR_EARLY := 0.10
# 岗位职级分布 — 后半程 (week 7-12)
const TIER_CHANCE_JUNIOR_LATE := 0.35
const TIER_CHANCE_MID_LATE := 0.40
const TIER_CHANCE_SENIOR_LATE := 0.25

# ══════════════════════════════════════════
#  枚举
# ══════════════════════════════════════════

# 专业技能 (5个)
enum SkillType {
	BACKEND,         # 后端开发
	FRONTEND,        # 前端开发
	ALGORITHM,       # 算法
	DATA_ENGINEERING,# 数据工程
	INFRASTRUCTURE,  # 基础设施
}

# 通用/辅助技能
enum GeneralSkillType {
	COMMUNICATION,   # 沟通
	INTERVIEW_SKILL, # 面试技巧
}

# 求职状态
enum ApplicationStatus {
	NONE,
	APPLIED,
	HAS_INTERVIEW,
	INTERVIEWED,
	OFFER,
	REJECTED,
}

# 公司规模
enum CompanyScale { BIG, MEDIUM, SMALL }

# 福利水平
enum BenefitLevel { HIGH, MEDIUM, NORMAL }

# 经营状况
enum BusinessStatus { GOOD, STABLE, STRUGGLING }

# 市场风向类型
enum MarketWindType { NONE, HOT, SHRINK }

# 岗位职级
enum JobTier { JUNIOR, MID, SENIOR }

# 外包等级
enum OutsourceLevel { MID_OUTSOURCE, HIGH_OUTSOURCE }

# ══════════════════════════════════════════
#  技能相关工具函数
# ══════════════════════════════════════════

# 升到第 N 级需要 N 点 XP (设计文档: 学习一次+1 XP，升到第N级需要N点XP)
static func xp_needed_for_level(target_level: int) -> int:
	return target_level

static func get_skill_name(skill: SkillType) -> String:
	match skill:
		SkillType.BACKEND: return "后端开发"
		SkillType.FRONTEND: return "前端开发"
		SkillType.ALGORITHM: return "算法"
		SkillType.DATA_ENGINEERING: return "数据工程"
		SkillType.INFRASTRUCTURE: return "基础设施"
		_: return "未知"

static func get_general_skill_name(skill: GeneralSkillType) -> String:
	match skill:
		GeneralSkillType.COMMUNICATION: return "沟通"
		GeneralSkillType.INTERVIEW_SKILL: return "面试技巧"
		_: return "未知"

static func get_skill_bonus_description(skill: SkillType) -> String:
	match skill:
		SkillType.BACKEND: return "后端相关岗位薪资+10%"
		SkillType.FRONTEND: return "面试通过率+8%"
		SkillType.ALGORITHM: return "大厂简历通过率+15%"
		SkillType.DATA_ENGINEERING: return "外包刷新率+15%，外包收入+20%"
		SkillType.INFRASTRUCTURE: return "面试消耗1AP（原2AP）"
		_: return ""

static func get_all_skill_types() -> Array:
	return [
		SkillType.BACKEND,
		SkillType.FRONTEND,
		SkillType.ALGORITHM,
		SkillType.DATA_ENGINEERING,
		SkillType.INFRASTRUCTURE,
	]

# ══════════════════════════════════════════
#  公司定义
# ══════════════════════════════════════════

class CompanyDef:
	var id: String
	var name: String
	var scale: CompanyScale
	var benefit_level: BenefitLevel
	var business_status: BusinessStatus
	var job_slots_min: int
	var job_slots_max: int
	var job_generate_chance: float
	var job_disappear_chance: float
	var preferred_skills: Array  # Array[SkillType], 2个倾向技能

	func _init(p_id: String, p_name: String, p_scale: CompanyScale,
			p_benefit: BenefitLevel, p_status: BusinessStatus,
			p_slots_min: int, p_slots_max: int, p_gen_chance: float,
			p_disappear: float, p_skills: Array) -> void:
		id = p_id
		name = p_name
		scale = p_scale
		benefit_level = p_benefit
		business_status = p_status
		job_slots_min = p_slots_min
		job_slots_max = p_slots_max
		job_generate_chance = p_gen_chance
		job_disappear_chance = p_disappear
		preferred_skills = p_skills

	func get_salary_multiplier() -> float:
		match benefit_level:
			BenefitLevel.HIGH: return 1.15
			BenefitLevel.MEDIUM: return 1.0
			_: return 0.90

	func get_scale_text() -> String:
		match scale:
			CompanyScale.BIG: return "大厂"
			CompanyScale.MEDIUM: return "中厂"
			_: return "小厂"

	func get_benefit_text() -> String:
		match benefit_level:
			BenefitLevel.HIGH: return "优厚"
			BenefitLevel.MEDIUM: return "中等"
			_: return "普通"

	func get_status_text() -> String:
		match business_status:
			BusinessStatus.GOOD: return "良好"
			BusinessStatus.STABLE: return "维持"
			_: return "艰难"

	func get_preferred_skills_text() -> String:
		var names := []
		for s in preferred_skills:
			names.append(GameData.get_skill_name(s))
		return "、".join(names)


static func get_all_companies() -> Array[CompanyDef]:
	return [
		# 大厂 ×2
		CompanyDef.new("bytedance", "字节飞扬", CompanyScale.BIG,
			BenefitLevel.HIGH, BusinessStatus.GOOD,
			2, 5, 0.70, 0.10,
			[SkillType.FRONTEND, SkillType.ALGORITHM]),
		CompanyDef.new("deepmind", "深渊后端", CompanyScale.BIG,
			BenefitLevel.HIGH, BusinessStatus.GOOD,
			2, 4, 0.65, 0.12,
			[SkillType.BACKEND, SkillType.INFRASTRUCTURE]),
		# 中厂 ×3
		CompanyDef.new("cybertech", "赛博科技", CompanyScale.MEDIUM,
			BenefitLevel.MEDIUM, BusinessStatus.GOOD,
			2, 4, 0.70, 0.15,
			[SkillType.BACKEND, SkillType.DATA_ENGINEERING]),
		CompanyDef.new("geekcloud", "极客云", CompanyScale.MEDIUM,
			BenefitLevel.MEDIUM, BusinessStatus.STABLE,
			1, 3, 0.65, 0.15,
			[SkillType.FRONTEND, SkillType.INFRASTRUCTURE]),
		CompanyDef.new("hashworks", "哈希工业", CompanyScale.MEDIUM,
			BenefitLevel.NORMAL, BusinessStatus.STABLE,
			2, 4, 0.65, 0.20,
			[SkillType.ALGORITHM, SkillType.DATA_ENGINEERING]),
		# 小厂 ×3
		CompanyDef.new("stackflow", "栈溢出", CompanyScale.SMALL,
			BenefitLevel.NORMAL, BusinessStatus.STABLE,
			1, 3, 0.75, 0.20,
			[SkillType.FRONTEND, SkillType.BACKEND]),
		CompanyDef.new("recursion", "递归传媒", CompanyScale.SMALL,
			BenefitLevel.MEDIUM, BusinessStatus.STRUGGLING,
			1, 3, 0.55, 0.25,
			[SkillType.FRONTEND, SkillType.DATA_ENGINEERING]),
		CompanyDef.new("pointshop", "指针工坊", CompanyScale.SMALL,
			BenefitLevel.NORMAL, BusinessStatus.STRUGGLING,
			1, 3, 0.60, 0.25,
			[SkillType.BACKEND, SkillType.ALGORITHM]),
	]


# ══════════════════════════════════════════
#  市场风向定义
# ══════════════════════════════════════════

class MarketWindDef:
	var id: String
	var name: String
	var wind_type: MarketWindType
	var target_skill: SkillType
	var gen_chance_modifier: float
	var description: String

	func _init(p_id: String, p_name: String, p_type: MarketWindType,
			p_skill: SkillType, p_mod: float, p_desc: String) -> void:
		id = p_id
		name = p_name
		wind_type = p_type
		target_skill = p_skill
		gen_chance_modifier = p_mod
		description = p_desc


# 风向从5个专业技能中随机选一个，类型为HOT(+20%)或SHRINK(-15%)
# 不再预定义列表，改为动态生成
static func generate_random_wind() -> MarketWindDef:
	var skills := get_all_skill_types()
	var skill: SkillType = skills[randi() % skills.size()]
	var skill_name := get_skill_name(skill)
	var is_hot := randf() < 0.5
	if is_hot:
		return MarketWindDef.new(
			"hot_%s" % str(skill), "%s需求激增" % skill_name,
			MarketWindType.HOT, skill, 0.20,
			"各大公司纷纷扩招%s方向工程师" % skill_name)
	else:
		return MarketWindDef.new(
			"shrink_%s" % str(skill), "%s岗位收缩" % skill_name,
			MarketWindType.SHRINK, skill, -0.15,
			"%s方向岗位需求下降" % skill_name)


# ══════════════════════════════════════════
#  市场事件定义
# ══════════════════════════════════════════

class MarketEventDef:
	var id: String
	var name: String
	var description: String
	var duration: int
	var effect_tag: String

	func _init(p_id: String, p_name: String, p_desc: String,
			p_duration: int, p_tag: String) -> void:
		id = p_id
		name = p_name
		description = p_desc
		duration = p_duration
		effect_tag = p_tag


static func get_all_market_events() -> Array[MarketEventDef]:
	return [
		MarketEventDef.new("ai_shock", "AI浪潮冲击",
			"AI大模型快速迭代，各公司裁员优化，经营状况普遍下滑",
			3, "ai_shock"),
		MarketEventDef.new("economy_down", "经济不景气",
			"融资环境恶化，新增岗位大幅减少",
			3, "economy_down"),
		MarketEventDef.new("policy_boost", "政策利好",
			"政府出台人才补贴政策，企业招聘意愿增强，面试通过率提升",
			3, "policy_boost"),
		MarketEventDef.new("funding_boom", "融资热潮",
			"资本市场活跃，多家公司获得融资，经营状况改善",
			2, "funding_boom"),
		MarketEventDef.new("industry_crackdown", "行业整顿",
			"监管部门出手整顿，所有公司暂停招聘一周",
			1, "industry_crackdown"),
	]


# ══════════════════════════════════════════
#  岗位定义 (V4: 职级+多技能需求)
# ══════════════════════════════════════════

class SkillRequirement:
	var skill: SkillType
	var level: int

	func _init(p_skill: SkillType, p_level: int) -> void:
		skill = p_skill
		level = p_level


class JobDef:
	var id: String
	var title: String
	var tier: JobTier
	var skill_requirements: Array  # Array[SkillRequirement]
	var communication_required: int
	var base_salary: int
	var energy_cost: int

	func _init(p_id: String, p_title: String, p_tier: JobTier,
			p_reqs: Array, p_comm: int, p_salary: int, p_energy: int) -> void:
		id = p_id
		title = p_title
		tier = p_tier
		skill_requirements = p_reqs
		communication_required = p_comm
		base_salary = p_salary
		energy_cost = p_energy

	func get_tier_text() -> String:
		match tier:
			JobTier.JUNIOR: return "初级"
			JobTier.MID: return "中级"
			JobTier.SENIOR: return "高级"
			_: return ""

	func get_primary_skills() -> Array:
		var skills := []
		for req in skill_requirements:
			skills.append(req.skill)
		return skills


# 所有岗位模板
static func get_all_jobs() -> Array[JobDef]:
	return [
		# ── 初级岗位 (1个专业技能, 占4AP) ──
		JobDef.new("jr_backend", "初级后端开发", JobTier.JUNIOR,
			[SkillRequirement.new(SkillType.BACKEND, 3)], 0, 750, 4),
		JobDef.new("jr_frontend", "初级前端开发", JobTier.JUNIOR,
			[SkillRequirement.new(SkillType.FRONTEND, 3)], 0, 720, 4),
		JobDef.new("jr_data_analyst", "初级数据分析师", JobTier.JUNIOR,
			[SkillRequirement.new(SkillType.DATA_ENGINEERING, 3)], 0, 700, 4),
		JobDef.new("jr_ops", "初级运维工程师", JobTier.JUNIOR,
			[SkillRequirement.new(SkillType.INFRASTRUCTURE, 3)], 1, 730, 4),
		JobDef.new("jr_algo", "初级算法工程师", JobTier.JUNIOR,
			[SkillRequirement.new(SkillType.ALGORITHM, 4)], 0, 850, 4),

		# ── 中级岗位 (1-2个专业技能, 占5AP) ──
		JobDef.new("mid_fullstack", "全栈开发", JobTier.MID,
			[SkillRequirement.new(SkillType.FRONTEND, 4),
			 SkillRequirement.new(SkillType.BACKEND, 3)], 2, 1100, 5),
		JobDef.new("mid_search", "搜索工程师", JobTier.MID,
			[SkillRequirement.new(SkillType.ALGORITHM, 4),
			 SkillRequirement.new(SkillType.BACKEND, 3)], 2, 1200, 5),
		JobDef.new("mid_data_eng", "数据工程师", JobTier.MID,
			[SkillRequirement.new(SkillType.DATA_ENGINEERING, 4),
			 SkillRequirement.new(SkillType.BACKEND, 3)], 2, 1050, 5),
		JobDef.new("mid_sre", "SRE工程师", JobTier.MID,
			[SkillRequirement.new(SkillType.INFRASTRUCTURE, 4),
			 SkillRequirement.new(SkillType.BACKEND, 3)], 3, 1100, 5),
		JobDef.new("mid_bigdata", "大数据开发", JobTier.MID,
			[SkillRequirement.new(SkillType.DATA_ENGINEERING, 4),
			 SkillRequirement.new(SkillType.INFRASTRUCTURE, 3)], 2, 1050, 5),
		JobDef.new("mid_frontend", "中级前端工程师", JobTier.MID,
			[SkillRequirement.new(SkillType.FRONTEND, 5)], 3, 1000, 5),

		# ── 高级岗位 (2个专业技能, 占5AP) ──
		JobDef.new("sr_fullstack", "高级全栈架构师", JobTier.SENIOR,
			[SkillRequirement.new(SkillType.FRONTEND, 6),
			 SkillRequirement.new(SkillType.BACKEND, 5)], 4, 1700, 5),
		JobDef.new("sr_recommend", "推荐系统专家", JobTier.SENIOR,
			[SkillRequirement.new(SkillType.ALGORITHM, 6),
			 SkillRequirement.new(SkillType.BACKEND, 5)], 3, 1800, 5),
		JobDef.new("sr_data_platform", "数据平台负责人", JobTier.SENIOR,
			[SkillRequirement.new(SkillType.DATA_ENGINEERING, 6),
			 SkillRequirement.new(SkillType.INFRASTRUCTURE, 5)], 4, 1650, 5),
		JobDef.new("sr_ai_app", "AI应用工程师", JobTier.SENIOR,
			[SkillRequirement.new(SkillType.ALGORITHM, 5),
			 SkillRequirement.new(SkillType.FRONTEND, 5)], 3, 1600, 5),
		JobDef.new("sr_sre", "高级SRE", JobTier.SENIOR,
			[SkillRequirement.new(SkillType.INFRASTRUCTURE, 6),
			 SkillRequirement.new(SkillType.BACKEND, 5)], 3, 1700, 5),
	]


# 根据公司倾向技能和职级筛选匹配的岗位模板
static func get_matching_jobs(preferred_skills: Array, tier: JobTier) -> Array[JobDef]:
	var all_jobs := get_all_jobs()
	var matched: Array[JobDef] = []
	for job in all_jobs:
		if job.tier != tier:
			continue
		var job_skills := job.get_primary_skills()
		var has_match := false
		for js in job_skills:
			if js in preferred_skills:
				has_match = true
				break
		if has_match:
			matched.append(job)
	return matched


# ══════════════════════════════════════════
#  岗位实例
# ══════════════════════════════════════════

class JobListing:
	var listing_id: String
	var job: JobDef
	var company_def: CompanyDef
	var actual_salary: int
	var actual_skill_requirements: Array  # Array[SkillRequirement] 实际需求
	var actual_comm_required: int
	var weeks_alive: int = 0

	func _init(p_id: String, p_job: JobDef, p_company: CompanyDef,
			p_salary: int, p_reqs: Array, p_comm: int) -> void:
		listing_id = p_id
		job = p_job
		company_def = p_company
		actual_salary = p_salary
		actual_skill_requirements = p_reqs
		actual_comm_required = p_comm

	func get_display_title() -> String:
		return "%s @ %s" % [job.title, company_def.name]

	func get_salary_text() -> String:
		return "$%s/周" % _format_number(actual_salary)

	func get_requirements_text() -> String:
		var parts := []
		for req in actual_skill_requirements:
			parts.append("%s Lv.%d" % [GameData.get_skill_name(req.skill), req.level])
		if actual_comm_required > 0:
			parts.append("沟通 Lv.%d" % actual_comm_required)
		return "、".join(parts)

	static func _format_number(n: int) -> String:
		var s := str(abs(n))
		var result := ""
		for i in range(s.length()):
			if i > 0 and (s.length() - i) % 3 == 0:
				result += ","
			result += s[i]
		if n < 0:
			return "-" + result
		return result


# ══════════════════════════════════════════
#  求职申请
# ══════════════════════════════════════════

class JobApplication:
	var listing: JobListing
	var status: ApplicationStatus
	var offer_weeks_left: int
	var is_referral: bool        # 是否内推
	var is_mass_apply: bool      # 是否海投

	func _init(p_listing: JobListing, p_referral: bool = false,
			p_mass: bool = false) -> void:
		listing = p_listing
		status = ApplicationStatus.APPLIED
		offer_weeks_left = 0
		is_referral = p_referral
		is_mass_apply = p_mass


# ══════════════════════════════════════════
#  外包机会
# ══════════════════════════════════════════

class OutsourceOpportunity:
	var level: OutsourceLevel
	var required_skill: SkillType
	var energy_cost: int       # 随机2-3
	var income: int            # 根据等级和行动力

	func _init(p_level: OutsourceLevel, p_skill: SkillType,
			p_energy: int) -> void:
		level = p_level
		required_skill = p_skill
		energy_cost = p_energy
		# 收入由等级和行动力决定
		if level == OutsourceLevel.MID_OUTSOURCE:
			income = 350 if p_energy == 2 else 500
		else:
			income = 550 if p_energy == 2 else 750

	func get_level_text() -> String:
		match level:
			OutsourceLevel.MID_OUTSOURCE: return "中级外包"
			OutsourceLevel.HIGH_OUTSOURCE: return "高级外包"
			_: return "外包"

	func get_min_skill_level() -> int:
		match level:
			OutsourceLevel.MID_OUTSOURCE: return 4
			OutsourceLevel.HIGH_OUTSOURCE: return 6
			_: return 4


# ══════════════════════════════════════════
#  工具定义 (V3框架保留, V4内容调整)
# ══════════════════════════════════════════

class ToolDef:
	var id: String
	var name: String
	var icon: String
	var price: int
	var weekly_cost: int
	var description: String
	var hint: String

	func _init(p_id: String, p_name: String, p_icon: String, p_price: int,
			p_weekly_cost: int, p_desc: String, p_hint: String) -> void:
		id = p_id
		name = p_name
		icon = p_icon
		price = p_price
		weekly_cost = p_weekly_cost
		description = p_desc
		hint = p_hint


static func get_all_tools() -> Array[ToolDef]:
	return [
		# 生产力工具
		ToolDef.new("mech_keyboard", "机械键盘", "⌨", 400, 0,
			"所有学习行动XP+0.5（每周前2次有效）", "适合：稳定成长路线"),
		ToolDef.new("headphones", "降噪耳机", "🎧", 350, 0,
			"学习不受负面事件影响", "适合：防守型玩家"),
		ToolDef.new("ipad", "二手iPad", "📱", 500, 0,
			"在职时每周自动+0.5XP到随机技能", "适合：先就业再择业"),
		# 经济工具
		ToolDef.new("thinkpad", "二手ThinkPad", "💻", 500, 0,
			"外包成功率+20%，外包收入+$100", "适合：外包流"),
		ToolDef.new("coffee_machine", "咖啡机", "☕", 250, 0,
			"每周生活费-$80", "适合：长线经济规划"),
		ToolDef.new("resume_template", "付费简历模板", "📄", 200, 0,
			"所有简历通过率+5%", "适合：万金油选择"),
		ToolDef.new("zhishixingqiu", "知识星球会员", "🌐", 150, 20,
			"外包刷新概率+15%，外包收入+$80", "适合：外包流"),
		# 社交工具
		ToolDef.new("nice_shirt", "得体的衬衫", "👔", 300, 0,
			"面试通过率+8%", "适合：面试冲刺"),
		ToolDef.new("linkedin", "LinkedIn会员", "🔗", 200, 40,
			"人脉行动每次+2（原+1）", "适合：社交流加速"),
		ToolDef.new("coworking", "共享办公月卡", "🏢", 350, 60,
			"每周自动+0.5人脉，零工收入+20%", "适合：社交+经济复合"),
	]


# ══════════════════════════════════════════
#  特质定义 (V4调整)
# ══════════════════════════════════════════

class TraitDef:
	var id: String
	var name: String
	var category: String        # growth / job / survival / social
	var condition_text: String
	var effect_text: String
	var side_effect_text: String
	var is_conditional: bool

	func _init(p_id: String, p_name: String, p_category: String,
			p_cond: String, p_effect: String, p_side: String = "",
			p_conditional: bool = false) -> void:
		id = p_id
		name = p_name
		category = p_category
		condition_text = p_cond
		effect_text = p_effect
		side_effect_text = p_side
		is_conditional = p_conditional


static func get_all_traits() -> Array[TraitDef]:
	return [
		# 成长型
		TraitDef.new("juanwang", "卷王", "growth",
			"连续3周每周学习≥4次（任意技能组合）", "所有学习XP+0.5",
			"「突发低烧」概率翻倍"),
		TraitDef.new("speedrun", "速通达人", "growth",
			"任一专业技能0→5耗时≤4周", "该技能后续升级XP需求-1（最低1）"),
		TraitDef.new("duomian", "多面手", "growth",
			"3个不同专业技能≥3", "中级岗位面试通过率+10%"),
		# 求职型
		TraitDef.new("mianba", "面霸", "job",
			"累计通过3次面试", "面试基础率+10%"),
		TraitDef.new("haiwang", "海王", "job",
			"累计2周使用海投", "海投随机匹配质量提升（至少1个匹配最高技能方向）"),
		TraitDef.new("negotiator", "谈判专家", "job",
			"拒绝Offer后拿到更高薪Offer", "所有Offer薪资+10%"),
		# 生存型
		TraitDef.new("conservative", "细水长流", "survival",
			"存款连续4周>$3,000", "每周生活费-$50"),
		TraitDef.new("slasher", "斜杠青年", "survival",
			"累计零工/外包≥8次", "所有零工/外包收入+25%"),
		TraitDef.new("desperate", "背水一战", "survival",
			"现金低于$500", "所有行动效果+20%",
			"现金>$1,500后消失", true),
		# 社交型
		TraitDef.new("social_butterfly", "社牛", "social",
			"人际关系≥7", "零工/外包+30%，面试通过率+5%"),
		TraitDef.new("insider", "圈内人", "social",
			"通过内推获得面试≥2次", "内推简历通过率倍率从×1.5升到×2.0"),
		TraitDef.new("outsource_pro", "外包达人", "social",
			"累计完成5次外包", "外包刷新概率+20%，外包失败率降为0"),
	]


# ══════════════════════════════════════════
#  结局评级
# ══════════════════════════════════════════

enum EndingRank { S, A, B, C, F }

static func get_ending_rank(projected_income: int, game_over: bool) -> EndingRank:
	if game_over:
		return EndingRank.F
	if projected_income >= 50000:
		return EndingRank.S
	if projected_income >= 30000:
		return EndingRank.A
	if projected_income >= 15000:
		return EndingRank.B
	if projected_income >= 0:
		return EndingRank.C
	return EndingRank.F

static func get_ending_name(rank: EndingRank) -> String:
	match rank:
		EndingRank.S: return "人生赢家"
		EndingRank.A: return "稳步上升"
		EndingRank.B: return "站稳脚跟"
		EndingRank.C: return "艰难求生"
		EndingRank.F: return "Game Over"
		_: return ""

static func get_ending_description(rank: EndingRank) -> String:
	match rank:
		EndingRank.S: return "大厂高级岗，年薪百万不是梦。你不仅上岸了，还上了最好的岸。"
		EndingRank.A: return "中级岗位，收入不错，还有成长空间。这个起点，不亏。"
		EndingRank.B: return "虽然不是理想工作，但至少有工资发。先活下来，再说别的。"
		EndingRank.C: return "勉强没饿死，但前路漫漫。也许下次会更好。"
		EndingRank.F: return "积蓄耗尽，你不得不回老家了……"
		_: return ""

static func get_rank_letter(rank: EndingRank) -> String:
	match rank:
		EndingRank.S: return "S"
		EndingRank.A: return "A"
		EndingRank.B: return "B"
		EndingRank.C: return "C"
		EndingRank.F: return "F"
		_: return "?"
