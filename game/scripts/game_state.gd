## 游戏状态管理 - V4: 公司系统/市场环境/角色技能重构
class_name GameState
extends RefCounted

# ══════════════════════════════════════════
#  玩家状态
# ══════════════════════════════════════════

var week: int = 1
var cash: int = GameData.INITIAL_CASH
var energy: int = GameData.ENERGY_PER_WEEK

# 专业技能 (5个)
var skills: Dictionary = {
	GameData.SkillType.BACKEND: 0,
	GameData.SkillType.FRONTEND: 0,
	GameData.SkillType.ALGORITHM: 0,
	GameData.SkillType.DATA_ENGINEERING: 0,
	GameData.SkillType.INFRASTRUCTURE: 0,
}
var skill_xp: Dictionary = {
	GameData.SkillType.BACKEND: 0.0,
	GameData.SkillType.FRONTEND: 0.0,
	GameData.SkillType.ALGORITHM: 0.0,
	GameData.SkillType.DATA_ENGINEERING: 0.0,
	GameData.SkillType.INFRASTRUCTURE: 0.0,
}

# 通用技能
var communication: int = 0
var communication_xp: float = 0.0
var interview_skill: int = 0
var interview_skill_xp: float = 0.0

# 被动属性
var work_experience: int = 0
var bigco_experience: int = 0
var gap_time: int = 0
var networking_points: int = 0
var personal_project_progress: int = 0   # 0-5, 5=完成
var personal_project_done: bool = false
var outsource_count: int = 0

# ── 工作状态 ──
var current_job_listing: GameData.JobListing = null
var pending_quit: bool = false

# ── 求职进度：listing_id -> JobApplication ──
var applications: Dictionary = {}

# ── 包装简历 ──
var resume_faked: bool = false

# ── 岗位市场 ──
var current_listings: Array[GameData.JobListing] = []

# ── 公司系统 ──
var companies: Array[GameData.CompanyDef] = []

# ── 市场风向 ──
var current_wind: GameData.MarketWindDef = null
var wind_weeks_left: int = 0

# ── 市场事件 ──
var current_market_event: GameData.MarketEventDef = null
var market_event_weeks_left: int = 0
var _original_business_status: Dictionary = {}

# ── 外包机会 ──
var current_outsource: GameData.OutsourceOpportunity = null

# ── 学习疲劳（每周重置）──
var weekly_study_count: Dictionary = {}  # SkillType/GeneralSkillType -> int

# ── 周效果 ──
var _energy_modifier_next_week: int = 0
var _fatigue_bonus_next_week: int = 0
var fatigue_bonus_this_week: int = 0

# ── 工具系统 ──
var owned_tools: Array[String] = []
var shop_available_tools: Array[String] = []
var shop_visited_this_week: bool = false
var _mech_keyboard_uses_this_week: int = 0  # 机械键盘每周前2次有效

# ── 特质系统 ──
var active_traits: Array[String] = []
var _study_streak_weeks: int = 0
var _weekly_study_total: int = 0
var _skill_first_learn_week: Dictionary = {}
var _interview_pass_count: int = 0
var _mass_apply_weeks: int = 0
var _highest_rejected_salary: int = 0
var _has_rejected_offer: bool = false
var _cash_above_3000_weeks: int = 0
var _total_gig_count: int = 0
var _referral_interview_count: int = 0
var _speedrun_skill: GameData.SkillType = GameData.SkillType.BACKEND
var _personal_project_work_this_week: int = 0

# ── 内部 ──
var _all_jobs: Array[GameData.JobDef]
var _all_tools: Array[GameData.ToolDef]
var _all_traits: Array[GameData.TraitDef]
var _all_market_events: Array[GameData.MarketEventDef]
var _listing_counter: int = 0
var _applied_this_week: Array[String] = []
var _interviewed_this_week: Array[String] = []
var _pending_referrals: Array[String] = []
var _weekly_apply_count: int = 0

# ── 统计数据 ──
var stats_total_applications: int = 0
var stats_total_interviews: int = 0
var stats_total_offers: int = 0
var stats_total_rejections: int = 0
var stats_highest_offer_salary: int = 0
var stats_total_gig_income: int = 0
var stats_total_study_count: int = 0

# ── 起始技能 ──
var starting_skill: GameData.SkillType = GameData.SkillType.BACKEND

# ── 面试反馈文案 ──
const _RESUME_GHOST := [
	"（%s 看了眼你的简历，然后沉默了。）",
	"（简历石沉大海，%s 从此杳无音讯。）",
	"（%s 把你的简历移入了回收站，但没有清空。）",
	"（%s 的 HR 可能还没上班。）",
]
const _RESUME_UNDERQUALIFIED := [
	"综合评估后，您的技能暂时与岗位需求有差距，感谢投递。",
	"经过仔细阅读，%s 决定暂不推进，欢迎您提升后再来。",
	"您的申请我们已收到，但目前的匹配度不符合要求。",
]
const _INTERVIEW_FAIL := [
	"说不出哪儿不好，就是感觉不太对。",
	"面试官觉得您与团队文化契合度有些担忧。",
	"双方聊得有点不在一个频道，最终没有推进。",
	"技术没问题，但沟通风格让面试官有些顾虑。",
	"虽然您表现出色，但此次竞争激烈，遗憾落选。",
	"HC 有限，最终选了另一位候选人，非常抱歉。",
]
const _RESUME_FAKE_CAUGHT := [
	"面试官深入追问技术细节，发现与简历描述不符，面试提前结束。",
	"被要求现场手写代码时露馅了，面试官表情微妙。",
	"项目经历被追问后前后矛盾，面试官委婉地结束了面试。",
]


func _init() -> void:
	_all_jobs = GameData.get_all_jobs()
	_all_tools = GameData.get_all_tools()
	_all_traits = GameData.get_all_traits()
	_all_market_events = GameData.get_all_market_events()
	# 深拷贝公司列表
	companies.clear()
	for cdef in GameData.get_all_companies():
		var c := GameData.CompanyDef.new(cdef.id, cdef.name, cdef.scale,
			cdef.benefit_level, cdef.business_status,
			cdef.job_slots_min, cdef.job_slots_max, cdef.job_generate_chance,
			cdef.job_disappear_chance, cdef.preferred_skills)
		companies.append(c)


## 选择起始专业技能并初始化游戏
func start_game(chosen_skill: GameData.SkillType) -> void:
	starting_skill = chosen_skill
	skills[chosen_skill] = 3
	skill_xp[chosen_skill] = 0.0  # 3级, 已积累6 XP (1+2+3=6)
	_generate_all_company_listings()


# ══════════════════════════════════════════
#  能量与技能
# ══════════════════════════════════════════

func get_free_energy() -> int:
	var locked := 0
	if current_job_listing:
		locked = current_job_listing.job.energy_cost
	return energy - locked


func get_skill(skill_type: GameData.SkillType) -> int:
	return skills[skill_type]


func get_skill_xp_progress(skill_type: GameData.SkillType) -> String:
	var lv: int = skills[skill_type]
	if lv >= GameData.MAX_SKILL_LEVEL:
		return "MAX"
	var needed: int = GameData.xp_needed_for_level(lv + 1)
	var current: float = skill_xp[skill_type]
	if absf(current - roundf(current)) < 0.01:
		return "%d/%d" % [roundi(current), needed]
	else:
		return "%.1f/%d" % [current, needed]


