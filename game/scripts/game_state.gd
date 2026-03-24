## 游戏状态管理 - 核心逻辑（V2: 疲劳/行动细化/数值重平衡/动态市场/信息透明）
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
	GameData.SkillType.SYSTEM: 0.0,
	GameData.SkillType.APPLICATION: 0.0,
	GameData.SkillType.INTERVIEW: 0.0,
	GameData.SkillType.ENGLISH: 0.0,
	GameData.SkillType.CPP: 0.0,
}

# ── 人脉与作品集 ──
var networking_points: int = 0
var portfolio_system: int = 0
var portfolio_application: int = 0
var portfolio_xp_system: int = 0       # V2: 开源积累（达到 PORTFOLIO_XP_NEEDED 时 +1 作品集）
var portfolio_xp_application: int = 0

# ── 工作状态 ──
var current_job_listing: GameData.JobListing = null
var pending_quit: bool = false

# ── 求职进度：listing_id -> JobApplication ──
var applications: Dictionary = {}

# ── 岗位市场 ──
var current_listings: Array[GameData.JobListing] = []
var market_bias: GameData.MarketBias = GameData.MarketBias.BALANCED
var hot_skill: GameData.SkillType = GameData.SkillType.SYSTEM  # V2: 热门技能

# ── 市场寒冬 ──
var market_downturn_weeks_left: int = 0
var _downturn_triggered: bool = false

# ── V2: 学习疲劳（每周重置）──
var weekly_study_count: Dictionary = {}  # SkillType -> int（本周看文档次数）

# ── 周效果 ──
var fatigue_bonus_this_week: int = 0   # V2: 灵感爆发 → 疲劳阈值+1
var _fatigue_bonus_next_week: int = 0
var _energy_modifier_next_week: int = 0
var mock_interview_buff: bool = false   # V2: 模拟面试 → 下次面试vibe+10%

# ── V3: 工具系统 ──
var owned_tools: Array[String] = []           # 已装备的工具ID列表
var shop_available_tools: Array[String] = []  # 当前二手市场展示的工具ID
var shop_visited_this_week: bool = false

# ── V3: 特质系统 ──
var active_traits: Array[String] = []         # 已激活的特质ID列表
# 特质进度追踪
var _study_streak_weeks: int = 0              # 连续学习≥4次的周数（卷王）
var _weekly_study_total: int = 0              # 本周学习总次数
var _skill_first_learn_week: Dictionary = {}  # SkillType -> 开始学习的周数（速通达人）
var _vibe_pass_count: int = 0                 # 累计vibe通过次数（面霸）
var _triple_apply_weeks: int = 0              # 累计单周投3份的次数（海王）
var _highest_rejected_salary: int = 0         # 拒绝过的最高薪资（谈判专家）
var _has_rejected_offer: bool = false
var _cash_above_3000_weeks: int = 0           # 连续存款>$3000周数（细水长流）
var _total_gig_count: int = 0                 # 累计零工/私活次数（斜杠青年）
var _referral_interview_count: int = 0        # 内推获面试次数（圈内人）
var _speedrun_skill: GameData.SkillType = GameData.SkillType.SYSTEM  # 速通达人对应技能

var _all_jobs: Array[GameData.JobDef]
var _all_tools: Array[GameData.ToolDef]
var _all_traits: Array[GameData.TraitDef]
var _listing_counter: int = 0
var _applied_this_week: Array[String] = []
var _interviewed_this_week: Array[String] = []
var _pending_referrals: Array[String] = []
var _weekly_apply_count: int = 0              # 本周投递数量（海王追踪）

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
	_all_tools = GameData.get_all_tools()
	_all_traits = GameData.get_all_traits()
	_refresh_job_market()


# ════════════════════════════════════════
#  能量与技能
# ════════════════════════════════════════

func get_free_energy() -> int:
	var locked := 0
	if current_job_listing:
		locked = current_job_listing.job.energy_cost
	return energy - locked


func get_skill(skill_type: GameData.SkillType) -> int:
	return skills[skill_type]


## 获取技能升级进度，如 "2/3" 或 "1.5/3"；满级返回 "MAX"
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


## 内部：给技能加 XP 并自动升级
func _add_skill_xp(skill_type: GameData.SkillType, amount: float) -> void:
	if amount <= 0:
		return
	skill_xp[skill_type] += amount
	var lv: int = skills[skill_type]
	while lv < GameData.MAX_SKILL_LEVEL:
		var needed := float(GameData.xp_needed_for_level(lv + 1))
		if skill_xp[skill_type] >= needed:
			skill_xp[skill_type] -= needed
			lv += 1
			skills[skill_type] = lv
		else:
			break
	if lv >= GameData.MAX_SKILL_LEVEL:
		skill_xp[skill_type] = 0.0


# ════════════════════════════════════════
#  V3: 工具与特质查询
# ════════════════════════════════════════

## 是否拥有某工具
func has_tool(tool_id: String) -> bool:
	return owned_tools.has(tool_id)

## 是否拥有某特质
func has_trait(trait_id: String) -> bool:
	return active_traits.has(trait_id)

