## 游戏状态管理 - 核心逻辑
class_name GameState
extends RefCounted

# ── 玩家状态 ──
var week: int = 1
var cash: int = GameData.INITIAL_CASH
var energy: int = GameData.ENERGY_PER_WEEK
var skills: Dictionary = {
	GameData.SkillType.SYSTEM: 0,
	GameData.SkillType.APPLICATION: 0,
	GameData.SkillType.INTERVIEW: 0,
	GameData.SkillType.ENGLISH: 0,
	GameData.SkillType.CPP: 0,
}
var skill_xp: Dictionary = {
	GameData.SkillType.SYSTEM: 0,
	GameData.SkillType.APPLICATION: 0,
	GameData.SkillType.INTERVIEW: 0,
	GameData.SkillType.ENGLISH: 0,
	GameData.SkillType.CPP: 0,
}

# ── 工作状态 ──
var current_job: GameData.JobDef = null
var pending_quit: bool = false

# ── 求职进度：listing_id -> JobApplication ──
var applications: Dictionary = {}

# ── 岗位市场 ──
var current_listings: Array[GameData.JobListing] = []
var market_bias: GameData.MarketBias = GameData.MarketBias.BALANCED

var _all_jobs: Array[GameData.JobDef]
var _listing_counter: int = 0
var _applied_this_week: Array[String] = []
var _interviewed_this_week: Array[String] = []

# ── 面试反馈文案 ──
const _RESUME_GHOST := [
	"（%s 看了眼你的简历，然后沉默了。）",
	"（简历石沉大海，%s 从此杳无音讯。）",
	"（%s 把你的简历移入了回收站，但没有清空。）",
	"（%s 的 HR 可能还没上班。）",
]
const _RESUME_OVERQUALIFIED := [
	"感谢申请，您的背景过于优秀，我们担心您很快就会离职。",
	"您的资历超出了我们的预期范围，此次遗憾。",
	"您 over-qualified，%s 有些担心留不住您。",
	"技术很好，但我们更需要能长期留下来的人。",
]
const _RESUME_UNDERQUALIFIED := [
	"综合评估后，您的技能暂时与岗位需求有差距，感谢投递。",
	"经过仔细阅读，%s 决定暂不推进，欢迎您提升后再来。",
	"您的申请我们已收到，但目前的匹配度不符合要求。",
]
const _INTERVIEW_VIBE := [
	"说不出哪儿不好，就是感觉不太对。",
	"面试官觉得您与团队文化契合度有些担忧。",
	"双方聊得有点不在一个频道，最终没有推进。",
	"技术没问题，但沟通风格让面试官有些顾虑。",
	"面试官今天心情不太好，您也是受害者。",
	"气场不合，面试官说不清楚，就是感觉不对。",
]
const _INTERVIEW_COMPETITION := [
	"虽然您表现出色，但此次竞争激烈，遗憾落选。",
	"您是优秀的候选人，但有人比您更符合当前需求。",
	"HC 有限，最终选了另一位候选人，非常抱歉。",
	"虽然您很好，但对方的背景恰好更贴合这个岗位。",
	"感谢参加面试，此次与您无缘，期待下次合作。",
]


func _init() -> void:
	_all_jobs = GameData.get_all_jobs()
	_refresh_job_market()


# ════════════════════════════════════════
#  能量与行动
# ════════════════════════════════════════

func get_free_energy() -> int:
	var locked := 0
	if current_job:
		locked = current_job.energy_cost
	return energy - locked


func get_skill(skill_type: GameData.SkillType) -> int:
	return skills[skill_type]


## 学习技能（每次 1 能量 +1 XP；XP满自动升级）
func action_study(skill_type: GameData.SkillType) -> bool:
	var current_level: int = skills[skill_type]
	if current_level >= GameData.MAX_SKILL_LEVEL:
		return false
	if get_free_energy() < 1:
		return false
	energy -= 1
	skill_xp[skill_type] += 1
	var needed: int = GameData.xp_needed_for_level(current_level + 1)
	if skill_xp[skill_type] >= needed:
		skills[skill_type] = current_level + 1
		skill_xp[skill_type] = 0
	return true


## 获取技能升级进度，如 "2/3"；满级返回 "MAX"
func get_skill_xp_progress(skill_type: GameData.SkillType) -> String:
	var lv: int = skills[skill_type]
	if lv >= GameData.MAX_SKILL_LEVEL:
		return "MAX"
	var needed: int = GameData.xp_needed_for_level(lv + 1)
	return "%d/%d" % [skill_xp[skill_type], needed]


