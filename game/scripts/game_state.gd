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

# ── 工作状态 ──
var current_job: GameData.JobDef = null  # 当前在职岗位
var pending_quit: bool = false            # 是否已提交辞职（下周生效）

# ── 求职进度 ──
var applications: Dictionary = {}  # job_id -> JobApplication

# ── 本周行动记录（用于结算通知） ──
var _applied_this_week: Array[String] = []
var _interviewed_this_week: Array[String] = []

# ── 所有岗位引用 ──
var all_jobs: Array[GameData.JobDef]

func _init() -> void:
	all_jobs = GameData.get_all_jobs()


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


## 学习技能（升到第 N 级需消耗 N 点能量）
func action_study(skill_type: GameData.SkillType) -> bool:
	var current_level: int = skills[skill_type]
	if current_level >= GameData.MAX_SKILL_LEVEL:
		return false
	var cost: int = current_level + 1
	if get_free_energy() < cost:
		return false
	energy -= cost
	skills[skill_type] = current_level + 1
	return true


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


## 投递简历
func action_apply(job_id: String) -> bool:
	if get_free_energy() < 1:
		return false
	# 检查是否已有进行中的申请
	if applications.has(job_id):
		var app: GameData.JobApplication = applications[job_id]
		if app.status != GameData.ApplicationStatus.NONE and \
				app.status != GameData.ApplicationStatus.REJECTED:
			return false
	var job := _find_job(job_id)
	if job == null:
		return false
	energy -= 1
	var app := GameData.JobApplication.new(job)
	applications[job_id] = app
	_applied_this_week.append(job_id)
	return true


## 参加面试
func action_interview(job_id: String) -> bool:
	if get_free_energy() < 2:
		return false
	if not applications.has(job_id):
		return false
	var app: GameData.JobApplication = applications[job_id]
	if app.status != GameData.ApplicationStatus.HAS_INTERVIEW:
		return false
	energy -= 2
	app.status = GameData.ApplicationStatus.INTERVIEWED
	_interviewed_this_week.append(job_id)
	return true


## 接受 Offer
func action_accept_offer(job_id: String) -> bool:
	if not applications.has(job_id):
		return false
	var app: GameData.JobApplication = applications[job_id]
	if app.status != GameData.ApplicationStatus.OFFER:
		return false
	# 如果当前在职，跳槽（当前工作自动结束）
	current_job = app.job
	pending_quit = false
	# 清除该申请
	applications.erase(job_id)
	return true


## 拒绝 Offer
func action_reject_offer(job_id: String) -> bool:
	if not applications.has(job_id):
		return false
	var app: GameData.JobApplication = applications[job_id]
	if app.status != GameData.ApplicationStatus.OFFER:
		return false
	applications.erase(job_id)
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
	# 上周投递 → 本周出结果
	for job_id in _applied_this_week:
		if not applications.has(job_id):
			continue
		var app: GameData.JobApplication = applications[job_id]
		if app.status != GameData.ApplicationStatus.APPLIED:
			continue
		var job := app.job
		var player_skill: int = skills[job.skill_type]
		if player_skill >= job.skill_required:
			app.status = GameData.ApplicationStatus.HAS_INTERVIEW
			result.notifications.append("%s：简历通过，获得面试机会！" % job.title)
		else:
			app.status = GameData.ApplicationStatus.REJECTED
			result.notifications.append("%s：很遗憾，简历未通过筛选。" % job.title)

	# 上周面试 → 本周出结果
	for job_id in _interviewed_this_week:
		if not applications.has(job_id):
			continue
		var app: GameData.JobApplication = applications[job_id]
		if app.status != GameData.ApplicationStatus.INTERVIEWED:
			continue
		var pass_rate := _calc_interview_pass_rate(app.job)
		if randf() <= pass_rate:
			app.status = GameData.ApplicationStatus.OFFER
			app.offer_weeks_left = GameData.OFFER_VALIDITY_WEEKS
			result.notifications.append("%s：面试通过，获得 Offer！（%d 周内有效）" % [app.job.title, app.offer_weeks_left])
		else:
			app.status = GameData.ApplicationStatus.REJECTED
			result.notifications.append("%s：面试未通过。" % app.job.title)

	# 4. Offer 有效期 -1，过期自动作废
	var to_expire: Array[String] = []
	for job_id in applications:
		var app: GameData.JobApplication = applications[job_id]
		if app.status == GameData.ApplicationStatus.OFFER:
			app.offer_weeks_left -= 1
			if app.offer_weeks_left <= 0:
				to_expire.append(job_id)
				result.expired_offers.append(app.job.title)
	for job_id in to_expire:
		applications.erase(job_id)

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

	return result


# ════════════════════════════════════════
#  结局判定
# ════════════════════════════════════════

enum Ending { GAME_OVER, STRUGGLING, STABLE, SUCCESS }

func get_ending() -> Ending:
	if cash < 0:
		return Ending.GAME_OVER

	# 检查是否持有高级岗位 offer
	for job_id in applications:
		var app: GameData.JobApplication = applications[job_id]
		if app.status == GameData.ApplicationStatus.OFFER:
			if app.job.skill_required >= 8:
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
#  内部工具
# ════════════════════════════════════════

func _find_job(job_id: String) -> GameData.JobDef:
	for job in all_jobs:
		if job.id == job_id:
			return job
	return null


func _calc_interview_pass_rate(job: GameData.JobDef) -> float:
	var player_skill: int = skills[job.skill_type]
	var interview_skill: int = skills[GameData.SkillType.INTERVIEW]
	var rate := 0.35 + (player_skill - job.skill_required) * 0.08 + interview_skill * 0.02
	return clampf(rate, 0.2, 0.95)