## 获取工具每周总费用
func get_tool_weekly_cost() -> int:
	var total := 0
	for tid in owned_tools:
		var tdef := _find_tool_def(tid)
		if tdef:
			total += tdef.weekly_cost
	return total

## 查找工具定义
func _find_tool_def(tool_id: String) -> GameData.ToolDef:
	for t in _all_tools:
		if t.id == tool_id:
			return t
	return null

## 查找特质定义
func _find_trait_def(trait_id: String) -> GameData.TraitDef:
	for t in _all_traits:
		if t.id == trait_id:
			return t
	return null

## 获取零工/私活收入倍率（斜杠青年+社牛+共享办公）
func _get_gig_income_multiplier() -> float:
	var mult := 1.0
	if has_trait("slasher"):
		mult += 0.25
	if has_trait("social_butterfly"):
		mult += 0.30
	if has_tool("coworking") and networking_points >= 5:
		mult += 0.20
	return mult

## 获取学习XP加成（卷王+背水一战）
func _get_study_xp_bonus() -> float:
	var bonus := 0.0
	if has_trait("juanwang"):
		bonus += 0.5
	if has_trait("desperate"):
		bonus += 0.2  # 20% of base 1.0
	return bonus

## V3: 逛二手市场（1EP，刷新可购买工具列表）
func action_browse_shop() -> bool:
	if get_free_energy() < GameData.SHOP_ENERGY_COST:
		return false
	energy -= GameData.SHOP_ENERGY_COST
	_refresh_shop()
	shop_visited_this_week = true
	return true

## 刷新商店：从未拥有的工具中随机展示3个
func _refresh_shop() -> void:
	var available: Array[String] = []
	for t in _all_tools:
		if not owned_tools.has(t.id):
			available.append(t.id)
	available.shuffle()
	shop_available_tools.clear()
	for i in range(mini(GameData.SHOP_DISPLAY_COUNT, available.size())):
		shop_available_tools.append(available[i])

## 购买工具（返回是否成功）
func action_buy_tool(tool_id: String) -> bool:
	var tdef := _find_tool_def(tool_id)
	if tdef == null:
		return false
	if owned_tools.has(tool_id):
		return false
	if cash < tdef.price:
		return false
	if owned_tools.size() >= GameData.MAX_TOOLS:
		return false  # 需要先调用 replace
	cash -= tdef.price
	owned_tools.append(tool_id)
	return true

## 替换工具（背包满时用新工具替换旧工具）
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

## V3: 远程兼职（需要ThinkPad，2EP→$350）
func action_remote_gig() -> bool:
	if not has_tool("thinkpad"):
		return false
	if get_free_energy() < GameData.REMOTE_GIG_ENERGY:
		return false
	energy -= GameData.REMOTE_GIG_ENERGY
	var income := GameData.REMOTE_GIG_INCOME
	if market_downturn_weeks_left > 0:
		income = int(income * 0.90)
	income = int(income * _get_gig_income_multiplier())
	cash += income
	_total_gig_count += 1
	return true

## 获取远程兼职收入（供UI显示）
func get_remote_gig_income() -> int:
	var income := GameData.REMOTE_GIG_INCOME
	if market_downturn_weeks_left > 0:
		income = int(income * 0.90)
	income = int(income * _get_gig_income_multiplier())
	return income

## 获取特质进度信息（供UI显示）
func get_trait_progress(trait_id: String) -> String:
	match trait_id:
		"juanwang":
			return "连续学习周数：%d/3" % _study_streak_weeks
		"speedrun":
			return "（需在4周内将技能0→5）"
		"fullstack":
			var sys_lv: int = skills[GameData.SkillType.SYSTEM]
			var app_lv: int = skills[GameData.SkillType.APPLICATION]
			return "系统Lv.%d/4 应用Lv.%d/4" % [mini(sys_lv, 4), mini(app_lv, 4)]
		"mianba":
			return "vibe通过：%d/3" % _vibe_pass_count
		"haiwang":
			return "单周3投次数：%d/2" % _triple_apply_weeks
		"negotiator":
			if _has_rejected_offer:
				return "已拒绝offer（最高$%d/周），等待更高薪offer" % _highest_rejected_salary
			return "尚未拒绝过offer"
		"conservative":
			return "连续>$3,000周数：%d/4" % _cash_above_3000_weeks
		"slasher":
			return "零工/私活次数：%d/8" % _total_gig_count
		"desperate":
			return "现金：$%d（<%d触发）" % [cash, 500]
		"social_butterfly":
			return "人脉：%d/7" % mini(networking_points, 7)
		"opensource_pro":
			var pf := maxi(portfolio_system, portfolio_application)
			return "作品集：%d/2 人脉：%d/3" % [mini(pf, 2), mini(networking_points, 3)]
		"insider":
			return "内推面试：%d/2" % _referral_interview_count
		_:
			return ""


# ════════════════════════════════════════
#  V2: 学习疲劳查询
# ════════════════════════════════════════

## 返回看文档的疲劳状态: "normal" / "half" / "blocked"
func get_docs_fatigue(skill_type: GameData.SkillType) -> String:
	var count: int = weekly_study_count.get(skill_type, 0)
	var threshold: int = GameData.STUDY_FULL_XP_LIMIT + fatigue_bonus_this_week
	if count < threshold:
		return "normal"
	elif count == threshold:
		return "half"
	else:
		return "blocked"