## 兼职零工
func action_gig_parttime() -> bool:
	if get_free_energy() < GameData.GIG_ENERGY_PARTTIME:
		return false
	energy -= GameData.GIG_ENERGY_PARTTIME
	cash += GameData.GIG_INCOME_PARTTIME
	return true


## 全职零工
func action_gig_fulltime() -> bool:
	if get_free_energy() < GameData.GIG_ENERGY_FULLTIME:
		return false
	energy -= GameData.GIG_ENERGY_FULLTIME
	cash += GameData.GIG_INCOME_FULLTIME
	return true


## 批量投递（1能量，1-3个listing_id；超过1个时有惩罚）
func action_apply_batch(listing_ids: Array[String]) -> bool:
	if listing_ids.is_empty() or get_free_energy() < 1:
		return false

	var count := listing_ids.size()
	var penalty := 1.0
	if count == 2:
		penalty = GameData.BATCH_PENALTY_2
	elif count >= 3:
		penalty = GameData.BATCH_PENALTY_3

	var applied_any := false
	for listing_id in listing_ids:
		var listing := _find_listing(listing_id)
		if listing == null:
			continue
		if applications.has(listing_id):
			var app: GameData.JobApplication = applications[listing_id]
			if app.status != GameData.ApplicationStatus.NONE and \
					app.status != GameData.ApplicationStatus.REJECTED:
				continue
		var new_app := GameData.JobApplication.new(listing, penalty)
		applications[listing_id] = new_app
		_applied_this_week.append(listing_id)
		applied_any = true

	if applied_any:
		energy -= 1
	return applied_any


## 参加面试
func action_interview(listing_id: String) -> bool:
	if get_free_energy() < 2:
		return false
	if not applications.has(listing_id):
		return false
	var app: GameData.JobApplication = applications[listing_id]
	if app.status != GameData.ApplicationStatus.HAS_INTERVIEW:
		return false
	energy -= 2
	app.status = GameData.ApplicationStatus.INTERVIEWED
	_interviewed_this_week.append(listing_id)
	return true


## 接受 Offer
func action_accept_offer(listing_id: String) -> bool:
	if not applications.has(listing_id):
		return false
	var app: GameData.JobApplication = applications[listing_id]
	if app.status != GameData.ApplicationStatus.OFFER:
		return false
	current_job = app.listing.job
	pending_quit = false
	applications.erase(listing_id)
	return true


## 拒绝 Offer
func action_reject_offer(listing_id: String) -> bool:
	if not applications.has(listing_id):
		return false
	var app: GameData.JobApplication = applications[listing_id]
	if app.status != GameData.ApplicationStatus.OFFER:
		return false
	applications.erase(listing_id)
	return true


## 辞职（下周生效）
func action_quit() -> bool:
	if current_job == null:
		return false
	pending_quit = true
	return true


# ════════════════════════════════════════
#  周结算
# ════════════════════════════════════════

class WeekSettlement:
	var salary_earned: int = 0
	var living_cost: int = GameData.WEEKLY_LIVING_COST
	var cash_before: int = 0
	var cash_after: int = 0
	var notifications: Array[String] = []
	var expired_offers: Array[String] = []
	var is_game_over: bool = false
	var did_quit: bool = false
	var market_refreshed: bool = false
	var new_market_bias: GameData.MarketBias = GameData.MarketBias.BALANCED


