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
}
var skill_xp: Dictionary = {
	GameData.SkillType.SYSTEM: 0,
	GameData.SkillType.APPLICATION: 0,
	GameData.SkillType.INTERVIEW: 0,
}

# ── 工作状态 ──
var current_job: GameData.JobDef = null  # 当前在职岗位
var pending_quit: bool = false            # 是否已提交辞职（下周生效）

# ── 求职进度：listing_id -> JobApplication ──
var applications: Dictionary = {}

# ── 岗位市场 ──
var current_listings: Array[GameData.JobListing] = []
var market_bias: GameData.MarketBias = GameData.MarketBias.BALANCED

# ── 所有岗位模板引用 ──
var _all_jobs: Array[GameData.JobDef]
var _listing_counter: int = 0

# ── 本周行动记录（用于结算通知） ──
var _applied_this_week: Array[String] = []    # listing_ids
var _interviewed_this_week: Array[String] = []  # listing_ids


func _init() -> void:
	_all_jobs = GameData.get_all_jobs()
	_refresh_job_market()  # 第1周市场初始化


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


## 学习技能（每次 1 能量 +1 XP；升到第 N 级需 ceil(N/2) XP）
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


## 获取技能升级进度字符串，如 "2/3"；满级返回 "MAX"
func get_skill_xp_progress(skill_type: GameData.SkillType) -> String:
	var lv: int = skills[skill_type]
	if lv >= GameData.MAX_SKILL_LEVEL:
		return "MAX"
	var needed: int = GameData.xp_needed_for_level(lv + 1)
	return "%d/%d" % [skill_xp[skill_type], needed]


## 兼职零工（消耗 3 能量，获得 $280）
func action_gig_parttime() -> bool:
	if get_free_energy() < GameData.GIG_ENERGY_PARTTIME:
		return false
	energy -= GameData.GIG_ENERGY_PARTTIME
	cash += GameData.GIG_INCOME_PARTTIME
	return true


## 全职零工（消耗 5 能量，获得 $520）
func action_gig_fulltime() -> bool:
	if get_free_energy() < GameData.GIG_ENERGY_FULLTIME:
		return false
	energy -= GameData.GIG_ENERGY_FULLTIME
	cash += GameData.GIG_INCOME_FULLTIME
	return true


## 投递简历（传入 listing_id）
func action_apply(listing_id: String) -> bool:
	if get_free_energy() < 1:
		return false
	var listing := _find_listing(listing_id)
	if listing == null:
		return false
	# 检查是否已有进行中的申请
	if applications.has(listing_id):
		var app: GameData.JobApplication = applications[listing_id]
		if app.status != GameData.ApplicationStatus.NONE and \
				app.status != GameData.ApplicationStatus.REJECTED:
			return false
	energy -= 1
	var new_app := GameData.JobApplication.new(listing)
	applications[listing_id] = new_app
	_applied_this_week.append(listing_id)
	return true


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

	# 3. 处理求职通知
	for listing_id in _applied_this_week:
		if not applications.has(listing_id):
			continue
		var app: GameData.JobApplication = applications[listing_id]
		if app.status != GameData.ApplicationStatus.APPLIED:
			continue
		var job := app.listing.job
		var player_skill: int = skills[job.skill_type]
		if player_skill >= job.skill_required:
			app.status = GameData.ApplicationStatus.HAS_INTERVIEW
			result.notifications.append("%s [%s]：简历通过，获得面试机会！" % [job.title, app.listing.company])
		else:
			app.status = GameData.ApplicationStatus.REJECTED
			result.notifications.append("%s [%s]：很遗憾，简历未通过筛选。" % [job.title, app.listing.company])

	for listing_id in _interviewed_this_week:
		if not applications.has(listing_id):
			continue
		var app: GameData.JobApplication = applications[listing_id]
		if app.status != GameData.ApplicationStatus.INTERVIEWED:
			continue
		var pass_rate := _calc_interview_pass_rate(app.listing.job)
		if randf() <= pass_rate:
			app.status = GameData.ApplicationStatus.OFFER
			app.offer_weeks_left = GameData.OFFER_VALIDITY_WEEKS
			result.notifications.append("%s [%s]：面试通过，获得 Offer！（%d 周内有效）" % [
				app.listing.job.title, app.listing.company, app.offer_weeks_left])
		else:
			app.status = GameData.ApplicationStatus.REJECTED
			result.notifications.append("%s [%s]：面试未通过。" % [app.listing.job.title, app.listing.company])

	# 4. Offer 有效期 -1
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

	# 5. 处理辞职
	if pending_quit:
		result.did_quit = true
		result.notifications.append("你已离职：%s" % current_job.title)
		current_job = null
		pending_quit = false

	result.cash_after = cash

	# 6. 判断 Game Over
	if cash < 0:
		result.is_game_over = true

	# 7. 推进到下一周 & 重置能量
	week += 1
	energy = GameData.ENERGY_PER_WEEK
	_applied_this_week.clear()
	_interviewed_this_week.clear()

	# 8. 检查是否需要刷新岗位市场
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
	# 随机选市场偏向
	var bias_roll := randi() % 3
	market_bias = bias_roll as GameData.MarketBias

	# 按偏向决定系统/应用岗位数量
	var system_count: int
	var app_count: int
	match market_bias:
		GameData.MarketBias.SYSTEM_HEAVY:
			system_count = 3
			app_count = 2
		GameData.MarketBias.APP_HEAVY:
			system_count = 2
			app_count = 3
		_:  # BALANCED
			system_count = 2
			app_count = 3
			if randi() % 2 == 0:
				system_count = 3
				app_count = 2

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
	# 权重：低级 50%，中级 35%，高级 15%
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
#  内部工具
# ════════════════════════════════════════

func _find_listing(listing_id: String) -> GameData.JobListing:
	for listing in current_listings:
		if listing.listing_id == listing_id:
			return listing
	# 也检查进行中的申请（市场刷新后仍可操作）
	if applications.has(listing_id):
		return applications[listing_id].listing
	return null


func _calc_interview_pass_rate(job: GameData.JobDef) -> float:
	var player_skill: int = skills[job.skill_type]
	var interview_skill: int = skills[GameData.SkillType.INTERVIEW]
	var rate := 0.35 + (player_skill - job.skill_required) * 0.08 + interview_skill * 0.02
	return clampf(rate, 0.2, 0.95)


func get_market_bias_text() -> String:
	match market_bias:
		GameData.MarketBias.SYSTEM_HEAVY:
			return "系统/后端需求旺盛"
		GameData.MarketBias.APP_HEAVY:
			return "前端/应用需求旺盛"
		_:
			return "市场需求均衡"