# ════════════════════════════════════════
#  V2: 学习行动（拆分为看文档/刷题/做开源）
# ════════════════════════════════════════

## 看文档/看面经/背单词（1EP, 受疲劳限制, 稳定XP）
func action_study_docs(skill_type: GameData.SkillType) -> bool:
	if skills[skill_type] >= GameData.MAX_SKILL_LEVEL:
		return false
	if get_free_energy() < 1:
		return false
	var fatigue := get_docs_fatigue(skill_type)
	if fatigue == "blocked":
		return false
	energy -= 1
	var xp_gain: float = 1.0 if fatigue == "normal" else 0.5
	if skill_type == hot_skill:
		xp_gain += GameData.HOT_SKILL_XP_BONUS
	# V3: 机械键盘加成
	if has_tool("mech_keyboard"):
		xp_gain += 0.5
	# V3: 卷王/背水一战加成
	xp_gain += _get_study_xp_bonus()
	weekly_study_count[skill_type] = weekly_study_count.get(skill_type, 0) + 1
	_weekly_study_total += 1
	_track_skill_start(skill_type)
	_add_skill_xp(skill_type, xp_gain)
	return true


## 刷题/实战练习（1EP, 不受疲劳, 随机0-2XP; 仅限SYSTEM/APPLICATION/CPP）
func action_study_practice(skill_type: GameData.SkillType) -> bool:
	if skill_type not in [GameData.SkillType.SYSTEM, GameData.SkillType.APPLICATION, GameData.SkillType.CPP]:
		return false
	if skills[skill_type] >= GameData.MAX_SKILL_LEVEL:
		return false
	if get_free_energy() < 1:
		return false
	energy -= 1
	var roll := randf()
	var base_xp: float
	if roll < 0.20:
		base_xp = 0.0
	elif roll < 0.80:
		base_xp = 1.0
	else:
		base_xp = 2.0
	# V3: LeetCode会员加成 (+1)
	if has_tool("leetcode"):
		base_xp += 1.0
	if skill_type == hot_skill:
		base_xp += GameData.HOT_SKILL_XP_BONUS
	# V3: 卷王/背水一战加成
	base_xp += _get_study_xp_bonus()
	_weekly_study_total += 1
	_track_skill_start(skill_type)
	_add_skill_xp(skill_type, base_xp)
	return true


## 做开源贡献（2EP, +1XP +0.5作品集; 仅限SYSTEM/APPLICATION）
## V3: GitHub Copilot降低到1EP
func action_study_opensource(skill_type: GameData.SkillType) -> bool:
	if skill_type not in [GameData.SkillType.SYSTEM, GameData.SkillType.APPLICATION]:
		return false
	if skills[skill_type] >= GameData.MAX_SKILL_LEVEL:
		return false
	var cost := GameData.OPENSOURCE_ENERGY
	if has_tool("copilot"):
		cost = 1
	if get_free_energy() < cost:
		return false
	energy -= cost
	var xp_gain := 1.0
	if skill_type == hot_skill:
		xp_gain += GameData.HOT_SKILL_XP_BONUS
	# V3: 卷王/背水一战加成
	xp_gain += _get_study_xp_bonus()
	_weekly_study_total += 1
	_track_skill_start(skill_type)
	_add_skill_xp(skill_type, xp_gain)
	# 作品集进度
	if skill_type == GameData.SkillType.SYSTEM:
		if portfolio_system < GameData.MAX_PORTFOLIO_POINTS:
			portfolio_xp_system += GameData.PORTFOLIO_XP_NEEDED / 2  # always +1 xp (need 2 for +1 point)
			if portfolio_xp_system >= GameData.PORTFOLIO_XP_NEEDED:
				portfolio_xp_system -= GameData.PORTFOLIO_XP_NEEDED
				portfolio_system += 1
	else:
		if portfolio_application < GameData.MAX_PORTFOLIO_POINTS:
			portfolio_xp_application += GameData.PORTFOLIO_XP_NEEDED / 2
			if portfolio_xp_application >= GameData.PORTFOLIO_XP_NEEDED:
				portfolio_xp_application -= GameData.PORTFOLIO_XP_NEEDED
				portfolio_application += 1
	# V3: 开源达人特质 → 开源时额外+1人脉
	if has_trait("opensource_pro") and networking_points < GameData.MAX_NETWORKING_POINTS:
		networking_points += 1
	return true


## V2: 模拟面试（2EP, +1面试XP, 下次面试vibe+10%）
func action_mock_interview() -> bool:
	if skills[GameData.SkillType.INTERVIEW] >= GameData.MAX_SKILL_LEVEL:
		return false
	if get_free_energy() < GameData.MOCK_INTERVIEW_ENERGY:
		return false
	energy -= GameData.MOCK_INTERVIEW_ENERGY
	var xp_gain := 1.0
	if hot_skill == GameData.SkillType.INTERVIEW:
		xp_gain += GameData.HOT_SKILL_XP_BONUS
	xp_gain += _get_study_xp_bonus()
	_weekly_study_total += 1
	_track_skill_start(GameData.SkillType.INTERVIEW)
	_add_skill_xp(GameData.SkillType.INTERVIEW, xp_gain)
	mock_interview_buff = true
	return true


