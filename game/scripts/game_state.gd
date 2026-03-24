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

# ── 人脉与作品集 ──
var networking_points: int = 0
var portfolio_system: int = 0
var portfolio_application: int = 0

# ── 工作状态 ──
var current_job_listing: GameData.JobListing = null
var pending_quit: bool = false

# ── 求职进度：listing_id -> JobApplication ──
var applications: Dictionary = {}

# ── 岗位市场 ──
var current_listings: Array[GameData.JobListing] = []
var market_bias: GameData.MarketBias = GameData.MarketBias.BALANCED

# ── 市场寒冬 ──
var market_downturn_weeks_left: int = 0
var _downturn_triggered: bool = false

# ── 周效果 ──
var double_xp_this_week: bool = false
var _double_xp_next_week: bool = false
var _energy_modifier_next_week: int = 0

var _all_jobs: Array[GameData.JobDef]
var _listing_counter: int = 0
var _applied_this_week: Array[String] = []
var _interviewed_this_week: Array[String] = []
var _pending_referrals: Array[String] = []

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
const _PORTFOLIO_BACKFIRE := [
	"被追问项目细节时答不上来，面试官神色有些疑虑……",
	"展示作品集时被问及实现细节，一时语塞，场面略显尴尬。",
	"作品集引起了面试官兴趣，但深入一问，暴露了技术短板。",
]


func _init() -> void:
	_all_jobs = GameData.get_all_jobs()
	_refresh_job_market()


# ════════════════════════════════════════
#  能量与行动
# ════════════════════════════════════════

func get_free_energy() -> int:
	var locked := 0
	if current_job_listing:
		locked = current_job_listing.job.energy_cost
	return energy - locked


func get_skill(skill_type: GameData.SkillType) -> int:
	return skills[skill_type]


## 学习技能（每次 1 能量 +1 XP；XP满自动升级；灵感爆发时 XP ×2）
func action_study(skill_type: GameData.SkillType) -> bool:
	var current_level: int = skills[skill_type]
	if current_level >= GameData.MAX_SKILL_LEVEL:
		return false
	if get_free_energy() < 1:
		return false
	energy -= 1
	var xp_gain := 2 if double_xp_this_week else 1
	skill_xp[skill_type] = (skill_xp[skill_type] as int) + xp_gain
	var needed: int = GameData.xp_needed_for_level(current_level + 1)
	if (skill_xp[skill_type] as int) >= needed:
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


## 兼职零工（寒冬期收入 -10%）
func action_gig_parttime() -> bool:
	if get_free_energy() < GameData.GIG_ENERGY_PARTTIME:
		return false
	energy -= GameData.GIG_ENERGY_PARTTIME
	var income := GameData.GIG_INCOME_PARTTIME
	if market_downturn_weeks_left > 0:
		income = int(income * 0.90)
	cash += income
	return true


## 全职零工（寒冬期收入 -10%）
func action_gig_fulltime() -> bool:
	if get_free_energy() < GameData.GIG_ENERGY_FULLTIME:
		return false
	energy -= GameData.GIG_ENERGY_FULLTIME
	var income := GameData.GIG_INCOME_FULLTIME
	if market_downturn_weeks_left > 0:
		income = int(income * 0.90)
	cash += income
	return true


## 维护人脉（1 能量，人脉 +1，上限 10）
func action_networking() -> bool:
	if get_free_energy() < 1:
		return false
	if networking_points >= GameData.MAX_NETWORKING_POINTS:
		return false
	energy -= 1
	networking_points += 1
	return true


## 做个人项目（3 能量，对应方向作品集 +1，上限 3）
func action_portfolio(skill_type: GameData.SkillType) -> bool:
	if get_free_energy() < GameData.PORTFOLIO_ENERGY_COST:
		return false
	if skill_type == GameData.SkillType.SYSTEM:
		if portfolio_system >= GameData.MAX_PORTFOLIO_POINTS:
			return false
		portfolio_system += 1
	else:
		if portfolio_application >= GameData.MAX_PORTFOLIO_POINTS:
			return false
		portfolio_application += 1
	energy -= GameData.PORTFOLIO_ENERGY_COST
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
	current_job_listing = app.listing
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
	if current_job_listing == null:
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
	var event_name: String = ""
	var event_desc: String = ""
	var market_downturn_started: bool = false
	var market_downturn_ended: bool = false


