## 主界面控制器（V4: 公司系统/市场风向/市场事件）
extends Control

@onready var header_label: RichTextLabel = %HeaderLabel
@onready var status_label: RichTextLabel = %StatusLabel
@onready var job_progress_label: RichTextLabel = %JobProgressLabel
@onready var action_list: VBoxContainer = %ActionList
@onready var settlement_panel: Panel = %SettlementPanel
@onready var settlement_label: RichTextLabel = %SettlementLabel
@onready var ending_panel: Panel = %EndingPanel
@onready var ending_label: RichTextLabel = %EndingLabel
@onready var sub_menu_panel: Panel = %SubMenuPanel
@onready var sub_menu_list: VBoxContainer = %SubMenuList
@onready var sub_menu_title: Label = %SubMenuTitle

var game: GameState
var _apply_selection: Dictionary = {}  # listing_id -> bool
var _shop_mode: bool = false           # V3: 当前子菜单是否是商店
var _replacing_tool_id: String = ""    # V3: 正在替换哪个新工具（背包满时）
var _company_mode: bool = false        # V4: 当前子菜单是否是公司列表
var _selected_company: GameData.CompanyDef = null  # V4: 当前选中的公司

func _ready() -> void:
	game = GameState.new()
	settlement_panel.visible = false
	ending_panel.visible = false
	sub_menu_panel.visible = false
	_refresh_ui()


# ════════════════════════════════════════
#  UI 刷新
# ════════════════════════════════════════

func _refresh_ui() -> void:
	_update_header()
	_update_status()
	_update_job_progress()
	_update_action_list()


func _update_header() -> void:
	var hot := game.get_hot_skill_name()
	var header := "第 %d 周 / %d 周    现金: $%s    🔥热门：%s" % [
		game.week, GameData.MAX_WEEKS, _format_number(game.cash), hot]
	var wind := game.get_wind_text()
	if wind != "":
		header += "    📊 风向：%s" % wind
	var event := game.get_market_event_text()
	if event != "":
		header += "\n⚡ 市场事件：%s" % event
	header_label.text = header


func _update_status() -> void:
	var s := game.skills
	var ST := GameData.SkillType
	var free_energy := game.get_free_energy()

	var job_text := "失业"
	if game.current_job_listing:
		job_text = "在职 - %s（周薪 $%d，占用 %d 能量）" % [
			game.current_job_listing.job.title,
			game.current_job_listing.actual_salary,
			game.current_job_listing.job.energy_cost]
		if game.pending_quit:
			job_text += " [已提辞职]"

	# V2: 人脉被动效果提示
	var net_effects: Array[String] = []
	if game.networking_points >= GameData.NETWORKING_VIBE_THRESHOLD:
		net_effects.append("面试+5%")
	if game.networking_points >= GameData.NETWORKING_APPLY_THRESHOLD:
		net_effects.append("海投-1档")
	var net_text := " [%s]" % ", ".join(net_effects) if net_effects.size() > 0 else ""

	# 状态效果
	var effects: Array[String] = []
	if game.market_downturn_weeks_left > 0:
		effects.append("📉 寒冬中（剩 %d 周）" % game.market_downturn_weeks_left)
	if game.current_market_event != null and game.market_event_weeks_left > 0:
		effects.append("⚡ %s（剩 %d 周）" % [game.current_market_event.name, game.market_event_weeks_left])
	if game.fatigue_bonus_this_week > 0:
		effects.append("💡 疲劳+%d" % game.fatigue_bonus_this_week)
	if game.mock_interview_buff:
		effects.append("🎯 模拟面试")
	var effects_line := ("    " + "  |  ".join(effects)) if effects.size() > 0 else ""

	# V2: 作品集开源进度
	var sys_pf := "%d/%d" % [game.portfolio_system, GameData.MAX_PORTFOLIO_POINTS]
	if game.portfolio_system < GameData.MAX_PORTFOLIO_POINTS and game.portfolio_xp_system > 0:
		sys_pf += "(+%d/%d)" % [game.portfolio_xp_system, GameData.PORTFOLIO_XP_NEEDED]
	var app_pf := "%d/%d" % [game.portfolio_application, GameData.MAX_PORTFOLIO_POINTS]
	if game.portfolio_application < GameData.MAX_PORTFOLIO_POINTS and game.portfolio_xp_application > 0:
		app_pf += "(+%d/%d)" % [game.portfolio_xp_application, GameData.PORTFOLIO_XP_NEEDED]

	# V3: 工具行
	var tool_texts: Array[String] = []
	for tid in game.owned_tools:
		var tdef := game._find_tool_def(tid)
		if tdef:
			var cost_text := "(-$%d/周)" % tdef.weekly_cost if tdef.weekly_cost > 0 else ""
			tool_texts.append("%s%s%s" % [tdef.icon, tdef.name, cost_text])
	var tools_line := "🧰 工具 [%d/%d]：%s" % [
		game.owned_tools.size(), GameData.MAX_TOOLS,
		"  ".join(tool_texts) if tool_texts.size() > 0 else "无"]

	# V3: 特质行
	var trait_texts: Array[String] = []
	for tid in game.active_traits:
		var tdef := game._find_trait_def(tid)
		if tdef:
			trait_texts.append("「%s」" % tdef.name)
	var traits_line := "🏷️ 特质：%s" % (
		"  ".join(trait_texts) if trait_texts.size() > 0 else "无")

	status_label.text = (
		"专业：系统 Lv.%d(%s)  应用 Lv.%d(%s)  C++ Lv.%d(%s)\n" % [
			s[ST.SYSTEM], game.get_skill_xp_progress(ST.SYSTEM),
			s[ST.APPLICATION], game.get_skill_xp_progress(ST.APPLICATION),
			s[ST.CPP], game.get_skill_xp_progress(ST.CPP)] +
		"通用：面试技巧 Lv.%d(%s)  英语 Lv.%d(%s)\n" % [
			s[ST.INTERVIEW], game.get_skill_xp_progress(ST.INTERVIEW),
			s[ST.ENGLISH], game.get_skill_xp_progress(ST.ENGLISH)] +
		"人脉：%d/%d%s    作品集：系统 %s  应用 %s\n" % [
			game.networking_points, GameData.MAX_NETWORKING_POINTS, net_text,
			sys_pf, app_pf] +
		"%s\n" % tools_line +
		"%s\n" % traits_line +
		"状态：%s\n" % job_text +
		"可用能量：%d / %d    市场：%s%s" % [
			free_energy, game.energy, game.get_market_bias_text(), effects_line]
	)


