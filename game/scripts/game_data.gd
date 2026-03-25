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

# V4: 市场风向周期
const MARKET_WIND_CYCLE := 3         # 每3周可产生新风向
const MARKET_EVENT_CHANCE := 0.25    # 每周25%概率产生市场事件
const MARKET_EVENT_DURATION := 3     # 市场事件默认持续周数

# 批量投递惩罚系数
const BATCH_PENALTY_2 := 0.80
const BATCH_PENALTY_3 := 0.65

# 人脉与作品集
const MAX_NETWORKING_POINTS := 10
const PORTFOLIO_ENERGY_COST := 3
const MAX_PORTFOLIO_POINTS := 3

# V2: 学习疲劳
const STUDY_FULL_XP_LIMIT := 1  # 前N次满XP，第N+1次半XP，之后禁用

# V3: 工具与特质系统
const MAX_TOOLS := 3              # 背包上限
const SHOP_DISPLAY_COUNT := 3     # 每次逛市场展示数量
const SHOP_ENERGY_COST := 1       # 逛二手市场消耗
const REMOTE_GIG_ENERGY := 2      # 远程兼职消耗
const REMOTE_GIG_INCOME := 350    # 远程兼职收入

# V2: 技术私活
const TECH_FREELANCE_ENERGY := 2
const TECH_FREELANCE_BASE := 150
const TECH_FREELANCE_PER_SKILL := 40
const TECH_FREELANCE_MIN_SKILL := 3

# V2: 模拟面试
const MOCK_INTERVIEW_ENERGY := 2
const MOCK_INTERVIEW_VIBE_BONUS := 0.10

# V2: 英语角
const ENGLISH_CORNER_ENERGY := 2

# V2: 做开源
const OPENSOURCE_ENERGY := 2
const PORTFOLIO_XP_NEEDED := 2  # 2次开源 = +1作品集

# V2: 作品集加成（重平衡）
const PORTFOLIO_RESUME_BONUS_PER := 0.10  # was 0.08
const PORTFOLIO_VIBE_MULT: Array = [1.0, 1.10, 1.18, 1.25]  # was [1.0, 1.08, 1.15, 1.20]

# V2: 人脉被动效果
const NETWORKING_VIBE_THRESHOLD := 5   # ≥5: 面试vibe+5%
const NETWORKING_VIBE_BONUS := 0.05
const NETWORKING_APPLY_THRESHOLD := 8  # ≥8: 海投惩罚降一档

# V2: 热门技能
const HOT_SKILL_XP_BONUS := 0.5
const HOT_SKILL_COMPETITION_BONUS := 0.10

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

# ── 学习方式（V2）──
enum StudyType { DOCS, PRACTICE, OPENSOURCE }

# ── 求职状态 ──
enum ApplicationStatus {
	NONE,
	APPLIED,
	HAS_INTERVIEW,
	INTERVIEWED,
	OFFER,
	REJECTED,
}

# ── V4: 公司规模 ──
enum CompanyScale { BIG, MEDIUM, SMALL }

# ── V4: 福利水平 ──
enum BenefitLevel { HIGH, MEDIUM, NORMAL }

# ── V4: 经营状况 ──
enum BusinessStatus { GOOD, STABLE, STRUGGLING }

# ── V4: 市场风向类型 ──
enum MarketWindType { NONE, HOT, SHRINK }

# ── V4: 公司定义 ──
class CompanyDef:
	var id: String
	var name: String
	var scale: CompanyScale
	var benefit_level: BenefitLevel
	var business_status: BusinessStatus      # 可被市场事件改变
	var job_slots_min: int                   # 每次刷新最少参与岗位数
	var job_slots_max: int                   # 每次刷新最多参与岗位数
	var job_generate_chance: float           # 每个岗位位实际生成的概率
	var job_disappear_chance: float          # 每周岗位消失的概率
	var preferred_skill: SkillType           # 公司主营方向

	func _init(p_id: String, p_name: String, p_scale: CompanyScale,
			p_benefit: BenefitLevel, p_status: BusinessStatus,
			p_slots_min: int, p_slots_max: int, p_gen_chance: float,
			p_disappear: float, p_skill: SkillType) -> void:
		id = p_id
		name = p_name
		scale = p_scale
		benefit_level = p_benefit
		business_status = p_status
		job_slots_min = p_slots_min
		job_slots_max = p_slots_max
		job_generate_chance = p_gen_chance
		job_disappear_chance = p_disappear
		preferred_skill = p_skill

	func get_salary_multiplier() -> float:
		match benefit_level:
			BenefitLevel.HIGH:
				return 1.15
			BenefitLevel.MEDIUM:
				return 1.0
			_:
				return 0.90

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