func settle_week() -> WeekSettlement:
	var result := WeekSettlement.new()
	result.cash_before = cash

	# 0. 将上周内推移入本周简历处理列表
	for ref_id in _pending_referrals:
		if not _applied_this_week.has(ref_id):
			_applied_this_week.append(ref_id)
	_pending_referrals.clear()

	# 1. 发工资
	if current_job_listing:
		result.salary_earned = current_job_listing.actual_salary
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
		var listing := app.listing
		var job := listing.job
		var company := listing.company

		# 10% 概率被鬼了（公司不回应）
		if randf() < 0.10:
			app.status = GameData.ApplicationStatus.REJECTED
			var msg: String = _RESUME_GHOST[randi() % _RESUME_GHOST.size()]
			result.notifications.append("%s [%s]：%s" % [job.title, company, msg % company])
			continue

		var pass_rate := _calc_resume_pass_rate(listing, app.apply_penalty)
		if randf() < pass_rate:
			app.status = GameData.ApplicationStatus.HAS_INTERVIEW
			var referral_note := "（内推加成！）" if app.apply_penalty > 1.0 else ""
			result.notifications.append("✅ %s [%s]：简历通过！已安排面试。%s" % [job.title, company, referral_note])
		else:
			app.status = GameData.ApplicationStatus.REJECTED
			var primary_diff: int = (skills[job.skill_type] as int) - listing.actual_skill_required
			var msg: String
			if primary_diff >= 5:
				var tpl: String = _RESUME_OVERQUALIFIED[randi() % _RESUME_OVERQUALIFIED.size()]
				msg = tpl % company if "%s" in tpl else tpl
			else:
				var tpl: String = _RESUME_UNDERQUALIFIED[randi() % _RESUME_UNDERQUALIFIED.size()]
				msg = tpl % company if "%s" in tpl else tpl
			result.notifications.append("❌ %s [%s]：%s" % [job.title, company, msg])

	# 4. 处理面试结果（两段式判定 + 作品集加成）
	for listing_id in _interviewed_this_week:
		if not applications.has(listing_id):
			continue
		var app: GameData.JobApplication = applications[listing_id]
		if app.status != GameData.ApplicationStatus.INTERVIEWED:
			continue
		var listing := app.listing
		var job := listing.job
		var company := listing.company

		# 第二层：面试官好感（面试技巧 + 随机 + 作品集加成）
		var interview_skill: int = skills[GameData.SkillType.INTERVIEW]
		var vibe_base := clampf(0.40 + interview_skill * 0.05, 0.10, 0.90)

		# 作品集面试加成（×1.0 / ×1.08 / ×1.15 / ×1.20）
		const PORTFOLIO_VIBE_MULT: Array = [1.0, 1.08, 1.15, 1.20]
		var portfolio_pts: int
		if job.skill_type == GameData.SkillType.SYSTEM:
			portfolio_pts = portfolio_system
		else:
			portfolio_pts = portfolio_application
		var portfolio_mult: float = PORTFOLIO_VIBE_MULT[portfolio_pts]

		# "被问住"风险：主技能低于要求 2 级以上 且 作品集 ≥ 2
		var primary_skill: int = skills[job.skill_type] as int
		var skill_gap := listing.actual_skill_required - primary_skill
		var backfired := false
		if skill_gap >= 2 and portfolio_pts >= 2 and randf() < 0.10:
			portfolio_mult = 0.90
			backfired = true

		var vibe_rate := clampf(vibe_base * portfolio_mult, 0.05, 0.95)
		var vibe_pass := randf() < vibe_rate

		# 第三层：竞争（纯随机，随岗位层级递增，寒冬期加难）
		var comp_rate := 0.65
		if listing.actual_skill_required >= 8:
			comp_rate = 0.40
		elif listing.actual_skill_required >= 5:
			comp_rate = 0.55
		if market_downturn_weeks_left > 0:
			comp_rate *= 0.85
		var comp_pass := randf() < comp_rate

		if vibe_pass and comp_pass:
			app.status = GameData.ApplicationStatus.OFFER
			app.offer_weeks_left = GameData.OFFER_VALIDITY_WEEKS
			result.notifications.append(
				"🎉 恭喜！%s [%s] 向您发出了 Offer！（周薪 $%d，%d 周内有效）" % [
					job.title, company, listing.actual_salary, app.offer_weeks_left])
		elif not vibe_pass:
			app.status = GameData.ApplicationStatus.REJECTED
			if backfired:
				var bf_msg: String = _PORTFOLIO_BACKFIRE[randi() % _PORTFOLIO_BACKFIRE.size()]
				result.notifications.append("❌ %s [%s]：%s" % [job.title, company, bf_msg])
			else:
				var msg: String = _INTERVIEW_VIBE[randi() % _INTERVIEW_VIBE.size()]
				result.notifications.append("❌ %s [%s]：%s" % [job.title, company, msg])
		else:
			app.status = GameData.ApplicationStatus.REJECTED
			var msg: String = _INTERVIEW_COMPETITION[randi() % _INTERVIEW_COMPETITION.size()]
			result.notifications.append("❌ %s [%s]：%s" % [job.title, company, msg])

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
		result.notifications.append("你已离职：%s" % current_job_listing.job.title)
		current_job_listing = null
		pending_quit = false

	# 7. 随机事件（30% 概率）
	if randf() < 0.30:
		_process_random_event(result)

	result.cash_after = cash

	# 8. 判断 Game Over
	if cash < 0:
		result.is_game_over = true

	# 9. 寒冬倒计时
	if market_downturn_weeks_left > 0:
		market_downturn_weeks_left -= 1
		if market_downturn_weeks_left == 0:
			result.market_downturn_ended = true

	# 10. 推进到下一周 & 重置能量/效果
	week += 1
	energy = maxi(1, GameData.ENERGY_PER_WEEK + _energy_modifier_next_week)
	_energy_modifier_next_week = 0
	double_xp_this_week = _double_xp_next_week
	_double_xp_next_week = false
	_applied_this_week.clear()
	_interviewed_this_week.clear()

	# 11. 检查市场刷新（第7周先检查寒冬，再刷新）
	if week in GameData.MARKET_REFRESH_WEEKS and week != 1:
		if week == 7 and not _downturn_triggered and randf() < 0.30:
			market_downturn_weeks_left = 3
			_downturn_triggered = true
			result.market_downturn_started = true
		_refresh_job_market()
		result.market_refreshed = true
		result.new_market_bias = market_bias

	return result