func _update_job_progress() -> void:
	if game.applications.is_empty():
		job_progress_label.text = "（无求职进度）"
		return
	var lines: Array[String] = []
	for listing_id in game.applications:
		var app: GameData.JobApplication = game.applications[listing_id]
		var status_text := ""
		match app.status:
			GameData.ApplicationStatus.APPLIED:
				status_text = "已投递，等待回复"
			GameData.ApplicationStatus.HAS_INTERVIEW:
				status_text = "有面试机会 ✦"
			GameData.ApplicationStatus.INTERVIEWED:
				status_text = "已面试，等待结果"
			GameData.ApplicationStatus.OFFER:
				status_text = "收到 Offer（剩余 %d 周）" % app.offer_weeks_left
			GameData.ApplicationStatus.REJECTED:
				status_text = "已拒绝"
		if app.status != GameData.ApplicationStatus.REJECTED:
			var modifier_text := ""
			if app.apply_penalty > 1.0:
				modifier_text = " [内推+50%%]"
			elif app.apply_penalty < 1.0:
				modifier_text = " [海投×%.0f%%]" % (app.apply_penalty * 100)
			lines.append("· %s [%s]%s — %s" % [app.listing.job.title, app.listing.company, modifier_text, status_text])
	job_progress_label.text = "\n".join(lines) if lines.size() > 0 else "（无求职进度）"


# ════════════════════════════════════════
#  V2: 行动列表（分区 + 细化）
# ════════════════════════════════════════