## V2: 参加英语角（2EP, +1英语XP, +1人脉）
func action_english_corner() -> bool:
	if get_free_energy() < GameData.ENGLISH_CORNER_ENERGY:
		return false
	energy -= GameData.ENGLISH_CORNER_ENERGY
	if skills[GameData.SkillType.ENGLISH] < GameData.MAX_SKILL_LEVEL:
		var xp_gain := 1.0
		if hot_skill == GameData.SkillType.ENGLISH:
			xp_gain += GameData.HOT_SKILL_XP_BONUS
		xp_gain += _get_study_xp_bonus()
		_weekly_study_total += 1
		_track_skill_start(GameData.SkillType.ENGLISH)
		_add_skill_xp(GameData.SkillType.ENGLISH, xp_gain)
	if networking_points < GameData.MAX_NETWORKING_POINTS:
		networking_points += 1
	return true


# ════════════════════════════════════════
#  工作行动
# ════════════════════════════════════════

## 兼职零工（寒冬期收入 -10%；V3: 斜杠青年/社牛/共享办公加成）
func action_gig_parttime() -> bool:
	if get_free_energy() < GameData.GIG_ENERGY_PARTTIME:
		return false
	energy -= GameData.GIG_ENERGY_PARTTIME
	var income := GameData.GIG_INCOME_PARTTIME
	if market_downturn_weeks_left > 0:
		income = int(income * 0.90)
	income = int(income * _get_gig_income_multiplier())
	cash += income
	_total_gig_count += 1
	return true


## 全职零工（寒冬期收入 -10%；V3: 斜杠青年/社牛/共享办公加成）
func action_gig_fulltime() -> bool:
	if get_free_energy() < GameData.GIG_ENERGY_FULLTIME:
		return false
	energy -= GameData.GIG_ENERGY_FULLTIME
	var income := GameData.GIG_INCOME_FULLTIME
	if market_downturn_weeks_left > 0:
		income = int(income * 0.90)
	income = int(income * _get_gig_income_multiplier())
	cash += income
	_total_gig_count += 1
	return true


## V2: 技术私活（2EP, $150 + 最高专业技能×$40; 需要专业技能≥3）
## V3: 知识星球+$100, 斜杠青年/社牛/共享办公加成
func action_tech_freelance() -> bool:
	var max_primary := maxi(skills[GameData.SkillType.SYSTEM] as int, skills[GameData.SkillType.APPLICATION] as int)
	if max_primary < GameData.TECH_FREELANCE_MIN_SKILL:
		return false
	if get_free_energy() < GameData.TECH_FREELANCE_ENERGY:
		return false
	energy -= GameData.TECH_FREELANCE_ENERGY
	var income := GameData.TECH_FREELANCE_BASE + max_primary * GameData.TECH_FREELANCE_PER_SKILL
	if has_tool("zhishixingqiu"):
		income += 100
	if market_downturn_weeks_left > 0:
		income = int(income * 0.90)
	income = int(income * _get_gig_income_multiplier())
	cash += income
	_total_gig_count += 1
	return true


## 获取技术私活收入（供UI显示）
func get_tech_freelance_income() -> int:
	var max_primary := maxi(skills[GameData.SkillType.SYSTEM] as int, skills[GameData.SkillType.APPLICATION] as int)
	var income := GameData.TECH_FREELANCE_BASE + max_primary * GameData.TECH_FREELANCE_PER_SKILL
	if has_tool("zhishixingqiu"):
		income += 100
	if market_downturn_weeks_left > 0:
		income = int(income * 0.90)
	income = int(income * _get_gig_income_multiplier())
	return income


# ════════════════════════════════════════
#  社交行动
# ════════════════════════════════════════

## 维护人脉（1 能量，人脉 +1，上限 10）
## V3: LinkedIn会员每次+2
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


# ════════════════════════════════════════
#  求职行动
# ════════════════════════════════════════

## 批量投递（1能量，1-3个listing_id；V2: 人脉≥8时惩罚降一档）
## V3: 海王特质减半惩罚
func action_apply_batch(listing_ids: Array[String]) -> bool:
	if listing_ids.is_empty() or get_free_energy() < 1:
		return false

	var count := listing_ids.size()
	# V2: 人脉≥8时，惩罚按 count-1 计算
	var effective_count := count
	if networking_points >= GameData.NETWORKING_APPLY_THRESHOLD:
		effective_count = maxi(1, count - 1)
	var penalty := 1.0
	if effective_count == 2:
		penalty = GameData.BATCH_PENALTY_2
	elif effective_count >= 3:
		penalty = GameData.BATCH_PENALTY_3
	# V3: 海王特质减半惩罚
	if has_trait("haiwang") and penalty < 1.0:
		penalty = 1.0 - (1.0 - penalty) * 0.5  # 0.65 → 0.825, 0.80 → 0.90
	# V3: 追踪海王进度
	if count >= 3:
		_weekly_apply_count += count  # will check at week end

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