# ════════════════════════════════════════
#  随机事件
# ════════════════════════════════════════

func _process_random_event(result: WeekSettlement) -> void:
	# 构建事件池；负面事件在寒冬期权重 ×1.3
	var neg_mult := 1.3 if market_downturn_weeks_left > 0 else 1.0
	# pool 内每项为 [event_id: String, weight: int]
	var pool: Array = []

	# 负面事件
	pool.append(["computer_broke",  int(3.0 * neg_mult)])
	pool.append(["rent_increase",   int(2.0 * neg_mult)])
	pool.append(["sick",            int(2.0 * neg_mult)])

	var has_interview_app := false
	var has_applied_app   := false
	for lid: String in applications:
		var app: GameData.JobApplication = applications[lid]
		if app.status == GameData.ApplicationStatus.HAS_INTERVIEW:
			has_interview_app = true
		if app.status == GameData.ApplicationStatus.APPLIED:
			has_applied_app = true

	# "面试被放鸽子" 权重极低，确保每次触发概率约 3%
	if has_interview_app:
		pool.append(["interview_ghosted", int(1.0 * neg_mult)])
	if has_applied_app:
		pool.append(["app_dropped",       int(1.0 * neg_mult)])

	# 正面事件
	pool.append(["freelance_gig",     3])
	pool.append(["good_mood",         2])
	pool.append(["cheap_food",        2])
	pool.append(["flash_inspiration", 2])

	# 朋友内推：权重随人脉线性增加（0点不进池）
	if networking_points >= 1:
		var ref_weight := 4
		if networking_points >= 7:
			ref_weight = 12
		elif networking_points >= 4:
			ref_weight = 8
		pool.append(["referral", ref_weight])

	# 加权随机选取
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

	# 执行事件效果
	match chosen_id:
		"computer_broke":
			result.event_name = "🔧 电脑出了点问题"
			result.event_desc = "紧急维修费 $300。"
			cash -= 300
		"rent_increase":
			result.event_name = "🏠 临时涨租"
			result.event_desc = "房东要求补交差价，额外支出 $250。"
			cash -= 250
		"sick":
			result.event_name = "🤒 突发低烧"
			result.event_desc = "下周最大能量 -2。"
			_energy_modifier_next_week -= 2
		"interview_ghosted":
			var ghosted_id := _pick_random_app_with_status(GameData.ApplicationStatus.HAS_INTERVIEW)
			if not ghosted_id.is_empty():
				var app: GameData.JobApplication = applications[ghosted_id]
				result.event_name = "📵 面试被放鸽子"
				result.event_desc = "%s [%s] 的面试官临时有事，面试取消。" % [
					app.listing.job.title, app.listing.company]
				applications.erase(ghosted_id)
			else:
				return  # 没有可取消的面试，事件无效
		"app_dropped":
			var dropped_id := _pick_random_app_with_status(GameData.ApplicationStatus.APPLIED)
			if not dropped_id.is_empty():
				var app: GameData.JobApplication = applications[dropped_id]
				result.event_name = "🗑 简历不翼而飞"
				result.event_desc = "%s 表示从未收到你的简历（HR系统故障）。" % app.listing.company
				applications.erase(dropped_id)
			else:
				return
		"freelance_gig":
			result.event_name = "💰 接到外包小单"
			result.event_desc = "意外接到外包，收入 +$350。"
			cash += 350
		"good_mood":
			result.event_name = "☀ 今天状态奇好"
			result.event_desc = "下周能量上限 +2。"
			_energy_modifier_next_week += 2
		"cheap_food":
			result.event_name = "🍜 发现省钱攻略"
			result.event_desc = "附近超市大促，本周生活补贴 +$250。"
			cash += 250
		"flash_inspiration":
			result.event_name = "💡 灵感爆发"
			result.event_desc = "下周学习任意技能 XP 翻倍。"
			_double_xp_next_week = true
		"referral":
			var listing := _pick_referral_listing()
			if listing:
				var new_app := GameData.JobApplication.new(listing, 1.5)
				applications[listing.listing_id] = new_app
				_pending_referrals.append(listing.listing_id)
				result.event_name = "🤝 朋友内推"
				result.event_desc = "已内推 %s [%s]，简历通过率 ×150%%！（下周出结果）" % [
					listing.job.title, listing.company]
			else:
				return