func get_general_skill_xp_progress(is_communication: bool) -> String:
	var lv: int = communication if is_communication else interview_skill
	var xp: float = communication_xp if is_communication else interview_skill_xp
	if lv >= GameData.MAX_SKILL_LEVEL:
		return "MAX"
	var needed: int = GameData.xp_needed_for_level(lv + 1)
	if absf(xp - roundf(xp)) < 0.01:
		return "%d/%d" % [roundi(xp), needed]
	else:
		return "%.1f/%d" % [xp, needed]


func _add_skill_xp(skill_type: GameData.SkillType, amount: float) -> void:
	if amount <= 0:
		return
	skill_xp[skill_type] += amount
	var lv: int = skills[skill_type]
	while lv < GameData.MAX_SKILL_LEVEL:
		var needed := float(GameData.xp_needed_for_level(lv + 1))
		# 速通达人XP减免
		if has_trait("speedrun") and skill_type == _speedrun_skill:
			needed = maxf(1.0, needed - 1.0)
		if skill_xp[skill_type] >= needed:
			skill_xp[skill_type] -= needed
			lv += 1
			skills[skill_type] = lv
		else:
			break
	if lv >= GameData.MAX_SKILL_LEVEL:
		skill_xp[skill_type] = 0.0


func _add_general_skill_xp(is_communication: bool, amount: float) -> void:
	if amount <= 0:
		return
	if is_communication:
		communication_xp += amount
		while communication < GameData.MAX_SKILL_LEVEL:
			var needed := float(GameData.xp_needed_for_level(communication + 1))
			if communication_xp >= needed:
				communication_xp -= needed
				communication += 1
			else:
				break
		if communication >= GameData.MAX_SKILL_LEVEL:
			communication_xp = 0.0
	else:
		interview_skill_xp += amount
		while interview_skill < GameData.MAX_SKILL_LEVEL:
			var needed := float(GameData.xp_needed_for_level(interview_skill + 1))
			if interview_skill_xp >= needed:
				interview_skill_xp -= needed
				interview_skill += 1
			else:
				break
		if interview_skill >= GameData.MAX_SKILL_LEVEL:
			interview_skill_xp = 0.0


# ══════════════════════════════════════════
#  工具与特质查询
# ══════════════════════════════════════════

func has_tool(tool_id: String) -> bool:
	return owned_tools.has(tool_id)

func has_trait(trait_id: String) -> bool:
	return active_traits.has(trait_id)

func get_tool_weekly_cost() -> int:
	var total := 0
	for tid in owned_tools:
		var tdef := _find_tool_def(tid)
		if tdef:
			total += tdef.weekly_cost
	return total

func _find_tool_def(tool_id: String) -> GameData.ToolDef:
	for t in _all_tools:
		if t.id == tool_id:
			return t
	return null

func _find_trait_def(trait_id: String) -> GameData.TraitDef:
	for t in _all_traits:
		if t.id == trait_id:
			return t
	return null

## 零工/外包收入倍率
func _get_gig_income_multiplier() -> float:
	var mult := 1.0
	if has_trait("slasher"):
		mult += 0.25
	if has_trait("social_butterfly"):
		mult += 0.30
	if has_tool("coworking") and networking_points >= 5:
		mult += 0.20
	return mult

## 学习XP加成
func _get_study_xp_bonus() -> float:
	var bonus := 0.0
	if has_trait("juanwang"):
		bonus += 0.5
	if has_trait("desperate"):
		bonus += 0.2
	# 机械键盘: 每周前2次有效
	if has_tool("mech_keyboard") and _mech_keyboard_uses_this_week < 2:
		bonus += 0.5
		_mech_keyboard_uses_this_week += 1
	return bonus


# ══════════════════════════════════════════
#  学习行动 (V4: 每种技能一种学习方式, 1EP)
# ══════════════════════════════════════════

## 获取学习疲劳状态: "normal" / "half"
func get_study_fatigue(key: Variant) -> String:
	var count: int = weekly_study_count.get(key, 0)
	var threshold: int = GameData.STUDY_FATIGUE_THRESHOLD + fatigue_bonus_this_week
	if count < threshold - 1:
		return "normal"
	else:
		return "half"  # 第4次及以后减半


## 学习专业技能 (1EP)
func action_study_skill(skill_type: GameData.SkillType) -> bool:
	if skills[skill_type] >= GameData.MAX_SKILL_LEVEL:
		return false
	if get_free_energy() < 1:
		return false
	energy -= 1
	var count: int = weekly_study_count.get(skill_type, 0)
	var threshold: int = GameData.STUDY_FATIGUE_THRESHOLD + fatigue_bonus_this_week
	var xp_gain: float = 1.0
	if count >= threshold - 1:
		xp_gain = 0.5  # 第4次起减半
	xp_gain += _get_study_xp_bonus()
	weekly_study_count[skill_type] = count + 1
	_weekly_study_total += 1
	stats_total_study_count += 1
	_track_skill_start(skill_type)
	_add_skill_xp(skill_type, xp_gain)
	return true


## 学习沟通 (1EP)
func action_study_communication() -> bool:
	if communication >= GameData.MAX_SKILL_LEVEL:
		return false
	if get_free_energy() < 1:
		return false
	energy -= 1
	var key := "communication"
	var count: int = weekly_study_count.get(key, 0)
	var threshold: int = GameData.STUDY_FATIGUE_THRESHOLD + fatigue_bonus_this_week
	var xp_gain: float = 1.0
	if count >= threshold - 1:
		xp_gain = 0.5
	xp_gain += _get_study_xp_bonus()
	weekly_study_count[key] = count + 1
	_weekly_study_total += 1
	stats_total_study_count += 1
	_add_general_skill_xp(true, xp_gain)
	return true


## 学习面试技巧 (1EP)
func action_study_interview() -> bool:
	if interview_skill >= GameData.MAX_SKILL_LEVEL:
		return false
	if get_free_energy() < 1:
		return false
	energy -= 1
	var key := "interview_skill"
	var count: int = weekly_study_count.get(key, 0)
	var threshold: int = GameData.STUDY_FATIGUE_THRESHOLD + fatigue_bonus_this_week
	var xp_gain: float = 1.0
	if count >= threshold - 1:
		xp_gain = 0.5
	xp_gain += _get_study_xp_bonus()
	weekly_study_count[key] = count + 1
	_weekly_study_total += 1
	stats_total_study_count += 1
	_add_general_skill_xp(false, xp_gain)
	return true


# ══════════════════════════════════════════
#  求职行动
# ══════════════════════════════════════════

## 精投简历 (1EP, 选择1个岗位投递)
func action_focused_apply(listing_id: String) -> bool:
	if get_free_energy() < 1:
		return false
	var listing := _find_listing(listing_id)
	if listing == null:
		return false
	if applications.has(listing_id):
		var app: GameData.JobApplication = applications[listing_id]
		if app.status != GameData.ApplicationStatus.REJECTED:
			return false
	energy -= 1
	var new_app := GameData.JobApplication.new(listing)
	applications[listing_id] = new_app
	_applied_this_week.append(listing_id)
	stats_total_applications += 1
	_weekly_apply_count += 1
	return true