func _update_action_list() -> void:
	for child in action_list.get_children():
		child.queue_free()

	var free := game.get_free_energy()
	var ST := GameData.SkillType

	# ── 学习 ──
	_add_section_header("── 学习 ──")

	# 系统: 看文档 / 刷题 / 做开源
	_add_docs_btn("看文档·系统开发", ST.SYSTEM, free)
	_add_practice_btn("刷题·系统开发", ST.SYSTEM, free)
	_add_opensource_btn("做开源·系统开发", ST.SYSTEM, free)

	# 应用: 看文档 / 刷题 / 做开源
	_add_docs_btn("看文档·应用开发", ST.APPLICATION, free)
	_add_practice_btn("刷题·应用开发", ST.APPLICATION, free)
	_add_opensource_btn("做开源·应用开发", ST.APPLICATION, free)

	# C++: 看文档 / 刷题
	_add_docs_btn("看文档·C++", ST.CPP, free)
	_add_practice_btn("刷题·C++", ST.CPP, free)

	# 面试: 看面经 / 模拟面试
	_add_docs_btn("看面经", ST.INTERVIEW, free)
	var mock_text := "模拟面试（-2EP，+1XP，下次面试vibe+10%%）"
	var mock_can := free >= GameData.MOCK_INTERVIEW_ENERGY and game.get_skill(ST.INTERVIEW) < GameData.MAX_SKILL_LEVEL
	_add_action_button(mock_text, mock_can, _on_mock_interview)

	# 英语: 背单词 / 英语角
	_add_docs_btn("背单词", ST.ENGLISH, free)
	var corner_text := "参加英语角（-2EP，+1英语XP +1人脉）"
	_add_action_button(corner_text, free >= GameData.ENGLISH_CORNER_ENERGY, _on_english_corner)

	# ── 工作 ──
	_add_section_header("── 工作 ──")

	_add_action_button(
		"兼职零工（-3EP，+$%d）" % _calc_gig_display(GameData.GIG_INCOME_PARTTIME),
		free >= GameData.GIG_ENERGY_PARTTIME, _on_gig_parttime)
	_add_action_button(
		"全职零工（-5EP，+$%d）" % _calc_gig_display(GameData.GIG_INCOME_FULLTIME),
		free >= GameData.GIG_ENERGY_FULLTIME, _on_gig_fulltime)

	# V2: 技术私活
	var max_primary := maxi(game.get_skill(ST.SYSTEM), game.get_skill(ST.APPLICATION))
	if max_primary >= GameData.TECH_FREELANCE_MIN_SKILL:
		var fl_income := game.get_tech_freelance_income()
		_add_action_button(
			"技术私活（-2EP，+$%d）" % fl_income,
			free >= GameData.TECH_FREELANCE_ENERGY, _on_tech_freelance)
	else:
		_add_action_button(
			"技术私活（需要专业技能≥%d）" % GameData.TECH_FREELANCE_MIN_SKILL,
			false, Callable())

	# V3: 远程兼职（需要ThinkPad）
	if game.has_tool("thinkpad"):
		_add_action_button(
			"远程兼职（-2EP，+$%d）" % game.get_remote_gig_income(),
			free >= GameData.REMOTE_GIG_ENERGY, _on_remote_gig)

	# V3: 逛二手市场
	var shop_text := "逛二手市场（-1EP，浏览可购买工具）"
	if game.shop_visited_this_week:
		shop_text = "逛二手市场（本周已逛过）"
	_add_action_button(shop_text,
		free >= GameData.SHOP_ENERGY_COST and not game.shop_visited_this_week, _on_browse_shop)

	# ── 社交与求职 ──
	_add_section_header("── 社交与求职 ──")

	var net_full := game.networking_points >= GameData.MAX_NETWORKING_POINTS
	var net_gain := 2 if game.has_tool("linkedin") else 1
	_add_action_button(
		"维护人脉（-1EP，人脉 %d → %d/%d）%s" % [
			game.networking_points,
			mini(game.networking_points + net_gain, GameData.MAX_NETWORKING_POINTS),
			GameData.MAX_NETWORKING_POINTS,
			" 🔗+1" if game.has_tool("linkedin") else ""],
		free >= 1 and not net_full, _on_networking)

	_add_portfolio_btn(ST.SYSTEM, free)
	_add_portfolio_btn(ST.APPLICATION, free)

	# 投递简历
	var apply_hint := ""
	if game.networking_points >= GameData.NETWORKING_APPLY_THRESHOLD:
		apply_hint = "，人脉加成：惩罚-1档"
	_add_action_button("投递简历（-1EP，可投1-3家%s）" % apply_hint, free >= 1, _on_apply)

	# 面试按钮
	for listing_id in game.applications:
		var app: GameData.JobApplication = game.applications[listing_id]
		if app.status == GameData.ApplicationStatus.HAS_INTERVIEW:
			var rates := game.calc_interview_pass_rate(app.listing)
			var btn_text := "参加面试：%s [%s]（-2EP，通过率≈%.0f%%）" % [
				app.listing.job.title, app.listing.company, rates["total"] * 100]
			_add_action_button(btn_text, free >= 2, _on_interview.bind(listing_id))

	# Offer 操作
	for listing_id in game.applications:
		var app: GameData.JobApplication = game.applications[listing_id]
		if app.status == GameData.ApplicationStatus.OFFER:
			_add_action_button(
				"接受 Offer：%s [%s]（$%d/周）" % [app.listing.job.title, app.listing.company, app.listing.actual_salary],
				true, _on_accept_offer.bind(listing_id))
			_add_action_button(
				"拒绝 Offer：%s [%s]" % [app.listing.job.title, app.listing.company],
				true, _on_reject_offer.bind(listing_id))

	# 辞职
	if game.current_job_listing and not game.pending_quit:
		_add_action_button("辞职", true, _on_quit)

	# V3: 查看特质进度（不花能量）
	_add_action_button("查看特质进度", true, _on_show_traits)

	# V4: 查看公司列表
	_add_action_button("查看公司列表", true, _on_show_companies)

	_add_action_button(">>> 结束本周 <<<", true, _on_end_week)


# ── 按钮工厂 ──

func _add_section_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.85, 1))
	label.add_theme_font_size_override("font_size", 16)
	action_list.add_child(label)


func _add_docs_btn(label: String, skill_type: GameData.SkillType, free: int) -> void:
	var progress := game.get_skill_xp_progress(skill_type)
	var maxed := game.get_skill(skill_type) >= GameData.MAX_SKILL_LEVEL
	var fatigue := game.get_docs_fatigue(skill_type)
	var hot := " 🔥" if skill_type == game.hot_skill else ""

	if maxed:
		_add_action_button("%s（MAX）" % label, false, Callable())
		return

	var fatigue_text := ""
	var can := free >= 1
	match fatigue:
		"half":
			fatigue_text = " ⚡半效"
		"blocked":
			fatigue_text = " — 本周已疲劳"
			can = false

	# V3: 机械键盘加成提示
	var kb_hint := " ⌨+0.5" if game.has_tool("mech_keyboard") else ""
	_add_action_button(
		"%s（-1EP，进度 %s）%s%s%s" % [label, progress, hot, kb_hint, fatigue_text],
		can, _on_study_docs.bind(skill_type))