## 拒绝 Offer（V3: 追踪谈判专家进度）
func action_reject_offer(listing_id: String) -> bool:
	if not applications.has(listing_id):
		return false
	var app: GameData.JobApplication = applications[listing_id]
	if app.status != GameData.ApplicationStatus.OFFER:
		return false
	# V3: 谈判专家追踪
	_has_rejected_offer = true
	if app.listing.actual_salary > _highest_rejected_salary:
		_highest_rejected_salary = app.listing.actual_salary
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
	var tool_cost: int = 0                       # V3: 工具订阅费用
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
	var new_traits: Array[String] = []           # V3: 本周新获得的特质ID
	var lost_traits: Array[String] = []          # V3: 本周失去的特质ID


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

	# 2. 扣生活费（V3: 咖啡机-$80, 细水长流-$50）
	var living := GameData.WEEKLY_LIVING_COST
	if has_tool("coffee_machine"):
		living -= 80
	if has_trait("conservative"):
		living -= 50
	result.living_cost = living
	cash -= living

	# 2.5 V3: 扣工具订阅费
	var tool_cost := get_tool_weekly_cost()
	if tool_cost > 0:
		cash -= tool_cost
		result.tool_cost = tool_cost

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

		# 10% 概率被鬼了
		if randf() < 0.10:
			app.status = GameData.ApplicationStatus.REJECTED
			var msg: String = _RESUME_GHOST[randi() % _RESUME_GHOST.size()]
			result.notifications.append("%s [%s]：%s" % [job.title, company, msg % company])
			continue

		var pass_rate := calc_resume_pass_rate(listing, app.apply_penalty)
		# V3: 圈内人特质追踪（内推通过简历）
		if randf() < pass_rate:
			app.status = GameData.ApplicationStatus.HAS_INTERVIEW
			var referral_note := "（内推加成！）" if app.apply_penalty > 1.0 else ""
			# V3: 圈内人追踪
			if app.apply_penalty > 1.0:
				_referral_interview_count += 1
			result.notifications.append("✅ %s [%s]：简历通过！已安排面试。%s" % [job.title, company, referral_note])
		else:
			app.status = GameData.ApplicationStatus.REJECTED
			var primary_diff: int = (skills[job.skill_type] as int) - listing.actual_skill_required
			var reason_parts: Array[String] = []
			if primary_diff < 0:
				reason_parts.append("技能差%d级" % absi(primary_diff))
			elif primary_diff >= 5:
				reason_parts.append("资历过高")
			var eng_diff: int = (skills[GameData.SkillType.ENGLISH] as int) - _effective_english_req(listing)
			if eng_diff < 0:
				reason_parts.append("英语不足")
			var reason := "（%s，通过率%.0f%%）" % ["、".join(reason_parts), pass_rate * 100] if reason_parts.size() > 0 else "（通过率%.0f%%）" % (pass_rate * 100)
			var msg: String
			if primary_diff >= 5:
				var tpl: String = _RESUME_OVERQUALIFIED[randi() % _RESUME_OVERQUALIFIED.size()]
				msg = tpl % company if "%s" in tpl else tpl
			else:
				var tpl: String = _RESUME_UNDERQUALIFIED[randi() % _RESUME_UNDERQUALIFIED.size()]
				msg = tpl % company if "%s" in tpl else tpl
			result.notifications.append("❌ %s [%s]%s：%s" % [job.title, company, reason, msg])

	# 4. 处理面试结果
	for listing_id in _interviewed_this_week:
		if not applications.has(listing_id):
			continue
		var app: GameData.JobApplication = applications[listing_id]
		if app.status != GameData.ApplicationStatus.INTERVIEWED:
			continue
		var listing := app.listing
		var job := listing.job
		var company := listing.company

		# Vibe 判定（V2: 人脉加成 + 模拟面试buff + 热门技能）
		var interview_skill: int = skills[GameData.SkillType.INTERVIEW]
		var vibe_base := 0.40 + interview_skill * 0.05
		if networking_points >= GameData.NETWORKING_VIBE_THRESHOLD:
			vibe_base += GameData.NETWORKING_VIBE_BONUS
		if mock_interview_buff:
			vibe_base += GameData.MOCK_INTERVIEW_VIBE_BONUS
			mock_interview_buff = false
		if hot_skill == GameData.SkillType.INTERVIEW:
			vibe_base += 0.05
		# V3: 得体的衬衫+8%, 面霸+10%, 社牛+5%
		if has_tool("nice_shirt"):
			vibe_base += 0.08
		if has_trait("mianba"):
			vibe_base += 0.10
		if has_trait("social_butterfly"):
			vibe_base += 0.05
		vibe_base = clampf(vibe_base, 0.10, 0.90)

		# V2: 作品集加成（重平衡数值）
		var portfolio_pts: int
		if job.skill_type == GameData.SkillType.SYSTEM:
			portfolio_pts = portfolio_system
		else:
			portfolio_pts = portfolio_application
		var portfolio_mult: float = GameData.PORTFOLIO_VIBE_MULT[portfolio_pts]

		# "被问住"风险
		var primary_skill: int = skills[job.skill_type] as int
		var skill_gap := listing.actual_skill_required - primary_skill
		var backfired := false
		if skill_gap >= 2 and portfolio_pts >= 2 and randf() < 0.10:
			portfolio_mult = 0.90
			backfired = true

		var vibe_rate := clampf(vibe_base * portfolio_mult, 0.05, 0.95)
		var vibe_pass := randf() < vibe_rate

		# 竞争判定（V2: 热门技能降低竞争）
		var comp_rate := 0.65
		if listing.actual_skill_required >= 8:
			comp_rate = 0.40
		elif listing.actual_skill_required >= 5:
			comp_rate = 0.55
		if market_downturn_weeks_left > 0:
			comp_rate *= 0.85
		if _is_job_hot(listing):
			comp_rate = minf(comp_rate + GameData.HOT_SKILL_COMPETITION_BONUS, 0.95)
		var comp_pass := randf() < comp_rate

		# V3: 面霸追踪
		if vibe_pass:
			_vibe_pass_count += 1

		if vibe_pass and comp_pass:
			app.status = GameData.ApplicationStatus.OFFER
			app.offer_weeks_left = GameData.OFFER_VALIDITY_WEEKS
			# V3: 谈判专家+10%薪资
			var offer_salary := listing.actual_salary
			if has_trait("negotiator"):
				offer_salary = int(offer_salary * 1.10)
				listing.actual_salary = offer_salary
			# V3: 谈判专家检测（拿到比拒绝过的更高的offer）
			if _has_rejected_offer and offer_salary > _highest_rejected_salary and not has_trait("negotiator"):
				_check_and_grant_trait("negotiator", result)
			result.notifications.append(
				"🎉 恭喜！%s [%s] 向您发出了 Offer！（周薪 $%d，%d 周内有效）" % [
					job.title, company, offer_salary, app.offer_weeks_left])
		elif not vibe_pass:
			app.status = GameData.ApplicationStatus.REJECTED
			if backfired:
				var bf_msg: String = _PORTFOLIO_BACKFIRE[randi() % _PORTFOLIO_BACKFIRE.size()]
				result.notifications.append("❌ %s [%s]（vibe %.0f%%未通过）：%s" % [job.title, company, vibe_rate * 100, bf_msg])
			else:
				var msg: String = _INTERVIEW_VIBE[randi() % _INTERVIEW_VIBE.size()]
				result.notifications.append("❌ %s [%s]（vibe %.0f%%未通过）：%s" % [job.title, company, vibe_rate * 100, msg])
		else:
			app.status = GameData.ApplicationStatus.REJECTED
			var msg: String = _INTERVIEW_COMPETITION[randi() % _INTERVIEW_COMPETITION.size()]
			result.notifications.append("❌ %s [%s]（竞争 %.0f%%未通过）：%s" % [job.title, company, comp_rate * 100, msg])

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

	# 6.5 V3: 工具被动效果
	# 二手iPad: 在职时每周自动+0.5XP到随机技能
	if has_tool("ipad") and current_job_listing:
		var random_skills := [
			GameData.SkillType.SYSTEM, GameData.SkillType.APPLICATION,
			GameData.SkillType.CPP, GameData.SkillType.INTERVIEW,
			GameData.SkillType.ENGLISH]
		var chosen_skill: GameData.SkillType = random_skills[randi() % random_skills.size()]
		if skills[chosen_skill] < GameData.MAX_SKILL_LEVEL:
			_add_skill_xp(chosen_skill, 0.5)
			result.notifications.append("📱 iPad通勤学习：+0.5 %s XP" % _skill_name(chosen_skill))

	# 共享办公月卡: 每周自动+0.5人脉（取整逻辑：2周+1）
	if has_tool("coworking") and networking_points < GameData.MAX_NETWORKING_POINTS:
		# 偶数周+1人脉（等效每周+0.5）
		if week % 2 == 0:
			networking_points = mini(networking_points + 1, GameData.MAX_NETWORKING_POINTS)

	# 6.6 V3: 特质检查
	_check_traits(result)

	# 6.7 V3: 海王周追踪
	if _weekly_apply_count >= 3:
		_triple_apply_weeks += 1

	# 6.8 V3: 卷王周追踪
	if _weekly_study_total >= 4:
		_study_streak_weeks += 1
	else:
		_study_streak_weeks = 0

	# 6.9 V3: 细水长流追踪
	if cash > 3000:
		_cash_above_3000_weeks += 1
	else:
		_cash_above_3000_weeks = 0

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

	# 10. 推进到下一周 & 重置
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
	shop_visited_this_week = false

	# 11. 检查市场刷新
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
	var neg_mult := 1.3 if market_downturn_weeks_left > 0 else 1.0
	var pool: Array = []

	# V3: 降噪耳机免疫电脑坏和低烧
	var immune_computer := has_tool("headphones")
	var sick_mult := 2.0 if has_trait("juanwang") else 1.0  # V3: 卷王加倍低烧概率
	if not immune_computer:
		pool.append(["computer_broke", int(3.0 * neg_mult)])
	pool.append(["rent_increase",  int(2.0 * neg_mult)])
	if not immune_computer:
		pool.append(["sick",           int(2.0 * neg_mult * sick_mult)])
	else:
		pool.append(["sick",           int(1.0 * neg_mult * sick_mult)])  # 减半但卷王仍翻倍

	var has_interview_app := false
	var has_applied_app   := false
	for lid: String in applications:
		var app: GameData.JobApplication = applications[lid]
		if app.status == GameData.ApplicationStatus.HAS_INTERVIEW:
			has_interview_app = true
		if app.status == GameData.ApplicationStatus.APPLIED:
			has_applied_app = true

	if has_interview_app:
		pool.append(["interview_ghosted", int(1.0 * neg_mult)])
	if has_applied_app:
		pool.append(["app_dropped",       int(1.0 * neg_mult)])

	pool.append(["freelance_gig",     3])
	pool.append(["good_mood",         2])
	pool.append(["cheap_food",        2])
	pool.append(["flash_inspiration", 2])

	if networking_points >= 1:
		var ref_weight := 4
		if networking_points >= 7:
			ref_weight = 12
		elif networking_points >= 4:
			ref_weight = 8
		pool.append(["referral", ref_weight])

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
				return
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
			result.event_desc = "下周学习疲劳阈值+1，每项技能可多学一次全效！"
			_fatigue_bonus_next_week = 1
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
		if applications.has(listing.listing_id):
			var app: GameData.JobApplication = applications[listing.listing_id]
			if app.status != GameData.ApplicationStatus.REJECTED:
				continue
		eligible.append(listing)
	if eligible.is_empty():
		return null

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
#  V3: 特质检查与授予
# ════════════════════════════════════════