func _pick_random_app_with_status(status: GameData.ApplicationStatus) -> String:
	var matching: Array[String] = []
	for lid: String in applications:
		var app: GameData.JobApplication = applications[lid]
		if app.status == status:
			matching.append(lid)
	if matching.is_empty():
		return ""
	return matching[randi() % matching.size()]


func _pick_referral_listing() -> GameData.JobListing:
	var eligible: Array[GameData.JobListing] = []
	for listing in current_listings:
		# 跳过已在进行中的申请（仅跳过非拒绝状态）
		if applications.has(listing.listing_id):
			var app: GameData.JobApplication = applications[listing.listing_id]
			if app.status != GameData.ApplicationStatus.REJECTED:
				continue
		eligible.append(listing)
	if eligible.is_empty():
		return null

	# 人脉 4+：偏向玩家较强方向
	if networking_points >= 4:
		var sys_skill: int = skills[GameData.SkillType.SYSTEM] as int
		var app_skill: int = skills[GameData.SkillType.APPLICATION] as int
		var preferred := GameData.SkillType.SYSTEM if sys_skill >= app_skill else GameData.SkillType.APPLICATION
		var pref_list: Array[GameData.JobListing] = []
		for l in eligible:
			if l.job.skill_type == preferred:
				pref_list.append(l)
		if not pref_list.is_empty():
			eligible = pref_list

	# 人脉 7+：偏向适合玩家层级的岗位
	if networking_points >= 7:
		var primary_skill: int = maxi(
			skills[GameData.SkillType.SYSTEM] as int,
			skills[GameData.SkillType.APPLICATION] as int)
		var good_tier: Array[GameData.JobListing] = []
		for l in eligible:
			if absi(l.actual_skill_required - primary_skill) <= 2:
				good_tier.append(l)
		if not good_tier.is_empty():
			eligible = good_tier

	return eligible[randi() % eligible.size()]


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
	if current_job_listing:
		if current_job_listing.job.skill_required >= 8:
			return Ending.SUCCESS
		elif current_job_listing.job.skill_required >= 5:
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

	# 寒冬期缩减岗位数
	var total_listings := GameData.LISTINGS_PER_REFRESH
	if market_downturn_weeks_left > 0:
		total_listings = 3

	var system_count := 0
	var app_count := 0
	match market_bias:
		GameData.MarketBias.SYSTEM_HEAVY:
			system_count = mini(3, total_listings - 1)
			app_count = total_listings - system_count
		GameData.MarketBias.APP_HEAVY:
			app_count = mini(3, total_listings - 1)
			system_count = total_listings - app_count
		_:
			system_count = total_listings / 2
			app_count = total_listings - system_count

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

		var actual_salary := roundi(job.weekly_salary * randf_range(0.85, 1.15) / 10.0) * 10
		var actual_skill_req: int = maxi(1, job.skill_required + (randi() % 3) - 1)
		var actual_eng_req: int  = maxi(1, job.english_required + (randi() % 3) - 1)
		var actual_cpp_req := 0
		if job.cpp_required > 0:
			actual_cpp_req = maxi(1, job.cpp_required + (randi() % 3) - 1)

		current_listings.append(GameData.JobListing.new(
			listing_id, job, company, actual_salary, actual_skill_req, actual_eng_req, actual_cpp_req))


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