func settle_week() -> WeekSettlement:
	var result := WeekSettlement.new()
	result.cash_before = cash

	# 1. 发工资
	if current_job:
		result.salary_earned = current_job.weekly_salary
		cash += result.salary_earned

	# 2. 扣生活费
	cash -= GameData.WEEKLY_LIVING_COST

	# 3. 处理简历结果
	for listing_id in _applied_this_week:
		if not applications.has(listing_id):
			continue
		var app: GameData.JobApplication = applications[listing_id]
		if app.status != GameData.ApplicationStatus.APPLIED:
			continue
		var job := app.listing.job
		var company := app.listing.company

		# 10% 概率被鬼了（公司不回应）
		if randf() < 0.10:
			app.status = GameData.ApplicationStatus.REJECTED
			var msg := _RESUME_GHOST[randi() % _RESUME_GHOST.size()]
			result.notifications.append("%s [%s]：%s" % [job.title, company, msg % company])
			continue

		var pass_rate := _calc_resume_pass_rate(job, app.apply_penalty)
		if randf() < pass_rate:
			app.status = GameData.ApplicationStatus.HAS_INTERVIEW
			result.notifications.append("%s [%s]：简历通过！已安排面试。" % [job.title, company])
		else:
			app.status = GameData.ApplicationStatus.REJECTED
			var primary_diff := skills[job.skill_type] - job.skill_required
			var msg: String
			if primary_diff >= 5:
				var tpl := _RESUME_OVERQUALIFIED[randi() % _RESUME_OVERQUALIFIED.size()]
				msg = tpl % company if "%s" in tpl else tpl
			else:
				var tpl := _RESUME_UNDERQUALIFIED[randi() % _RESUME_UNDERQUALIFIED.size()]
				msg = tpl % company if "%s" in tpl else tpl
			result.notifications.append("%s [%s]：%s" % [job.title, company, msg])

	# 4. 处理面试结果（两段式判定）
	for listing_id in _interviewed_this_week:
		if not applications.has(listing_id):
			continue
		var app: GameData.JobApplication = applications[listing_id]
		if app.status != GameData.ApplicationStatus.INTERVIEWED:
			continue
		var job := app.listing.job
		var company := app.listing.company

		# 第二层：面试官好感（面试技巧 + 随机）
		var interview_skill: int = skills[GameData.SkillType.INTERVIEW]
		var vibe_rate := clampf(0.40 + interview_skill * 0.05, 0.10, 0.90)
		var vibe_pass := randf() < vibe_rate

		# 第三层：竞争（纯随机，随岗位层级递增）
		var comp_rate := 0.65
		if job.skill_required >= 8:
			comp_rate = 0.40
		elif job.skill_required >= 5:
			comp_rate = 0.55
		var comp_pass := randf() < comp_rate

		if vibe_pass and comp_pass:
			app.status = GameData.ApplicationStatus.OFFER
			app.offer_weeks_left = GameData.OFFER_VALIDITY_WEEKS
			result.notifications.append(
				"恭喜！%s [%s] 向您发出了 Offer！（周薪 $%d，%d 周内有效）" % [
					job.title, company, job.weekly_salary, app.offer_weeks_left])
		elif not vibe_pass:
			app.status = GameData.ApplicationStatus.REJECTED
			var msg := _INTERVIEW_VIBE[randi() % _INTERVIEW_VIBE.size()]
			result.notifications.append("%s [%s]：%s" % [job.title, company, msg])
		else:
			app.status = GameData.ApplicationStatus.REJECTED
			var msg := _INTERVIEW_COMPETITION[randi() % _INTERVIEW_COMPETITION.size()]
			result.notifications.append("%s [%s]：%s" % [job.title, company, msg])

	# 5. Offer 有效期 -1
	var to_expire: Array[String] = []
	for listing_id in applications:
		var app: GameData.JobApplication = applications[listing_id]
		if app.status == GameData.ApplicationStatus.OFFER:
			app.offer_weeks_left -= 1
			if app.offer_weeks_left <= 0:
				to_expire.append(listing_id)
				result.expired_offers.append("%s [%s]" % [app.listing.job.title, app.listing.company])
	for listing_id in to_expire:
		applications.erase(listing_id)

	# 6. 处理辞职
	if pending_quit:
		result.did_quit = true
		result.notifications.append("你已离职：%s" % current_job.title)
		current_job = null
		pending_quit = false

	result.cash_after = cash

	# 7. 判断 Game Over
	if cash < 0:
		result.is_game_over = true

	# 8. 推进到下一周 & 重置能量
	week += 1
	energy = GameData.ENERGY_PER_WEEK
	_applied_this_week.clear()
	_interviewed_this_week.clear()

	# 9. 检查市场刷新
	if week in GameData.MARKET_REFRESH_WEEKS and week != 1:
		_refresh_job_market()
		result.market_refreshed = true
		result.new_market_bias = market_bias

	return result


# ════════════════════════════════════════
#  结局判定
# ════════════════════════════════════════

enum Ending { GAME_OVER, STRUGGLING, STABLE, SUCCESS }

func get_ending() -> Ending:
	if cash < 0:
		return Ending.GAME_OVER
	for listing_id in applications:
		var app: GameData.JobApplication = applications[listing_id]
		if app.status == GameData.ApplicationStatus.OFFER:
			if app.listing.job.skill_required >= 8:
				return Ending.SUCCESS
	if current_job:
		if current_job.skill_required >= 8:
			return Ending.SUCCESS
		elif current_job.skill_required >= 5:
			return Ending.STABLE
		else:
			return Ending.STRUGGLING
	return Ending.STRUGGLING