## 海投简历 (1EP, 系统随机选5个岗位投递)
func action_mass_apply() -> Array[String]:
	if get_free_energy() < 1:
		return []
	energy -= 1
	var eligible: Array[GameData.JobListing] = []
	for listing in current_listings:
		if applications.has(listing.listing_id):
			var app: GameData.JobApplication = applications[listing.listing_id]
			if app.status != GameData.ApplicationStatus.REJECTED:
				continue
		eligible.append(listing)
	eligible.shuffle()
	var applied: Array[String] = []
	var count := mini(GameData.MASS_APPLY_COUNT, eligible.size())
	for i in range(count):
		var listing := eligible[i]
		var new_app := GameData.JobApplication.new(listing, false, true)
		applications[listing.listing_id] = new_app
		_applied_this_week.append(listing.listing_id)
		applied.append(listing.listing_id)
		stats_total_applications += 1
	_weekly_apply_count += count
	_mass_apply_weeks += 1  # 追踪海王进度（使用海投的周数）
	return applied


## 参加面试 (2EP, 基础设施方向1EP)
func get_interview_cost() -> int:
	if starting_skill == GameData.SkillType.INFRASTRUCTURE:
		return GameData.SKILL_BONUS_INFRA_INTERVIEW_COST
	return 2

func action_interview(listing_id: String) -> bool:
	var cost := get_interview_cost()
	if get_free_energy() < cost:
		return false
	if not applications.has(listing_id):
		return false
	var app: GameData.JobApplication = applications[listing_id]
	if app.status != GameData.ApplicationStatus.HAS_INTERVIEW:
		return false
	energy -= cost
	app.status = GameData.ApplicationStatus.INTERVIEWED
	_interviewed_this_week.append(listing_id)
	stats_total_interviews += 1
	return true


## 包装简历 (2EP)
func action_fake_resume() -> bool:
	if resume_faked:
		return false
	if get_free_energy() < 2:
		return false
	energy -= 2
	resume_faked = true
	return true


## 取消包装 (0EP)
func action_cancel_fake_resume() -> bool:
	if not resume_faked:
		return false
	resume_faked = false
	return true


## 接受Offer
func action_accept_offer(listing_id: String) -> bool:
	if not applications.has(listing_id):
		return false
	var app: GameData.JobApplication = applications[listing_id]
	if app.status != GameData.ApplicationStatus.OFFER:
		return false
	# 面试技巧≥4的薪资加成：拿到Offer时30%概率额外+10-15%
	var offer_salary := app.listing.actual_salary
	if interview_skill >= 4 and randf() < 0.30:
		var bonus_pct := randf_range(0.10, 0.15)
		offer_salary = roundi(offer_salary * (1.0 + bonus_pct))
		app.listing.actual_salary = offer_salary
	# 谈判专家+10%
	if has_trait("negotiator"):
		offer_salary = roundi(offer_salary * 1.10)
		app.listing.actual_salary = offer_salary
	current_job_listing = app.listing
	pending_quit = false
	# 入职+1人际关系
	networking_points = mini(networking_points + 1, GameData.MAX_NETWORKING_POINTS)
	# 清零gap
	gap_time = 0
	applications.erase(listing_id)
	return true


## 拒绝Offer
func action_reject_offer(listing_id: String) -> bool:
	if not applications.has(listing_id):
		return false
	var app: GameData.JobApplication = applications[listing_id]
	if app.status != GameData.ApplicationStatus.OFFER:
		return false
	_has_rejected_offer = true
	if app.listing.actual_salary > _highest_rejected_salary:
		_highest_rejected_salary = app.listing.actual_salary
	applications.erase(listing_id)
	return true


## 辞职
func action_quit() -> bool:
	if current_job_listing == null:
		return false
	pending_quit = true
	return true


# ══════════════════════════════════════════
#  社交行动
# ══════════════════════════════════════════

## 维护人际关系 (1EP, +1, LinkedIn+2)
func action_networking() -> bool:
	if get_free_energy() < 1:
		return false
	if networking_points >= GameData.MAX_NETWORKING_POINTS:
		return false
	energy -= 1
	var gain := 1
	if has_tool("linkedin"):
		gain = 2
	networking_points = mini(networking_points + gain, GameData.MAX_NETWORKING_POINTS)
	return true


## 做个人作品 (1EP, 需专业技能>4, 每周最多3次)
func action_personal_project() -> bool:
	if personal_project_done:
		return false
	if _personal_project_work_this_week >= GameData.PERSONAL_PROJECT_MAX_PER_WEEK:
		return false
	# 检查前置条件
	var has_skill := false
	for st in GameData.get_all_skill_types():
		if skills[st] >= GameData.PERSONAL_PROJECT_MIN_SKILL:
			has_skill = true
			break
	if not has_skill:
		return false
	if get_free_energy() < 1:
		return false
	energy -= 1
	personal_project_progress += 1
	_personal_project_work_this_week += 1
	if personal_project_progress >= GameData.PERSONAL_PROJECT_COST:
		personal_project_done = true
		gap_time = 0  # 完成后Gap清零
	return true


# ══════════════════════════════════════════
#  生存行动
# ══════════════════════════════════════════

## 打零工·兼职 (3EP, +$280)
func action_gig_parttime() -> bool:
	if get_free_energy() < GameData.GIG_ENERGY_PARTTIME:
		return false
	energy -= GameData.GIG_ENERGY_PARTTIME
	var income := roundi(GameData.GIG_INCOME_PARTTIME * _get_gig_income_multiplier())
	cash += income
	stats_total_gig_income += income
	_total_gig_count += 1
	return true


## 打零工·全职 (5EP, +$520)
func action_gig_fulltime() -> bool:
	if get_free_energy() < GameData.GIG_ENERGY_FULLTIME:
		return false
	energy -= GameData.GIG_ENERGY_FULLTIME
	var income := roundi(GameData.GIG_INCOME_FULLTIME * _get_gig_income_multiplier())
	cash += income
	stats_total_gig_income += income
	_total_gig_count += 1
	return true


## 接外包
func action_take_outsource() -> bool:
	if current_outsource == null:
		return false
	if get_free_energy() < current_outsource.energy_cost:
		return false
	energy -= current_outsource.energy_cost
	var skill_level: int = skills[current_outsource.required_skill]
	var min_level := current_outsource.get_min_skill_level()
	# 失败判定
	var fail_chance := 0.0
	if skill_level - min_level < 2:
		fail_chance = GameData.OUTSOURCE_FAIL_CHANCE
	# ThinkPad加成
	if has_tool("thinkpad"):
		fail_chance = maxf(0.0, fail_chance - 0.20)
	# 外包达人: 失败率降为0
	if has_trait("outsource_pro"):
		fail_chance = 0.0
	if randf() < fail_chance:
		current_outsource = null
		return true  # 失败但行动力已消耗
	var income := current_outsource.income
	# ThinkPad+$100
	if has_tool("thinkpad"):
		income += 100
	# 知识星球+$80
	if has_tool("zhishixingqiu"):
		income += 80
	# 数据工程方向：外包收入+20%
	if starting_skill == GameData.SkillType.DATA_ENGINEERING:
		income = roundi(income * (1.0 + GameData.SKILL_BONUS_DATA_OUTSOURCE_INCOME))
	income = roundi(income * _get_gig_income_multiplier())
	cash += income
	stats_total_gig_income += income
	outsource_count += 1
	_total_gig_count += 1
	current_outsource = null
	return true