# ── V4: 所有公司 ──
static func get_all_companies() -> Array[CompanyDef]:
	return [
		# 大厂 ×2
		CompanyDef.new("bytedance", "字节飞扬", CompanyScale.BIG,
			BenefitLevel.HIGH, BusinessStatus.GOOD,
			1, 3, 0.50, 0.15, SkillType.APPLICATION),
		CompanyDef.new("deepmind", "深渊后端", CompanyScale.BIG,
			BenefitLevel.HIGH, BusinessStatus.GOOD,
			1, 2, 0.45, 0.20, SkillType.SYSTEM),
		# 中厂 ×3
		CompanyDef.new("cybertech", "赛博科技", CompanyScale.MEDIUM,
			BenefitLevel.MEDIUM, BusinessStatus.GOOD,
			1, 2, 0.55, 0.25, SkillType.SYSTEM),
		CompanyDef.new("geekcloud", "极客云", CompanyScale.MEDIUM,
			BenefitLevel.MEDIUM, BusinessStatus.STABLE,
			1, 2, 0.50, 0.20, SkillType.APPLICATION),
		CompanyDef.new("hashworks", "哈希工业", CompanyScale.MEDIUM,
			BenefitLevel.NORMAL, BusinessStatus.STABLE,
			1, 3, 0.60, 0.30, SkillType.SYSTEM),
		# 小厂 ×3
		CompanyDef.new("stackflow", "栈溢出", CompanyScale.SMALL,
			BenefitLevel.NORMAL, BusinessStatus.STABLE,
			1, 2, 0.65, 0.35, SkillType.APPLICATION),
		CompanyDef.new("recursion", "递归传媒", CompanyScale.SMALL,
			BenefitLevel.MEDIUM, BusinessStatus.STRUGGLING,
			0, 2, 0.40, 0.30, SkillType.APPLICATION),
		CompanyDef.new("pointshop", "指针工坊", CompanyScale.SMALL,
			BenefitLevel.NORMAL, BusinessStatus.STRUGGLING,
			0, 2, 0.45, 0.40, SkillType.SYSTEM),
	]


# ── V4: 市场风向定义 ──
class MarketWindDef:
	var id: String
	var name: String
	var wind_type: MarketWindType      # HOT=某类岗位热门, SHRINK=某类岗位缩减
	var target_skill: SkillType        # 影响哪个方向
	var gen_chance_modifier: float     # 对目标方向公司的岗位生成率修正
	var description: String

	func _init(p_id: String, p_name: String, p_type: MarketWindType,
			p_skill: SkillType, p_mod: float, p_desc: String) -> void:
		id = p_id
		name = p_name
		wind_type = p_type
		target_skill = p_skill
		gen_chance_modifier = p_mod
		description = p_desc


static func get_all_market_winds() -> Array[MarketWindDef]:
	return [
		MarketWindDef.new("sys_hot", "后端/系统岗位需求激增", MarketWindType.HOT,
			SkillType.SYSTEM, 0.20, "各大公司纷纷扩招后端和系统工程师"),
		MarketWindDef.new("app_hot", "前端/应用岗位需求激增", MarketWindType.HOT,
			SkillType.APPLICATION, 0.20, "移动端和Web应用需求旺盛"),
		MarketWindDef.new("sys_shrink", "后端/系统岗位收缩", MarketWindType.SHRINK,
			SkillType.SYSTEM, -0.15, "云服务成本优化，后端岗位缩减"),
		MarketWindDef.new("app_shrink", "前端/应用岗位收缩", MarketWindType.SHRINK,
			SkillType.APPLICATION, -0.15, "低代码平台兴起，前端需求下降"),
	]


# ── V4: 市场事件定义 ──
class MarketEventDef:
	var id: String
	var name: String
	var description: String
	var duration: int                  # 持续周数
	var effect_tag: String             # 用于game_state中判断效果

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
			"监管部门出手整顿，部分公司暂停招聘一周",
			1, "industry_crackdown"),
	]


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
	var company: String              # 公司显示名（兼容旧代码）
	var company_def: CompanyDef      # V4: 所属公司定义
	var actual_salary: int           # 随机化后的实际周薪（基础 ±15% × 福利倍率，取整到10）
	var actual_skill_required: int   # 随机化后的主技能需求（基础 ±1，最低1）
	var actual_english_required: int
	var actual_cpp_required: int     # APPLICATION岗位始终为0
	var weeks_alive: int = 0         # V4: 已存在的周数

	func _init(p_listing_id: String, p_job: JobDef, p_company_def: CompanyDef,
			p_salary: int, p_skill_req: int, p_eng_req: int, p_cpp_req: int) -> void:
		listing_id = p_listing_id
		job = p_job
		company_def = p_company_def
		company = p_company_def.name
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