func _add_practice_btn(label: String, skill_type: GameData.SkillType, free: int) -> void:
	var maxed := game.get_skill(skill_type) >= GameData.MAX_SKILL_LEVEL
	var hot := " 🔥" if skill_type == game.hot_skill else ""
	# V3: LeetCode会员加成显示
	var xp_range := "随机0~2XP"
	if game.has_tool("leetcode"):
		xp_range = "随机1~3XP"
	_add_action_button(
		"%s（-1EP，%s）%s" % [label, xp_range, hot],
		free >= 1 and not maxed, _on_study_practice.bind(skill_type))


func _add_opensource_btn(label: String, skill_type: GameData.SkillType, free: int) -> void:
	var maxed := game.get_skill(skill_type) >= GameData.MAX_SKILL_LEVEL
	var hot := " 🔥" if skill_type == game.hot_skill else ""
	var pts: int = game.portfolio_system if skill_type == GameData.SkillType.SYSTEM else game.portfolio_application
	var pf_full := pts >= GameData.MAX_PORTFOLIO_POINTS
	var pf_text := " +0.5作品集" if not pf_full else ""
	# V3: Copilot减少EP
	var os_cost := GameData.OPENSOURCE_ENERGY
	if game.has_tool("copilot"):
		os_cost = 1
	var net_text := ""
	if game.has_trait("opensource_pro"):
		net_text = " +1人脉"
	_add_action_button(
		"%s（-%dEP，+1XP%s%s）%s" % [label, os_cost, pf_text, net_text, hot],
		free >= os_cost and not maxed, _on_study_opensource.bind(skill_type))


func _add_portfolio_btn(skill_type: GameData.SkillType, free: int) -> void:
	var direction := "系统" if skill_type == GameData.SkillType.SYSTEM else "应用"
	var pts := game.portfolio_system if skill_type == GameData.SkillType.SYSTEM else game.portfolio_application
	var maxed := pts >= GameData.MAX_PORTFOLIO_POINTS
	var label := "做个人项目·%s（-3EP，作品集 %d → %d/%d）" % [
		direction, pts, mini(pts + 1, GameData.MAX_PORTFOLIO_POINTS), GameData.MAX_PORTFOLIO_POINTS]
	_add_action_button(label, free >= GameData.PORTFOLIO_ENERGY_COST and not maxed,
		_on_portfolio.bind(skill_type))