func get_outsource_failed() -> bool:
	# 上次接外包是否失败（简化：通过current_outsource==null且上次action返回true判断）
	return false


## 获取兼职收入（供UI显示）
func get_gig_income(is_fulltime: bool) -> int:
	var base := GameData.GIG_INCOME_FULLTIME if is_fulltime else GameData.GIG_INCOME_PARTTIME
	return roundi(base * _get_gig_income_multiplier())


# ══════════════════════════════════════════
#  工具行动 (V3保留)
# ══════════════════════════════════════════

func action_browse_shop() -> bool:
	if get_free_energy() < GameData.SHOP_ENERGY_COST:
		return false
	energy -= GameData.SHOP_ENERGY_COST
	_refresh_shop()
	shop_visited_this_week = true
	return true

func _refresh_shop() -> void:
	var available: Array[String] = []
	for t in _all_tools:
		if not owned_tools.has(t.id):
			available.append(t.id)
	available.shuffle()
	shop_available_tools.clear()
	for i in range(mini(GameData.SHOP_DISPLAY_COUNT, available.size())):
		shop_available_tools.append(available[i])

func action_buy_tool(tool_id: String) -> bool:
	var tdef := _find_tool_def(tool_id)
	if tdef == null:
		return false
	if owned_tools.has(tool_id):
		return false
	if cash < tdef.price:
		return false
	if owned_tools.size() >= GameData.MAX_TOOLS:
		return false
	cash -= tdef.price
	owned_tools.append(tool_id)
	return true

func action_replace_tool(old_tool_id: String, new_tool_id: String) -> bool:
	if not owned_tools.has(old_tool_id):
		return false
	var tdef := _find_tool_def(new_tool_id)
	if tdef == null:
		return false
	if cash < tdef.price:
		return false
	cash -= tdef.price
	owned_tools.erase(old_tool_id)
	owned_tools.append(new_tool_id)
	return true


# ══════════════════════════════════════════
#  周结算
# ══════════════════════════════════════════

class WeekSettlement:
	var salary_earned: int = 0
	var living_cost: int = GameData.WEEKLY_LIVING_COST
	var tool_cost: int = 0
	var cash_before: int = 0
	var cash_after: int = 0
	var notifications: Array[String] = []
	var expired_offers: Array[String] = []
	var is_game_over: bool = false
	var did_quit: bool = false
	var new_traits: Array[String] = []
	var lost_traits: Array[String] = []
	var wind_changed: bool = false
	var market_event_started: bool = false
	var referral_listing_id: String = ""
	var outsource_available: bool = false
	var event_name: String = ""
	var event_desc: String = ""


func settle_week() -> WeekSettlement:
	var result := WeekSettlement.new()
	result.cash_before = cash

	# 0. 内推处理
	for ref_id in _pending_referrals:
		if not _applied_this_week.has(ref_id):
			_applied_this_week.append(ref_id)
	_pending_referrals.clear()

	# 1. 发工资 / Gap时间
	if current_job_listing:
		result.salary_earned = current_job_listing.actual_salary
		cash += result.salary_earned
		work_experience += 1
		if current_job_listing.company_def.scale == GameData.CompanyScale.BIG:
			bigco_experience += 1
	else:
		gap_time += 1

	# 2. 扣生活费
	var living := GameData.WEEKLY_LIVING_COST
	if has_tool("coffee_machine"):
		living -= 80
	if has_trait("conservative"):
		living -= 50
	result.living_cost = living
	cash -= living

	# 2.5 扣工具订阅费
	var tool_cost := get_tool_weekly_cost()
	if tool_cost > 0:
		cash -= tool_cost
		result.tool_cost = tool_cost

	# 3. 处理简历结果
	_process_resume_results(result)

	# 4. 处理面试结果
	_process_interview_results(result)

	# 5. 内推判定
	_check_referral(result)

	# 6. 外包刷新判定
	_check_outsource_refresh(result)

	# 7. Offer有效期-1
	var to_expire: Array[String] = []
	for listing_id in applications:
		var app: GameData.JobApplication = applications[listing_id]
		if app.status == GameData.ApplicationStatus.OFFER:
			app.offer_weeks_left -= 1
			if app.offer_weeks_left <= 0:
				to_expire.append(listing_id)
				result.expired_offers.append(
					"%s @ %s" % [app.listing.job.title, app.listing.company_def.name])
	for listing_id in to_expire:
		applications.erase(listing_id)

	# 8. 特质条件检查
	_check_traits(result)

	# 8.5 处理辞职
	if pending_quit:
		result.did_quit = true
		result.notifications.append("你已离职：%s @ %s" % [
			current_job_listing.job.title, current_job_listing.company_def.name])
		current_job_listing = null
		pending_quit = false

	# 8.6 工具被动效果
	# iPad: 在职时每周自动+0.5XP到随机技能
	if has_tool("ipad") and current_job_listing:
		var random_skills := GameData.get_all_skill_types()
		var chosen: GameData.SkillType = random_skills[randi() % random_skills.size()]
		if skills[chosen] < GameData.MAX_SKILL_LEVEL:
			_add_skill_xp(chosen, 0.5)
			result.notifications.append("📱 iPad通勤学习：+0.5 %s XP" % GameData.get_skill_name(chosen))

	# 共享办公: 每周自动+0.5人脉（偶数周+1）
	if has_tool("coworking") and networking_points < GameData.MAX_NETWORKING_POINTS:
		if week % 2 == 0:
			networking_points = mini(networking_points + 1, GameData.MAX_NETWORKING_POINTS)

	# 8.7 卷王/海王 周追踪
	if _weekly_study_total >= 4:
		_study_streak_weeks += 1
	else:
		_study_streak_weeks = 0

	# 细水长流追踪
	if cash > 3000:
		_cash_above_3000_weeks += 1
	else:
		_cash_above_3000_weeks = 0

	# 9. 岗位消失判定
	_process_job_disappearance(result)

	# 10. 市场风向/事件更新
	# 风向倒计时
	if wind_weeks_left > 0:
		wind_weeks_left -= 1
		if wind_weeks_left == 0:
			result.notifications.append("📊 市场风向「%s」已结束" % current_wind.name)
			current_wind = null

	# 事件倒计时
	if market_event_weeks_left > 0:
		market_event_weeks_left -= 1
		if market_event_weeks_left == 0:
			_end_market_event(result)

	# 每3周判定新风向（第1周不判定）
	if week > 1 and (week - 1) % GameData.MARKET_WIND_CYCLE == 0 and wind_weeks_left == 0:
		_roll_market_wind(result)

	# 每周判定市场事件
	if market_event_weeks_left == 0 and randf() < GameData.MARKET_EVENT_CHANCE:
		_roll_market_event(result)

	# 11. 岗位生成
	_generate_all_company_listings()

	# 12. 个人随机事件
	if randf() < 0.30:
		_process_random_event(result)

	# 13. Game Over判定
	result.cash_after = cash
	if cash < 0:
		result.is_game_over = true

	# 14. 推进到下一周
	week += 1
	energy = maxi(1, GameData.ENERGY_PER_WEEK + _energy_modifier_next_week)
	_energy_modifier_next_week = 0
	fatigue_bonus_this_week = _fatigue_bonus_next_week
	_fatigue_bonus_next_week = 0
	weekly_study_count.clear()
	_applied_this_week.clear()
	_interviewed_this_week.clear()
	_weekly_study_total = 0
	_weekly_apply_count = 0
	_personal_project_work_this_week = 0
	_mech_keyboard_uses_this_week = 0
	shop_visited_this_week = false

	# 15. 结局判定
	# (由UI在week > MAX_WEEKS时调用get_ending)

	return result