func _check_traits(result: WeekSettlement) -> void:
	# 卷王：连续3周学习≥4次
	if not has_trait("juanwang") and _study_streak_weeks >= 3:
		_check_and_grant_trait("juanwang", result)

	# 速通达人：任意技能从0→5在≤4周内
	if not has_trait("speedrun"):
		for st in _skill_first_learn_week:
			var start_week: int = _skill_first_learn_week[st]
			if skills[st] >= 5 and week - start_week <= 4:
				_speedrun_skill = st
				_check_and_grant_trait("speedrun", result)
				break

	# 全栈选手：系统≥4 且 应用≥4
	if not has_trait("fullstack"):
		if skills[GameData.SkillType.SYSTEM] >= 4 and skills[GameData.SkillType.APPLICATION] >= 4:
			_check_and_grant_trait("fullstack", result)

	# 面霸：累计通过3次vibe
	if not has_trait("mianba") and _vibe_pass_count >= 3:
		_check_and_grant_trait("mianba", result)

	# 海王：累计2次单周投3份
	if not has_trait("haiwang") and _triple_apply_weeks >= 2:
		_check_and_grant_trait("haiwang", result)

	# 细水长流：连续4周>$3000
	if not has_trait("conservative") and _cash_above_3000_weeks >= 4:
		_check_and_grant_trait("conservative", result)

	# 斜杠青年：累计零工/私活≥8次
	if not has_trait("slasher") and _total_gig_count >= 8:
		_check_and_grant_trait("slasher", result)

	# 背水一战：现金<$500（条件特质，可失去）
	if not has_trait("desperate") and cash < 500 and cash >= 0:
		_check_and_grant_trait("desperate", result)
	elif has_trait("desperate") and cash > 1500:
		active_traits.erase("desperate")
		result.lost_traits.append("desperate")

	# 社牛：人脉≥7
	if not has_trait("social_butterfly") and networking_points >= 7:
		_check_and_grant_trait("social_butterfly", result)

	# 开源达人：作品集≥2 且 人脉≥3
	if not has_trait("opensource_pro"):
		if maxi(portfolio_system, portfolio_application) >= 2 and networking_points >= 3:
			_check_and_grant_trait("opensource_pro", result)

	# 圈内人：内推获面试≥2次
	if not has_trait("insider") and _referral_interview_count >= 2:
		_check_and_grant_trait("insider", result)