func _add_action_button(text: String, enabled: bool, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.disabled = not enabled
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if callback.is_valid():
		btn.pressed.connect(callback)
	btn.add_theme_font_size_override("font_size", 18)
	action_list.add_child(btn)


# ════════════════════════════════════════
#  行动回调
# ════════════════════════════════════════

func _on_study_docs(skill_type: GameData.SkillType) -> void:
	game.action_study_docs(skill_type)
	_refresh_ui()

func _on_study_practice(skill_type: GameData.SkillType) -> void:
	game.action_study_practice(skill_type)
	_refresh_ui()

func _on_study_opensource(skill_type: GameData.SkillType) -> void:
	game.action_study_opensource(skill_type)
	_refresh_ui()

func _on_mock_interview() -> void:
	game.action_mock_interview()
	_refresh_ui()

func _on_english_corner() -> void:
	game.action_english_corner()
	_refresh_ui()

func _on_gig_parttime() -> void:
	game.action_gig_parttime()
	_refresh_ui()

func _on_gig_fulltime() -> void:
	game.action_gig_fulltime()
	_refresh_ui()

func _on_tech_freelance() -> void:
	game.action_tech_freelance()
	_refresh_ui()

func _on_apply() -> void:
	_apply_selection.clear()
	_show_apply_menu()

func _on_interview(listing_id: String) -> void:
	game.action_interview(listing_id)
	_refresh_ui()

func _on_accept_offer(listing_id: String) -> void:
	game.action_accept_offer(listing_id)
	_refresh_ui()

func _on_reject_offer(listing_id: String) -> void:
	game.action_reject_offer(listing_id)
	_refresh_ui()

func _on_networking() -> void:
	game.action_networking()
	_refresh_ui()

func _on_portfolio(skill_type: GameData.SkillType) -> void:
	game.action_portfolio(skill_type)
	_refresh_ui()

func _on_quit() -> void:
	game.action_quit()
	_refresh_ui()

func _on_remote_gig() -> void:
	game.action_remote_gig()
	_refresh_ui()

func _on_browse_shop() -> void:
	game.action_browse_shop()
	_shop_mode = true
	_replacing_tool_id = ""
	_show_shop_menu()


# ════════════════════════════════════════
#  V3: 工具商店
# ════════════════════════════════════════

func _show_shop_menu() -> void:
	sub_menu_panel.visible = true
	_rebuild_shop_menu()


func _rebuild_shop_menu() -> void:
	sub_menu_title.text = "二手市场    背包：%d/%d    现金：$%s" % [
		game.owned_tools.size(), GameData.MAX_TOOLS, _format_number(game.cash)]

	for child in sub_menu_list.get_children():
		child.queue_free()

	if _replacing_tool_id != "":
		# 替换模式：选择要丢弃的旧工具
		var new_tdef := game._find_tool_def(_replacing_tool_id)
		var hint_label := Label.new()
		hint_label.text = "背包已满！选择要替换的工具（将丢弃旧工具，购买「%s」$%d）：" % [
			new_tdef.name, new_tdef.price]
		hint_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 1))
		hint_label.add_theme_font_size_override("font_size", 16)
		sub_menu_list.add_child(hint_label)

		for tid in game.owned_tools:
			var tdef := game._find_tool_def(tid)
			if tdef:
				var cost_text := "（-$%d/周）" % tdef.weekly_cost if tdef.weekly_cost > 0 else ""
				var btn := Button.new()
				btn.text = "丢弃 %s%s %s%s" % [tdef.icon, tdef.name, cost_text, tdef.description]
				btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				btn.pressed.connect(_on_confirm_replace.bind(tid))
				btn.add_theme_font_size_override("font_size", 16)
				sub_menu_list.add_child(btn)

		var cancel_btn := Button.new()
		cancel_btn.text = "取消"
		cancel_btn.pressed.connect(_on_cancel_replace)
		cancel_btn.add_theme_font_size_override("font_size", 16)
		sub_menu_list.add_child(cancel_btn)
		return

	# 正常商店模式
	for tid in game.shop_available_tools:
		var tdef := game._find_tool_def(tid)
		if tdef == null:
			continue
		var already_owned := game.owned_tools.has(tid)
		var can_afford := game.cash >= tdef.price

		var cost_line := ""
		if tdef.weekly_cost > 0:
			cost_line = "    持续费用：$%d/周" % tdef.weekly_cost

		var status := ""
		if already_owned:
			status = " [已拥有]"

		# 工具卡片用Label + Button
		var card_label := Label.new()
		card_label.text = "%s %s    $%d%s\n   %s%s\n   %s" % [
			tdef.icon, tdef.name, tdef.price, status,
			tdef.description, cost_line, tdef.hint]
		card_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
		card_label.add_theme_font_size_override("font_size", 16)
		sub_menu_list.add_child(card_label)

		if not already_owned:
			var buy_btn := Button.new()
			buy_btn.text = "购买 $%d" % tdef.price
			buy_btn.disabled = not can_afford
			buy_btn.pressed.connect(_on_buy_tool.bind(tid))
			buy_btn.add_theme_font_size_override("font_size", 16)
			sub_menu_list.add_child(buy_btn)

		# 分隔
		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 8)
		sub_menu_list.add_child(sep)

	# 已拥有工具列表
	if game.owned_tools.size() > 0:
		var owned_label := Label.new()
		var owned_names: Array[String] = []
		for tid in game.owned_tools:
			var tdef := game._find_tool_def(tid)
			if tdef:
				owned_names.append("%s%s" % [tdef.icon, tdef.name])
		owned_label.text = "已拥有：%s" % "  ".join(owned_names)
		owned_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6, 1))
		owned_label.add_theme_font_size_override("font_size", 16)
		sub_menu_list.add_child(owned_label)

	# V3: 查看特质按钮
	var trait_btn := Button.new()
	trait_btn.text = "查看特质进度"
	trait_btn.pressed.connect(_on_show_traits)
	trait_btn.add_theme_font_size_override("font_size", 16)
	sub_menu_list.add_child(trait_btn)

	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.pressed.connect(_on_close_sub_menu)
	back_btn.add_theme_font_size_override("font_size", 16)
	sub_menu_list.add_child(back_btn)


func _on_buy_tool(tool_id: String) -> void:
	if game.owned_tools.size() >= GameData.MAX_TOOLS:
		# 背包满，进入替换模式
		_replacing_tool_id = tool_id
		_rebuild_shop_menu()
		return
	game.action_buy_tool(tool_id)
	_rebuild_shop_menu()
	_refresh_ui()


func _on_confirm_replace(old_tool_id: String) -> void:
	game.action_replace_tool(old_tool_id, _replacing_tool_id)
	_replacing_tool_id = ""
	_rebuild_shop_menu()
	_refresh_ui()


func _on_cancel_replace() -> void:
	_replacing_tool_id = ""
	_rebuild_shop_menu()


# ════════════════════════════════════════
#  V3: 特质详情面板
# ════════════════════════════════════════