# ══════════════════════════════════════════
#  结算子流程
# ══════════════════════════════════════════

func _process_resume_results(result: WeekSettlement) -> void:
	for listing_id in _applied_this_week:
		if not applications.has(listing_id):
			continue
		var app: GameData.JobApplication = applications[listing_id]
		if app.status != GameData.ApplicationStatus.APPLIED:
			continue
		var listing := app.listing
		var title := listing.get_display_title()

		# 10% 鬼了
		if randf() < 0.10:
			app.status = GameData.ApplicationStatus.REJECTED
			stats_total_rejections += 1
			var msg: String = _RESUME_GHOST[randi() % _RESUME_GHOST.size()]
			result.notifications.append("%s：%s" % [title, msg % listing.company_def.name])
			continue

		var pass_rate := calc_resume_pass_rate(listing, app.is_referral)
		if randf() < pass_rate:
			app.status = GameData.ApplicationStatus.HAS_INTERVIEW
			var referral_note := "（内推加成！）" if app.is_referral else ""
			if app.is_referral:
				_referral_interview_count += 1
			result.notifications.append("✅ %s：简历通过！已安排面试。%s" % [title, referral_note])
		else:
			app.status = GameData.ApplicationStatus.REJECTED
			stats_total_rejections += 1
			var msg: String = _RESUME_UNDERQUALIFIED[randi() % _RESUME_UNDERQUALIFIED.size()]
			var formatted := msg % listing.company_def.name if "%s" in msg else msg
			result.notifications.append("❌ %s（通过率%.0f%%）：%s" % [
				title, pass_rate * 100, formatted])


func _process_interview_results(result: WeekSettlement) -> void:
	for listing_id in _interviewed_this_week:
		if not applications.has(listing_id):
			continue
		var app: GameData.JobApplication = applications[listing_id]
		if app.status != GameData.ApplicationStatus.INTERVIEWED:
			continue
		var listing := app.listing
		var title := listing.get_display_title()

		# 包装简历拆穿判定
		if resume_faked and randf() < GameData.RESUME_FAKE_CATCH_CHANCE:
			app.status = GameData.ApplicationStatus.REJECTED
			stats_total_rejections += 1
			var msg: String = _RESUME_FAKE_CAUGHT[randi() % _RESUME_FAKE_CAUGHT.size()]
			result.notifications.append("❌ %s（包装被拆穿）：%s" % [title, msg])
			continue

		var pass_rate := calc_interview_pass_rate(listing)
		if randf() < pass_rate:
			app.status = GameData.ApplicationStatus.OFFER
			app.offer_weeks_left = GameData.OFFER_VALIDITY_WEEKS
			stats_total_offers += 1
			if listing.actual_salary > stats_highest_offer_salary:
				stats_highest_offer_salary = listing.actual_salary
			# 谈判专家检测
			if _has_rejected_offer and listing.actual_salary > _highest_rejected_salary \
					and not has_trait("negotiator"):
				_check_and_grant_trait("negotiator", result)
			_interview_pass_count += 1
			result.notifications.append(
				"🎉 %s Offer！（周薪 $%d，%d周内有效）" % [
					title, listing.actual_salary, app.offer_weeks_left])
		else:
			app.status = GameData.ApplicationStatus.REJECTED
			stats_total_rejections += 1
			var msg: String = _INTERVIEW_FAIL[randi() % _INTERVIEW_FAIL.size()]
			result.notifications.append("❌ %s（面试%.0f%%未通过）：%s" % [
				title, pass_rate * 100, msg])


func _check_referral(result: WeekSettlement) -> void:
	if networking_points < 1:
		return
	var chance := GameData.REFERRAL_BASE_CHANCE * (1.0 + networking_points * GameData.REFERRAL_NETWORKING_MULT)
	if randf() >= chance:
		return
	var listing := _pick_referral_listing()
	if listing == null:
		return
	var new_app := GameData.JobApplication.new(listing, true)
	applications[listing.listing_id] = new_app
	_pending_referrals.append(listing.listing_id)
	result.referral_listing_id = listing.listing_id
	result.notifications.append(
		"🤝 朋友内推：%s，简历通过率×%.0f%%！" % [
			listing.get_display_title(),
			(GameData.REFERRAL_RESUME_MULT if not has_trait("insider") else 2.0) * 100])


func _check_outsource_refresh(result: WeekSettlement) -> void:
	current_outsource = null
	var chance := GameData.OUTSOURCE_BASE_REFRESH_CHANCE \
		+ outsource_count * GameData.OUTSOURCE_REFRESH_PER_COMPLETION
	if has_tool("zhishixingqiu"):
		chance += 0.15
	if has_trait("outsource_pro"):
		chance += 0.20
	# 数据工程方向特色：外包刷新率+15%
	if starting_skill == GameData.SkillType.DATA_ENGINEERING:
		chance += GameData.SKILL_BONUS_DATA_OUTSOURCE
	chance = clampf(chance, 0.30, 0.75)
	if randf() >= chance:
		return
	# 找到可用的技能
	var eligible_skills: Array = []
	for st in GameData.get_all_skill_types():
		if skills[st] >= 4:
			eligible_skills.append(st)
	if eligible_skills.is_empty():
		return
	var chosen_skill: GameData.SkillType = eligible_skills[randi() % eligible_skills.size()]
	# 决定等级
	var level: GameData.OutsourceLevel = GameData.OutsourceLevel.MID_OUTSOURCE
	if skills[chosen_skill] >= 6 and randf() < 0.5:
		level = GameData.OutsourceLevel.HIGH_OUTSOURCE
	var energy_cost := 2 + (randi() % 2)  # 2-3
	current_outsource = GameData.OutsourceOpportunity.new(level, chosen_skill, energy_cost)
	result.outsource_available = true
	result.notifications.append("💼 外包机会：%s（%s Lv.%d+，%dEP→$%d）" % [
		current_outsource.get_level_text(),
		GameData.get_skill_name(chosen_skill),
		current_outsource.get_min_skill_level(),
		current_outsource.energy_cost,
		current_outsource.income])


func _process_job_disappearance(result: WeekSettlement) -> void:
	var disappeared: Array[String] = []
	var surviving: Array[GameData.JobListing] = []
	for listing in current_listings:
		listing.weeks_alive += 1
		if applications.has(listing.listing_id):
			surviving.append(listing)
			continue
		var disappear_chance := listing.company_def.job_disappear_chance
		if listing.company_def.business_status == GameData.BusinessStatus.STRUGGLING:
			disappear_chance += 0.10
		if randf() < disappear_chance:
			disappeared.append(listing.get_display_title())
		else:
			surviving.append(listing)
	current_listings = surviving
	if disappeared.size() > 0:
		result.notifications.append("📋 岗位被抢走：%s" % "、".join(disappeared))