## 主技能：差值 0~+4 为峰值区，+5以上 over-qualified，负数快速下降
## 英语：所有岗位均影响；C++：仅系统方向岗位影响
## 作品集：直接叠加简历通过率
## modifier：批量惩罚（<1.0）或内推加成（>1.0）
func _calc_resume_pass_rate(listing: GameData.JobListing, modifier: float) -> float:
	var job := listing.job
	var base := 0.55

	# 主技能修正
	var diff: int = (skills[job.skill_type] as int) - listing.actual_skill_required
	var primary_mod: float
	if diff >= 5:
		primary_mod = maxf(0.16 - (diff - 4) * 0.08, -0.20)
	elif diff >= 0:
		primary_mod = diff * 0.04
	elif diff == -1:
		primary_mod = -0.15
	elif diff == -2:
		primary_mod = -0.30
	else:
		primary_mod = maxf(-0.30 - (absf(diff) - 2) * 0.10, -0.50)

	# 英语修正
	var eng_diff: int = (skills[GameData.SkillType.ENGLISH] as int) - listing.actual_english_required
	var english_mod := clampf(eng_diff * 0.04, -0.12, 0.08)

	# C++ 修正（仅系统方向）
	var cpp_mod := 0.0
	if job.skill_type == GameData.SkillType.SYSTEM and listing.actual_cpp_required > 0:
		var cpp_diff: int = (skills[GameData.SkillType.CPP] as int) - listing.actual_cpp_required
		cpp_mod = clampf(cpp_diff * 0.04, -0.12, 0.08)

	# 作品集简历加成（+8% per 项目，上限 +24%）
	var portfolio_pts: int
	if job.skill_type == GameData.SkillType.SYSTEM:
		portfolio_pts = portfolio_system
	else:
		portfolio_pts = portfolio_application
	var portfolio_bonus := portfolio_pts * 0.08

	return clampf((base + primary_mod + english_mod + cpp_mod + portfolio_bonus) * modifier, 0.05, 0.88)


# ════════════════════════════════════════
#  内部工具
# ════════════════════════════════════════

func _find_listing(listing_id: String) -> GameData.JobListing:
	for listing in current_listings:
		if listing.listing_id == listing_id:
			return listing
	if applications.has(listing_id):
		return (applications[listing_id] as GameData.JobApplication).listing
	return null


func get_market_bias_text() -> String:
	match market_bias:
		GameData.MarketBias.SYSTEM_HEAVY:
			return "系统/后端需求旺盛"
		GameData.MarketBias.APP_HEAVY:
			return "前端/应用需求旺盛"
		_:
			return "市场需求均衡"