func _on_show_traits() -> void:
	sub_menu_panel.visible = true
	_shop_mode = false
	_rebuild_traits_panel()


func _rebuild_traits_panel() -> void:
	sub_menu_title.text = "你的特质"

	for child in sub_menu_list.get_children():
		child.queue_free()

	for tdef in game._all_traits:
		var owned := game.has_trait(tdef.id)
		var prefix := "✅" if owned else "🔒"
		var status_text := "" if owned else "（未解锁）"
		var progress := "" if owned else "    进度：%s" % game.get_trait_progress(tdef.id)
		var side := ""
		if tdef.side_effect_text != "":
			side = "\n    ⚠ 副作用：%s" % tdef.side_effect_text

		var label := Label.new()
		label.text = "%s 「%s」%s\n    条件：%s\n    效果：%s%s%s" % [
			prefix, tdef.name, status_text,
			tdef.condition_text, tdef.effect_text, side, progress]
		label.add_theme_font_size_override("font_size", 16)
		if owned:
			label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5, 1))
		else:
			label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		sub_menu_list.add_child(label)

		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 4)
		sub_menu_list.add_child(sep)

	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.pressed.connect(_on_close_sub_menu)
	back_btn.add_theme_font_size_override("font_size", 16)
	sub_menu_list.add_child(back_btn)


# ════════════════════════════════════════
#  V4: 公司列表
# ════════════════════════════════════════

func _on_show_companies() -> void:
	sub_menu_panel.visible = true
	_shop_mode = false
	_company_mode = true
	_selected_company = null
	_rebuild_company_panel()


func _rebuild_company_panel() -> void:
	for child in sub_menu_list.get_children():
		child.queue_free()

	if _selected_company != null:
		# 公司详情视图
		sub_menu_title.text = "公司详情 - %s" % _selected_company.name

		var info_label := Label.new()
		info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var scale_text := _selected_company.get_scale_text()
		var benefit_text := _selected_company.get_benefit_text()
		var status_text := _selected_company.get_status_text()
		var direction := "系统/后端" if _selected_company.preferred_skill == GameData.SkillType.SYSTEM else "前端/应用"

		# 统计该公司当前在市场上的岗位数
		var listing_count := 0
		for listing in game.current_listings:
			if listing.company_def.id == _selected_company.id:
				listing_count += 1

		info_label.text = (
			"公司名称：%s\n" % _selected_company.name +
			"公司规模：%s\n" % scale_text +
			"薪资福利：%s\n" % benefit_text +
			"经营状况：%s\n" % status_text +
			"主营方向：%s\n" % direction +
			"当前在招岗位：%d 个" % listing_count
		)
		info_label.add_theme_font_size_override("font_size", 18)
		info_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85, 1))
		sub_menu_list.add_child(info_label)

		# 列出该公司当前岗位
		if listing_count > 0:
			var sep := HSeparator.new()
			sep.add_theme_constant_override("separation", 8)
			sub_menu_list.add_child(sep)

			var jobs_header := Label.new()
			jobs_header.text = "── 在招岗位 ──"
			jobs_header.add_theme_color_override("font_color", Color(0.5, 0.7, 0.85, 1))
			jobs_header.add_theme_font_size_override("font_size", 16)
			sub_menu_list.add_child(jobs_header)

			for listing in game.current_listings:
				if listing.company_def.id == _selected_company.id:
					var skill_name := "系统" if listing.job.skill_type == GameData.SkillType.SYSTEM else "应用"
					var job_label := Label.new()
					job_label.text = "· %s | 要求%s%d 英%d $%d/周" % [
						listing.job.title, skill_name,
						listing.actual_skill_required,
						listing.actual_english_required,
						listing.actual_salary]
					job_label.add_theme_font_size_override("font_size", 16)
					job_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
					sub_menu_list.add_child(job_label)

		var back_btn := Button.new()
		back_btn.text = "返回公司列表"
		back_btn.pressed.connect(_on_back_to_company_list)
		back_btn.add_theme_font_size_override("font_size", 16)
		sub_menu_list.add_child(back_btn)
	else:
		# 公司列表视图
		sub_menu_title.text = "公司列表（共 %d 家）" % game.companies.size()

		for company in game.companies:
			var scale_text := company.get_scale_text()
			var status_text := company.get_status_text()
			var benefit_text := company.get_benefit_text()
			var direction := "系统" if company.preferred_skill == GameData.SkillType.SYSTEM else "应用"

			# 统计在招岗位
			var count := 0
			for listing in game.current_listings:
				if listing.company_def.id == company.id:
					count += 1

			var status_color := Color(0.6, 0.9, 0.6, 1)  # 良好=绿
			if company.business_status == GameData.BusinessStatus.STABLE:
				status_color = Color(0.9, 0.9, 0.5, 1)  # 维持=黄
			elif company.business_status == GameData.BusinessStatus.STRUGGLING:
				status_color = Color(0.9, 0.5, 0.5, 1)  # 艰难=红

			var btn := Button.new()
			btn.text = "%s  [%s]  福利:%s  经营:%s  方向:%s  在招:%d" % [
				company.name, scale_text, benefit_text, status_text, direction, count]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.pressed.connect(_on_select_company.bind(company))
			btn.add_theme_font_size_override("font_size", 16)
			sub_menu_list.add_child(btn)

		var close_btn := Button.new()
		close_btn.text = "返回"
		close_btn.pressed.connect(_on_close_sub_menu)
		close_btn.add_theme_font_size_override("font_size", 16)
		sub_menu_list.add_child(close_btn)