# ══════════════════════════════════════════
#  市场风向与市场事件
# ══════════════════════════════════════════

func _roll_market_wind(result: WeekSettlement) -> void:
	if randf() < (1.0 - GameData.MARKET_WIND_CHANCE):
		return
	current_wind = GameData.generate_random_wind()
	wind_weeks_left = GameData.MARKET_WIND_CYCLE
	result.wind_changed = true
	result.notifications.append("📊 市场风向：%s（持续%d周）" % [current_wind.name, wind_weeks_left])


func _roll_market_event(result: WeekSettlement) -> void:
	var event: GameData.MarketEventDef = _all_market_events[randi() % _all_market_events.size()]
	current_market_event = event
	market_event_weeks_left = event.duration
	result.market_event_started = true
	result.notifications.append("⚡ 市场事件：%s（持续%d周）" % [event.name, event.duration])
	result.notifications.append("   %s" % event.description)
	_apply_market_event(event)


func _apply_market_event(event: GameData.MarketEventDef) -> void:
	match event.effect_tag:
		"ai_shock":
			_original_business_status.clear()
			for c in companies:
				_original_business_status[c.id] = c.business_status
				match c.business_status:
					GameData.BusinessStatus.GOOD:
						c.business_status = GameData.BusinessStatus.STABLE
					GameData.BusinessStatus.STABLE:
						c.business_status = GameData.BusinessStatus.STRUGGLING
		"economy_down":
			pass  # 效果在岗位生成时检查
		"policy_boost":
			pass  # 效果在面试计算中检查
		"funding_boom":
			_original_business_status.clear()
			for c in companies:
				_original_business_status[c.id] = c.business_status
				if c.scale != GameData.CompanyScale.BIG and randf() < 0.60:
					match c.business_status:
						GameData.BusinessStatus.STRUGGLING:
							c.business_status = GameData.BusinessStatus.STABLE
						GameData.BusinessStatus.STABLE:
							c.business_status = GameData.BusinessStatus.GOOD
		"industry_crackdown":
			pass  # 效果在岗位生成时检查


func _end_market_event(result: WeekSettlement) -> void:
	if current_market_event == null:
		return
	result.notifications.append("📰 市场事件「%s」已结束" % current_market_event.name)
	if current_market_event.effect_tag in ["ai_shock", "funding_boom"]:
		for c in companies:
			if _original_business_status.has(c.id):
				c.business_status = _original_business_status[c.id] as GameData.BusinessStatus
		_original_business_status.clear()
	current_market_event = null


# ══════════════════════════════════════════
#  随机事件
# ══════════════════════════════════════════

func _process_random_event(result: WeekSettlement) -> void:
	var pool: Array = []

	var immune := has_tool("headphones")
	var sick_mult := 2.0 if has_trait("juanwang") else 1.0

	if not immune:
		pool.append(["computer_broke", 3])
	pool.append(["rent_increase", 2])
	pool.append(["unexpected_expense", 2])
	if not immune:
		pool.append(["sick", int(2.0 * sick_mult)])
	else:
		pool.append(["sick", int(1.0 * sick_mult)])

	pool.append(["freelance_gig", 3])
	pool.append(["good_mood", 2])
	pool.append(["cheap_food", 2])
	pool.append(["flash_inspiration", 2])

	if networking_points >= 1:
		pool.append(["networking_opportunity", 2])

	if current_job_listing:
		pool.append(["quarterly_bonus", 1])

	var total_weight := 0
	for entry: Array in pool:
		total_weight += entry[1] as int
	if total_weight <= 0:
		return

	var roll := randi() % total_weight
	var cumulative := 0
	var chosen_id := ""
	for entry: Array in pool:
		cumulative += entry[1] as int
		if roll < cumulative:
			chosen_id = entry[0] as String
			break
	if chosen_id.is_empty():
		return

	match chosen_id:
		"computer_broke":
			result.event_name = "🔧 电脑出了点问题"
			result.event_desc = "紧急维修费 $300。"
			cash -= 300
		"rent_increase":
			result.event_name = "🏠 临时涨租"
			result.event_desc = "房东要求补交差价，额外支出 $250。"
			cash -= 250
		"unexpected_expense":
			result.event_name = "💸 意外支出"
			result.event_desc = "突发支出 -$500。"
			cash -= 500
		"sick":
			result.event_name = "🤒 突发低烧"
			result.event_desc = "下周最大能量 -2。"
			_energy_modifier_next_week -= 2
		"freelance_gig":
			result.event_name = "💰 接到小单"
			result.event_desc = "意外接到外包小单，收入 +$350。"
			cash += 350
		"good_mood":
			result.event_name = "☀ 今天状态奇好"
			result.event_desc = "下周能量上限 +2。"
			_energy_modifier_next_week += 2
		"cheap_food":
			result.event_name = "🍜 发现省钱攻略"
			result.event_desc = "附近超市大促，生活补贴 +$250。"
			cash += 250
		"flash_inspiration":
			result.event_name = "💡 灵感爆发"
			result.event_desc = "下周学习任意专业技能获得双倍XP（疲劳阈值+1）！"
			_fatigue_bonus_next_week = 1
		"networking_opportunity":
			result.event_name = "🤝 社交机会"
			result.event_desc = "参加行业聚会，人际关系+1。"
			networking_points = mini(networking_points + 1, GameData.MAX_NETWORKING_POINTS)
		"quarterly_bonus":
			result.event_name = "🎁 季度奖金"
			result.event_desc = "公司发放季度奖金 +$600。"
			cash += 600


# ══════════════════════════════════════════
#  特质系统
# ══════════════════════════════════════════

func _check_traits(result: WeekSettlement) -> void:
	# 卷王：连续3周学习≥4次
	if not has_trait("juanwang") and _study_streak_weeks >= 3:
		_check_and_grant_trait("juanwang", result)

	# 速通达人：任一专业技能0→5在≤4周内
	if not has_trait("speedrun"):
		for st in _skill_first_learn_week:
			var start_week: int = _skill_first_learn_week[st]
			if skills[st] >= 5 and week - start_week <= 4:
				_speedrun_skill = st
				_check_and_grant_trait("speedrun", result)
				break

	# 多面手：3个不同专业技能≥3
	if not has_trait("duomian"):
		var count := 0
		for st in GameData.get_all_skill_types():
			if skills[st] >= 3:
				count += 1
		if count >= 3:
			_check_and_grant_trait("duomian", result)

	# 面霸：累计通过3次面试
	if not has_trait("mianba") and _interview_pass_count >= 3:
		_check_and_grant_trait("mianba", result)

	# 海王：累计2周使用海投
	if not has_trait("haiwang") and _mass_apply_weeks >= 2:
		_check_and_grant_trait("haiwang", result)

	# 细水长流：连续4周>$3,000
	if not has_trait("conservative") and _cash_above_3000_weeks >= 4:
		_check_and_grant_trait("conservative", result)

	# 斜杠青年：累计零工/外包≥8次
	if not has_trait("slasher") and _total_gig_count >= 8:
		_check_and_grant_trait("slasher", result)

	# 背水一战：现金<$500（条件特质）
	if not has_trait("desperate") and cash < 500 and cash >= 0:
		_check_and_grant_trait("desperate", result)
	elif has_trait("desperate") and cash > 1500:
		active_traits.erase("desperate")
		result.lost_traits.append("desperate")

	# 社牛：人际关系≥7
	if not has_trait("social_butterfly") and networking_points >= 7:
		_check_and_grant_trait("social_butterfly", result)

	# 圈内人：内推获面试≥2次
	if not has_trait("insider") and _referral_interview_count >= 2:
		_check_and_grant_trait("insider", result)

	# 外包达人：累计完成5次外包
	if not has_trait("outsource_pro") and outsource_count >= 5:
		_check_and_grant_trait("outsource_pro", result)