func get_ending_text(ending: Ending) -> Dictionary:
	match ending:
		Ending.SUCCESS:
			return {"title": "上岸成功", "desc": "你终于拿到了理想的工作。"}
		Ending.STABLE:
			return {"title": "站稳脚跟", "desc": "不算完美，但你活下来了。"}
		Ending.STRUGGLING:
			return {"title": "艰难求生", "desc": "还在挣扎，但没有放弃。"}
		_:
			return {"title": "Game Over", "desc": "你的积蓄耗尽了……"}


# ════════════════════════════════════════
#  市场刷新
# ════════════════════════════════════════

func _refresh_job_market() -> void:
	var bias_roll := randi() % 3
	market_bias = bias_roll as GameData.MarketBias

	var system_count := 2
	var app_count := 3
	match market_bias:
		GameData.MarketBias.SYSTEM_HEAVY:
			system_count = 3
			app_count = 2
		GameData.MarketBias.APP_HEAVY:
			system_count = 2
			app_count = 3
		_:
			system_count = 2 + (randi() % 2)
			app_count = GameData.LISTINGS_PER_REFRESH - system_count

	var system_jobs: Array[GameData.JobDef] = []
	var app_jobs: Array[GameData.JobDef] = []
	for job in _all_jobs:
		if job.skill_type == GameData.SkillType.SYSTEM:
			system_jobs.append(job)
		elif job.skill_type == GameData.SkillType.APPLICATION:
			app_jobs.append(job)

	current_listings.clear()
	_generate_listings(system_jobs, system_count)
	_generate_listings(app_jobs, app_count)


func _generate_listings(job_pool: Array[GameData.JobDef], count: int) -> void:
	var weights := [50, 35, 15]
	for _i in range(count):
		var job := _weighted_pick(job_pool, weights)
		var company := GameData.COMPANIES[randi() % GameData.COMPANIES.size()]
		_listing_counter += 1
		var listing_id := "%s_%d" % [job.id, _listing_counter]
		current_listings.append(GameData.JobListing.new(listing_id, job, company))


func _weighted_pick(pool: Array[GameData.JobDef], weights: Array) -> GameData.JobDef:
	var total := 0
	for w in weights:
		total += w
	var roll := randi() % total
	var cumulative := 0
	for i in range(pool.size()):
		cumulative += weights[mini(i, weights.size() - 1)]
		if roll < cumulative:
			return pool[i]
	return pool[pool.size() - 1]


# ════════════════════════════════════════
#  简历匹配率计算
# ════════════════════════════════════════

## 计算简历通过概率（不含鬼处理）
## 主技能：差值 0~+4 为峰值区，+5以上 over-qualified，负数快速下降
## 英语：所有岗位均影响；C++：仅系统方向岗位影响
func _calc_resume_pass_rate(job: GameData.JobDef, penalty: float) -> float:
	var base := 0.55

	# 主技能修正
	var diff := skills[job.skill_type] - job.skill_required
	var primary_mod: float
	if diff >= 5:
		primary_mod = maxf(0.16 - (diff - 4) * 0.08, -0.20)  # 超过+4开始惩罚
	elif diff >= 0:
		primary_mod = diff * 0.04  # +4% 每级，峰值 +16%
	elif diff == -1:
		primary_mod = -0.15
	elif diff == -2:
		primary_mod = -0.30
	else:
		primary_mod = maxf(-0.30 - (absf(diff) - 2) * 0.10, -0.50)

	# 英语修正（所有岗位）
	var eng_diff := skills[GameData.SkillType.ENGLISH] - job.english_required
	var english_mod := clampf(eng_diff * 0.04, -0.12, 0.08)

	# C++ 修正（仅系统方向）
	var cpp_mod := 0.0
	if job.skill_type == GameData.SkillType.SYSTEM and job.cpp_required > 0:
		var cpp_diff := skills[GameData.SkillType.CPP] - job.cpp_required
		cpp_mod = clampf(cpp_diff * 0.04, -0.12, 0.08)

	return clampf((base + primary_mod + english_mod + cpp_mod) * penalty, 0.05, 0.88)


# ════════════════════════════════════════
#  内部工具
# ════════════════════════════════════════

func _find_listing(listing_id: String) -> GameData.JobListing:
	for listing in current_listings:
		if listing.listing_id == listing_id:
			return listing
	if applications.has(listing_id):
		return applications[listing_id].listing
	return null


func get_market_bias_text() -> String:
	match market_bias:
		GameData.MarketBias.SYSTEM_HEAVY:
			return "系统/后端需求旺盛"
		GameData.MarketBias.APP_HEAVY:
			return "前端/应用需求旺盛"
		_:
			return "市场需求均衡"