func _on_select_company(company: GameData.CompanyDef) -> void:
	_selected_company = company
	_rebuild_company_panel()


func _on_back_to_company_list() -> void:
	_selected_company = null
	_rebuild_company_panel()


# ════════════════════════════════════════
#  V2: 投递子菜单（含通过率显示）
# ════════════════════════════════════════

func _show_apply_menu() -> void:
	sub_menu_panel.visible = true
	_rebuild_apply_menu()


func _rebuild_apply_menu() -> void:
	# V2: 显示人脉加成提示
	var net_hint := ""
	if game.networking_points >= GameData.NETWORKING_APPLY_THRESHOLD:
		net_hint = "  ★人脉加成：惩罚降一档"
	sub_menu_title.text = "选择投递岗位（本期市场：%s）\n选1个：正常 | 选2个：×80%% | 选3个：×65%%（最多3个）%s" % [
		game.get_market_bias_text(), net_hint]

	for child in sub_menu_list.get_children():
		child.queue_free()

	var selected_count: int = _apply_selection.values().count(true)

	for listing in game.current_listings:
		var job := listing.job
		var player_primary: int = game.skills[job.skill_type]
		var skill_name := "系统" if job.skill_type == GameData.SkillType.SYSTEM else "应用"
		var diff := player_primary - listing.actual_skill_required

		var match_hint := ""
		if diff >= 5:
			match_hint = " ⚠过高"
		elif diff >= 0:
			match_hint = " ✓"
		else:
			match_hint = " ✗(差%d级)" % absf(diff)

		var eng_hint := ""
		var eng_diff: int = (game.skills[GameData.SkillType.ENGLISH] as int) - listing.actual_english_required
		if eng_diff < 0:
			eng_hint = " 英语差%d" % absi(eng_diff)
		var cpp_hint := ""
		if job.skill_type == GameData.SkillType.SYSTEM and listing.actual_cpp_required > 0:
			var cpp_diff: int = (game.skills[GameData.SkillType.CPP] as int) - listing.actual_cpp_required
			if cpp_diff < 0:
				cpp_hint = " C++差%d" % absi(cpp_diff)

		var selected: bool = _apply_selection.get(listing.listing_id, false)
		var prefix := "[✓已选] " if selected else ""

		# V2: 通过率显示
		var resume_rate := game.calc_resume_pass_rate(listing)
		var interview_rates := game.calc_interview_pass_rate(listing)
		var rate_text := "  简历≈%.0f%% 面试≈%.0f%%" % [resume_rate * 100, interview_rates["total"] * 100]

		var text := "%s[%s] %s | 要求%s%d%s 英%d $%d/周%s%s%s" % [
			prefix, listing.company, job.title,
			skill_name, listing.actual_skill_required, match_hint,
			listing.actual_english_required, listing.actual_salary,
			eng_hint, cpp_hint, rate_text]

		var in_progress := false
		if game.applications.has(listing.listing_id):
			var app: GameData.JobApplication = game.applications[listing.listing_id]
			if app.status != GameData.ApplicationStatus.NONE and \
					app.status != GameData.ApplicationStatus.REJECTED:
				in_progress = true
				text += " [进行中]"

		var can_select: bool = not in_progress and (selected or selected_count < 3)

		var btn := Button.new()
		btn.text = text
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = not can_select
		btn.pressed.connect(_on_toggle_listing.bind(listing.listing_id))
		btn.add_theme_font_size_override("font_size", 16)
		sub_menu_list.add_child(btn)

	# 确认按钮
	var confirm_text := "确认投递（%d 家" % selected_count
	if selected_count == 2:
		confirm_text += "，通过率 ×80%%"
	elif selected_count >= 3:
		confirm_text += "，通过率 ×65%%"
	confirm_text += "）"

	var confirm_btn := Button.new()
	confirm_btn.text = confirm_text
	confirm_btn.disabled = selected_count == 0
	confirm_btn.pressed.connect(_on_confirm_apply)
	confirm_btn.add_theme_font_size_override("font_size", 16)
	sub_menu_list.add_child(confirm_btn)

	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.pressed.connect(_on_close_sub_menu)
	back_btn.add_theme_font_size_override("font_size", 16)
	sub_menu_list.add_child(back_btn)


func _on_toggle_listing(listing_id: String) -> void:
	var current: bool = _apply_selection.get(listing_id, false)
	_apply_selection[listing_id] = not current
	_rebuild_apply_menu()