func _check_and_grant_trait(trait_id: String, result: WeekSettlement) -> void:
	if has_trait(trait_id):
		return
	active_traits.append(trait_id)
	result.new_traits.append(trait_id)


## 追踪技能开始学习时间（速通达人用）
func _track_skill_start(skill_type: GameData.SkillType) -> void:
	if not _skill_first_learn_week.has(skill_type):
		if skills[skill_type] == 0:
			_skill_first_learn_week[skill_type] = week


## 技能名称（内部使用）
func _skill_name(skill_type: GameData.SkillType) -> String:
	match skill_type:
		GameData.SkillType.SYSTEM: return "系统开发"
		GameData.SkillType.APPLICATION: return "应用开发"
		GameData.SkillType.CPP: return "C++"
		GameData.SkillType.INTERVIEW: return "面试技巧"
		GameData.SkillType.ENGLISH: return "英语"
		_: return ""


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
#  市场刷新 & 热门技能
# ════════════════════════════════════════

func _refresh_job_market() -> void:
	var bias_roll := randi() % 3
	market_bias = bias_roll as GameData.MarketBias

	# V2: 随机热门技能
	var all_skills := [
		GameData.SkillType.SYSTEM, GameData.SkillType.APPLICATION,
		GameData.SkillType.CPP, GameData.SkillType.INTERVIEW,
		GameData.SkillType.ENGLISH,
	]
	hot_skill = all_skills[randi() % all_skills.size()]

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