func _check_and_grant_trait(trait_id: String, result: WeekSettlement) -> void:
	if has_trait(trait_id):
		return
	active_traits.append(trait_id)
	result.new_traits.append(trait_id)


func _track_skill_start(skill_type: GameData.SkillType) -> void:
	if not _skill_first_learn_week.has(skill_type):
		if skills[skill_type] == 0:
			_skill_first_learn_week[skill_type] = week


func get_trait_progress(trait_id: String) -> String:
	match trait_id:
		"juanwang":
			return "连续学习周数：%d/3" % _study_streak_weeks
		"speedrun":
			return "（需在4周内将专业技能0→5）"
		"duomian":
			var count := 0
			for st in GameData.get_all_skill_types():
				if skills[st] >= 3:
					count += 1
			return "专业技能≥3的数量：%d/3" % count
		"mianba":
			return "面试通过：%d/3" % _interview_pass_count
		"haiwang":
			return "使用海投周数：%d/2" % _mass_apply_weeks
		"negotiator":
			if _has_rejected_offer:
				return "已拒绝Offer（最高$%d/周），等待更高薪Offer" % _highest_rejected_salary
			return "尚未拒绝过Offer"
		"conservative":
			return "连续>$3,000周数：%d/4" % _cash_above_3000_weeks
		"slasher":
			return "零工/外包次数：%d/8" % _total_gig_count
		"desperate":
			return "现金：$%d（<$500触发）" % cash
		"social_butterfly":
			return "人际关系：%d/7" % mini(networking_points, 7)
		"insider":
			return "内推面试：%d/2" % _referral_interview_count
		"outsource_pro":
			return "外包完成：%d/5" % outsource_count
		_:
			return ""


# ══════════════════════════════════════════
#  通过率计算
# ══════════════════════════════════════════

## 简历通过率
func calc_resume_pass_rate(listing: GameData.JobListing, is_referral: bool = false) -> float:
	# 技能匹配基础分
	var skill_scores: Array[float] = []
	for req in listing.actual_skill_requirements:
		var player_lv: int = skills[req.skill]
		if resume_faked:
			player_lv += 1
		var score: float
		if player_lv >= req.level:
			score = 0.50 + (player_lv - req.level) * 0.05
		else:
			score = 0.50 - (req.level - player_lv) * 0.15
		skill_scores.append(score)

	var base_score := 0.0
	if skill_scores.size() == 1:
		base_score = skill_scores[0]
	elif skill_scores.size() >= 2:
		var total := 0.0
		for s in skill_scores:
			total += s
		base_score = total / skill_scores.size()

	# 通用技能检查
	if communication < listing.actual_comm_required:
		base_score *= 0.7

	# 加成
	var comm_bonus := communication * 0.02
	var network_bonus := networking_points * 0.03
	var work_exp_bonus := work_experience * 0.02
	var bigco_bonus := bigco_experience * 0.03
	var gap_penalty := 0.0
	if gap_time > 3:
		gap_penalty = (gap_time - 3) * 0.05
	var project_bonus := GameData.PERSONAL_PROJECT_RESUME_BONUS if personal_project_done else 0.0
	var template_bonus := 0.05 if has_tool("resume_template") else 0.0

	# 算法方向特色：大厂简历通过率+15%
	var algo_bigco_bonus := 0.0
	if starting_skill == GameData.SkillType.ALGORITHM \
			and listing.company_def.scale == GameData.CompanyScale.BIG:
		algo_bigco_bonus = GameData.SKILL_BONUS_ALGORITHM_BIGCO

	var rate := base_score + comm_bonus + network_bonus + work_exp_bonus \
		+ bigco_bonus - gap_penalty + project_bonus + template_bonus + algo_bigco_bonus

	# 内推加成
	if is_referral:
		var mult := GameData.REFERRAL_RESUME_MULT
		if has_trait("insider"):
			mult = 2.0
		rate *= mult

	return clampf(rate, 0.05, 0.95)


## 面试通过率
func calc_interview_pass_rate(listing: GameData.JobListing) -> float:
	var base_rate := 0.55

	# 技能加成
	var skill_bonus := 0.0
	var count := 0
	for req in listing.actual_skill_requirements:
		var player_lv: int = skills[req.skill]
		if resume_faked:
			player_lv += 1
		skill_bonus += (player_lv - req.level) * 0.08
		count += 1
	if count > 0:
		skill_bonus /= count

	var interview_bonus := interview_skill * 0.03
	var comm_bonus := communication * 0.02
	var work_exp_bonus := work_experience * 0.02
	var bigco_bonus := bigco_experience * 0.02
	var gap_penalty := 0.0
	if gap_time > 3:
		gap_penalty = (gap_time - 3) * 0.03
	var project_bonus := GameData.PERSONAL_PROJECT_INTERVIEW_BONUS if personal_project_done else 0.0

	# 工具/特质加成
	var tool_bonus := 0.0
	if has_tool("nice_shirt"):
		tool_bonus += 0.08
	if has_trait("mianba"):
		tool_bonus += 0.10
	if has_trait("social_butterfly"):
		tool_bonus += 0.05
	# 多面手: 中级岗位+10%
	if has_trait("duomian") and listing.job.tier == GameData.JobTier.MID:
		tool_bonus += 0.10
	# 政策利好
	if current_market_event != null and market_event_weeks_left > 0:
		if current_market_event.effect_tag == "policy_boost":
			tool_bonus += 0.15

	# 前端方向特色：面试通过率+8%
	var skill_dir_bonus := 0.0
	if starting_skill == GameData.SkillType.FRONTEND:
		skill_dir_bonus = GameData.SKILL_BONUS_FRONTEND_INTERVIEW

	var rate := base_rate + skill_bonus + interview_bonus + comm_bonus \
		+ work_exp_bonus + bigco_bonus - gap_penalty + project_bonus + tool_bonus \
		+ skill_dir_bonus

	return clampf(rate, 0.10, 0.90)


# ══════════════════════════════════════════
#  岗位生成
# ══════════════════════════════════════════

func _generate_all_company_listings() -> void:
	for company in companies:
		# 行业整顿: 暂停招聘
		if current_market_event != null and market_event_weeks_left > 0:
			if current_market_event.effect_tag == "industry_crackdown":
				continue

		# 计算当前岗位数
		var current_count := 0
		for listing in current_listings:
			if listing.company_def.id == company.id:
				current_count += 1

		var max_slots := company.job_slots_min + (randi() % (company.job_slots_max - company.job_slots_min + 1))
		var empty_slots := maxi(0, max_slots - current_count)

		# 计算生成概率
		var gen_chance := company.job_generate_chance
		# 风向修正
		if current_wind != null and wind_weeks_left > 0:
			for pref_skill in company.preferred_skills:
				if pref_skill == current_wind.target_skill:
					gen_chance += current_wind.gen_chance_modifier
					break
		# 经济不景气
		if current_market_event != null and market_event_weeks_left > 0:
			if current_market_event.effect_tag == "economy_down":
				gen_chance -= 0.20
		# 经营状况
		match company.business_status:
			GameData.BusinessStatus.GOOD:
				gen_chance += 0.05
			GameData.BusinessStatus.STRUGGLING:
				gen_chance -= 0.10
		gen_chance = clampf(gen_chance, 0.05, 0.95)

		for _i in range(empty_slots):
			if randf() < gen_chance:
				_create_listing_for_company(company)