func _on_confirm_apply() -> void:
	var selected_ids: Array[String] = []
	for listing_id in _apply_selection:
		if _apply_selection[listing_id]:
			selected_ids.append(listing_id)
	if selected_ids.is_empty():
		return
	game.action_apply_batch(selected_ids)
	_apply_selection.clear()
	sub_menu_panel.visible = false
	_refresh_ui()


func _on_close_sub_menu() -> void:
	sub_menu_panel.visible = false
	_apply_selection.clear()
	_shop_mode = false
	_company_mode = false
	_selected_company = null
	_replacing_tool_id = ""
	_refresh_ui()


# ════════════════════════════════════════
#  周结算
# ════════════════════════════════════════

func _on_end_week() -> void:
	var result := game.settle_week()
	_show_settlement(result)


func _show_settlement(result: GameState.WeekSettlement) -> void:
	settlement_panel.visible = true
	var lines: Array[String] = []
	lines.append("── 第 %d 周结算 ──" % (game.week - 1))
	if result.salary_earned > 0:
		lines.append("工资收入：+$%s" % _format_number(result.salary_earned))
	lines.append("生活费支出：-$%s" % _format_number(result.living_cost))
	if result.tool_cost > 0:
		lines.append("工具订阅：-$%s" % _format_number(result.tool_cost))
	lines.append("现金变化：$%s → $%s" % [
		_format_number(result.cash_before), _format_number(result.cash_after)])
	lines.append("──────────────────")

	if result.notifications.size() > 0:
		lines.append("本周通知：")
		for note in result.notifications:
			lines.append("· %s" % note)

	if result.expired_offers.size() > 0:
		lines.append("")
		for title in result.expired_offers:
			lines.append("⚠ Offer 已过期：%s" % title)

	# V3: 新获得的特质
	for trait_id in result.new_traits:
		var tdef := game._find_trait_def(trait_id)
		if tdef:
			lines.append("")
			lines.append("🌟 获得新特质：「%s」" % tdef.name)
			lines.append("   条件达成：%s" % tdef.condition_text)
			lines.append("   效果：%s" % tdef.effect_text)
			if tdef.side_effect_text != "":
				lines.append("   ⚠ 副作用：%s" % tdef.side_effect_text)

	# V3: 失去的特质
	for trait_id in result.lost_traits:
		var tdef := game._find_trait_def(trait_id)
		if tdef:
			lines.append("")
			lines.append("💨 特质消失：「%s」" % tdef.name)

	if not result.event_name.is_empty():
		lines.append("")
		lines.append("🎲 本周事件：%s" % result.event_name)
		lines.append("   %s" % result.event_desc)

	if result.market_downturn_ended:
		lines.append("")
		lines.append("📈 寒冬已过，市场回暖！")

	if result.market_refreshed:
		lines.append("")
		var downturn_note := "（寒冬期，共 %d 个岗位）" % game.current_listings.size() \
			if game.market_downturn_weeks_left > 0 else ""
		lines.append("★ 岗位市场已刷新！当前：%s%s" % [game.get_market_bias_text(), downturn_note])
		lines.append("   🔥 本期热门技能：%s" % game.get_hot_skill_name())
		lines.append("   📋 当前市场共 %d 个岗位" % game.current_listings.size())

	if result.is_game_over:
		lines.append("")
		lines.append("[color=red]你的积蓄耗尽了……Game Over[/color]")

	settlement_label.text = "\n".join(lines)


func _on_settlement_continue() -> void:
	settlement_panel.visible = false
	if game.cash < 0:
		_show_ending(GameState.Ending.GAME_OVER)
	elif game.week > GameData.MAX_WEEKS:
		_show_ending(game.get_ending())
	else:
		_refresh_ui()


# ════════════════════════════════════════
#  结局
# ════════════════════════════════════════

func _show_ending(ending: GameState.Ending) -> void:
	ending_panel.visible = true
	var info := game.get_ending_text(ending)
	ending_label.text = "%s\n\n%s\n\n最终现金：$%s\n存活周数：%d" % [
		info["title"], info["desc"], _format_number(game.cash), game.week - 1]


func _on_restart() -> void:
	game = GameState.new()
	_apply_selection.clear()
	_shop_mode = false
	_company_mode = false
	_selected_company = null
	_replacing_tool_id = ""
	settlement_panel.visible = false
	ending_panel.visible = false
	sub_menu_panel.visible = false
	_refresh_ui()


# ════════════════════════════════════════
#  工具
# ════════════════════════════════════════

## 计算零工显示收入（含倍率）
func _calc_gig_display(base_income: int) -> int:
	var income := base_income
	if game.market_downturn_weeks_left > 0:
		income = int(income * 0.90)
	income = int(income * game._get_gig_income_multiplier())
	return income


func _format_number(n: int) -> String:
	var s := str(absi(n))
	var result := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			result += ","
		result += s[i]
	if n < 0:
		return "-" + result
	return result