## 热门技能名称
func get_hot_skill_name() -> String:
	match hot_skill:
		GameData.SkillType.SYSTEM:
			return "系统开发"
		GameData.SkillType.APPLICATION:
			return "应用开发"
		GameData.SkillType.CPP:
			return "C++"
		GameData.SkillType.INTERVIEW:
			return "面试技巧"
		GameData.SkillType.ENGLISH:
			return "英语"
		_:
			return ""


# ════════════════════════════════════════
#  V2: 通过率计算（公开，供UI调用）
# ════════════════════════════════════════

## 计算简历通过率（不含10%鬼了的概率）
func calc_resume_pass_rate(listing: GameData.JobListing, modifier: float = 1.0) -> float:
	var job := listing.job
	var base := 0.55

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

	# V2: 热门技能英语效果
	var effective_eng_req := _effective_english_req(listing)
	var eng_diff: int = (skills[GameData.SkillType.ENGLISH] as int) - effective_eng_req
	var english_mod := clampf(eng_diff * 0.04, -0.12, 0.08)

	var cpp_mod := 0.0
	if job.skill_type == GameData.SkillType.SYSTEM and listing.actual_cpp_required > 0:
		var cpp_diff: int = (skills[GameData.SkillType.CPP] as int) - listing.actual_cpp_required
		cpp_mod = clampf(cpp_diff * 0.04, -0.12, 0.08)

	# V2: 作品集加成（重平衡值）
	var portfolio_pts: int
	if job.skill_type == GameData.SkillType.SYSTEM:
		portfolio_pts = portfolio_system
	else:
		portfolio_pts = portfolio_application
	var portfolio_bonus := portfolio_pts * GameData.PORTFOLIO_RESUME_BONUS_PER

	# V3: 付费简历模板+5%
	var template_bonus := 0.05 if has_tool("resume_template") else 0.0
	# V3: 圈内人特质 → 内推倍率从1.5→2.0
	var final_modifier := modifier
	if has_trait("insider") and modifier > 1.0:
		final_modifier = 2.0
	# V3: 背水一战+20%
	var desperate_bonus := 0.0
	if has_trait("desperate"):
		desperate_bonus = 0.10
	return clampf((base + primary_mod + english_mod + cpp_mod + portfolio_bonus + template_bonus + desperate_bonus) * final_modifier, 0.05, 0.88)


## 计算面试通过率（返回 vibe/competition/total）
func calc_interview_pass_rate(listing: GameData.JobListing) -> Dictionary:
	var job := listing.job
	var interview_skill: int = skills[GameData.SkillType.INTERVIEW]
	var vibe_base := 0.40 + interview_skill * 0.05
	if networking_points >= GameData.NETWORKING_VIBE_THRESHOLD:
		vibe_base += GameData.NETWORKING_VIBE_BONUS
	if mock_interview_buff:
		vibe_base += GameData.MOCK_INTERVIEW_VIBE_BONUS
	if hot_skill == GameData.SkillType.INTERVIEW:
		vibe_base += 0.05
	# V3: 得体的衬衫+8%, 面霸+10%, 社牛+5%
	if has_tool("nice_shirt"):
		vibe_base += 0.08
	if has_trait("mianba"):
		vibe_base += 0.10
	if has_trait("social_butterfly"):
		vibe_base += 0.05
	vibe_base = clampf(vibe_base, 0.10, 0.90)

	var portfolio_pts: int
	if job.skill_type == GameData.SkillType.SYSTEM:
		portfolio_pts = portfolio_system
	else:
		portfolio_pts = portfolio_application
	var portfolio_mult: float = GameData.PORTFOLIO_VIBE_MULT[portfolio_pts]
	var vibe_rate := clampf(vibe_base * portfolio_mult, 0.05, 0.95)

	var comp_rate := 0.65
	if listing.actual_skill_required >= 8:
		comp_rate = 0.40
	elif listing.actual_skill_required >= 5:
		comp_rate = 0.55
	if market_downturn_weeks_left > 0:
		comp_rate *= 0.85
	if _is_job_hot(listing):
		comp_rate = minf(comp_rate + GameData.HOT_SKILL_COMPETITION_BONUS, 0.95)

	return {"vibe": vibe_rate, "competition": comp_rate, "total": vibe_rate * comp_rate}


## 热门技能是否利好该岗位
func _is_job_hot(listing: GameData.JobListing) -> bool:
	match hot_skill:
		GameData.SkillType.SYSTEM, GameData.SkillType.CPP:
			return listing.job.skill_type == GameData.SkillType.SYSTEM
		GameData.SkillType.APPLICATION:
			return listing.job.skill_type == GameData.SkillType.APPLICATION
		_:
			return true


## 有效英语要求（热门英语时 -1）
func _effective_english_req(listing: GameData.JobListing) -> int:
	var req := listing.actual_english_required
	if hot_skill == GameData.SkillType.ENGLISH:
		req = maxi(0, req - 1)
	return req


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