func _create_listing_for_company(company: GameData.CompanyDef) -> void:
	# 决定职级（前半程偏初级，后半程偏高级）
	var tier_roll := randf()
	var tier: GameData.JobTier
	var junior_chance: float
	var mid_chance: float
	if week <= 6:
		junior_chance = GameData.TIER_CHANCE_JUNIOR_EARLY
		mid_chance = GameData.TIER_CHANCE_MID_EARLY
	else:
		junior_chance = GameData.TIER_CHANCE_JUNIOR_LATE
		mid_chance = GameData.TIER_CHANCE_MID_LATE
	if tier_roll < junior_chance:
		tier = GameData.JobTier.JUNIOR
	elif tier_roll < junior_chance + mid_chance:
		tier = GameData.JobTier.MID
	else:
		tier = GameData.JobTier.SENIOR

	# 从公司倾向技能匹配的岗位中随机选一个
	var matching := GameData.get_matching_jobs(company.preferred_skills, tier)
	if matching.is_empty():
		# 降级尝试
		if tier == GameData.JobTier.SENIOR:
			matching = GameData.get_matching_jobs(company.preferred_skills, GameData.JobTier.MID)
		if matching.is_empty():
			matching = GameData.get_matching_jobs(company.preferred_skills, GameData.JobTier.JUNIOR)
	if matching.is_empty():
		return

	var job: GameData.JobDef = matching[randi() % matching.size()]
	_listing_counter += 1
	var listing_id := "%s_%s_%d" % [company.id, job.id, _listing_counter]

	# 随机化薪资
	var salary_mult := company.get_salary_multiplier()
	var actual_salary := roundi(job.base_salary * salary_mult * randf_range(0.9, 1.1) / 10.0) * 10
	# 后端方向特色：后端相关岗位薪资+10%
	if starting_skill == GameData.SkillType.BACKEND:
		for req in job.skill_requirements:
			if req.skill == GameData.SkillType.BACKEND:
				actual_salary = roundi(actual_salary * (1.0 + GameData.SKILL_BONUS_BACKEND_SALARY) / 10.0) * 10
				break

	# 随机化技能需求 (±1 变动，但不低于原始-1，不高于原始+1)
	var actual_reqs: Array = []
	for req in job.skill_requirements:
		var variance := (randi() % 3) - 1  # -1, 0, +1
		var actual_level := maxi(1, req.level + variance)
		actual_reqs.append(GameData.SkillRequirement.new(req.skill, actual_level))

	# 沟通要求随机化
	var comm_variance := (randi() % 3) - 1
	var actual_comm := maxi(0, job.communication_required + comm_variance)

	current_listings.append(GameData.JobListing.new(
		listing_id, job, company, actual_salary, actual_reqs, actual_comm))


func _pick_referral_listing() -> GameData.JobListing:
	var eligible: Array[GameData.JobListing] = []
	for listing in current_listings:
		if applications.has(listing.listing_id):
			continue
		eligible.append(listing)
	if eligible.is_empty():
		return null

	# 尝试匹配玩家最高技能
	var best_skill: GameData.SkillType = GameData.SkillType.BACKEND
	var best_level := 0
	for st in GameData.get_all_skill_types():
		if skills[st] > best_level:
			best_level = skills[st]
			best_skill = st

	var preferred: Array[GameData.JobListing] = []
	for l in eligible:
		for req in l.actual_skill_requirements:
			if req.skill == best_skill:
				preferred.append(l)
				break

	# 海王特质: 至少1个匹配最高技能方向
	if not preferred.is_empty():
		return preferred[randi() % preferred.size()]
	return eligible[randi() % eligible.size()]


# ══════════════════════════════════════════
#  结局系统
# ══════════════════════════════════════════

## 计算预估年收入
func calc_projected_income() -> int:
	if current_job_listing:
		return (current_job_listing.actual_salary - GameData.WEEKLY_LIVING_COST) * 52 + cash
	# 检查是否有Offer
	var best_offer_salary := 0
	for listing_id in applications:
		var app: GameData.JobApplication = applications[listing_id]
		if app.status == GameData.ApplicationStatus.OFFER:
			if app.listing.actual_salary > best_offer_salary:
				best_offer_salary = app.listing.actual_salary
	if best_offer_salary > 0:
		return (best_offer_salary - GameData.WEEKLY_LIVING_COST) * 50 + cash
	# 无工作无Offer
	var projected := cash - GameData.WEEKLY_LIVING_COST * 12
	return maxi(0, projected)


func get_ending() -> GameData.EndingRank:
	if cash < 0:
		return GameData.EndingRank.F
	return GameData.get_ending_rank(calc_projected_income(), false)


# ══════════════════════════════════════════
#  UI查询方法
# ══════════════════════════════════════════

func get_wind_text() -> String:
	if current_wind != null and wind_weeks_left > 0:
		return "%s（剩%d周）" % [current_wind.name, wind_weeks_left]
	return ""

func get_market_event_text() -> String:
	if current_market_event != null and market_event_weeks_left > 0:
		return "%s（剩%d周）" % [current_market_event.name, market_event_weeks_left]
	return ""

func find_company(company_id: String) -> GameData.CompanyDef:
	for c in companies:
		if c.id == company_id:
			return c
	return null

func get_company_listing_count(company_id: String) -> int:
	var count := 0
	for listing in current_listings:
		if listing.company_def.id == company_id:
			count += 1
	return count

func _find_listing(listing_id: String) -> GameData.JobListing:
	for listing in current_listings:
		if listing.listing_id == listing_id:
			return listing
	if applications.has(listing_id):
		return (applications[listing_id] as GameData.JobApplication).listing
	return null

func get_max_professional_skill() -> int:
	var max_lv := 0
	for st in GameData.get_all_skill_types():
		if skills[st] > max_lv:
			max_lv = skills[st]
	return max_lv

## 是否可以做个人作品
func can_do_personal_project() -> bool:
	if personal_project_done:
		return false
	if _personal_project_work_this_week >= GameData.PERSONAL_PROJECT_MAX_PER_WEEK:
		return false
	for st in GameData.get_all_skill_types():
		if skills[st] >= GameData.PERSONAL_PROJECT_MIN_SKILL:
			return true
	return false

## 是否有外包可接
func has_outsource_available() -> bool:
	return current_outsource != null

## 获取外包信息文本
func get_outsource_info() -> String:
	if current_outsource == null:
		return ""
	return "%s（%s，%dEP→$%d）" % [
		current_outsource.get_level_text(),
		GameData.get_skill_name(current_outsource.required_skill),
		current_outsource.energy_cost,
		current_outsource.income]