# ── V3: 工具定义 ──
# 每个工具: id, name, icon, price, weekly_cost, description, hint
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
		ToolDef.new("leetcode", "LeetCode会员", "🔧", 300, 50,
			"刷题XP+1（0-2→1-3）", "适合：高强度刷题路线"),
		ToolDef.new("copilot", "GitHub Copilot", "🤖", 200, 30,
			"做开源只需1EP（原2EP）", "适合：作品集路线"),
		ToolDef.new("mech_keyboard", "机械键盘", "⌨", 400, 0,
			"看文档/教程XP+0.5", "适合：稳定成长路线"),
		ToolDef.new("headphones", "降噪耳机", "🎧", 350, 0,
			"免疫负面事件对学习的影响", "适合：防守型玩家"),
		ToolDef.new("ipad", "二手iPad", "📱", 500, 0,
			"在职时每周自动+0.5XP到随机技能", "适合：先就业再择业"),
		# 经济工具
		ToolDef.new("thinkpad", "二手ThinkPad", "💻", 500, 0,
			"解锁「远程兼职」（2EP→$350）", "适合：高效赚钱"),
		ToolDef.new("coffee_machine", "咖啡机", "☕", 250, 0,
			"每周生活费-$80", "适合：长线经济规划"),
		ToolDef.new("resume_template", "付费简历模板", "📄", 200, 0,
			"所有简历通过率+5%", "适合：万金油选择"),
		ToolDef.new("zhishixingqiu", "知识星球会员", "🌐", 150, 20,
			"技术私活收入+$100", "适合：私活流"),
		# 社交工具
		ToolDef.new("nice_shirt", "得体的衬衫", "👔", 300, 0,
			"面试vibe率+8%", "适合：面试冲刺"),
		ToolDef.new("linkedin", "LinkedIn会员", "🔗", 200, 40,
			"人脉行动每次+2（原+1）", "适合：社交流加速"),
		ToolDef.new("coworking", "共享办公月卡", "🏢", 350, 60,
			"每周自动+0.5人脉，人脉≥5时零工+20%", "适合：社交+经济复合"),
	]


# ── V3: 特质定义 ──
class TraitDef:
	var id: String
	var name: String
	var category: String        # growth / job / survival / social
	var condition_text: String
	var effect_text: String
	var side_effect_text: String  # 空 = 无副作用
	var is_conditional: bool      # true = 条件消失后特质也消失（如背水一战）

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
			"连续3周每周学习≥4次", "所有学习XP+0.5",
			"「突发低烧」概率翻倍"),
		TraitDef.new("speedrun", "速通达人", "growth",
			"任意技能从0升到5耗时≤4周", "该技能后续XP需求-1（最低1）"),
		TraitDef.new("fullstack", "全栈选手", "growth",
			"系统≥4 且 应用≥4", "可投双方向岗位"),
		# 求职型
		TraitDef.new("mianba", "面霸", "job",
			"累计通过3次面试vibe关", "面试vibe基础率+10%"),
		TraitDef.new("haiwang", "海王", "job",
			"累计2次单周投递3份简历", "海投惩罚减半（×0.65→×0.82）"),
		TraitDef.new("negotiator", "谈判专家", "job",
			"拒绝offer后拿到更高薪offer", "所有offer薪资+10%"),
		# 生存型
		TraitDef.new("conservative", "细水长流", "survival",
			"存款连续4周>$3,000", "每周生活费-$50"),
		TraitDef.new("slasher", "斜杠青年", "survival",
			"累计零工/私活≥8次", "所有零工/私活收入+25%"),
		TraitDef.new("desperate", "背水一战", "survival",
			"现金低于$500", "所有行动效果+20%",
			"现金>$1,500后消失", true),
		# 社交型
		TraitDef.new("social_butterfly", "社牛", "social",
			"人脉≥7", "零工/私活+30%，面试vibe+5%"),
		TraitDef.new("opensource_pro", "开源达人", "social",
			"作品集≥2 且 人脉≥3", "开源贡献额外+1人脉"),
		TraitDef.new("insider", "圈内人", "social",
			"通过内推获得面试≥2次", "内推通过率×1.5→×2.0"),
	]
