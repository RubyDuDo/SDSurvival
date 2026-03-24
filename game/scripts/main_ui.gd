## 主界面控制器
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
var _apply_selection: Dictionary = {}  # listing_id -> bool（投递多选状态）

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
	header_label.text = "第 %d 周 / %d 周          现金: $%s" % [
		game.week, GameData.MAX_WEEKS, _format_number(game.cash)]


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

	# 状态效果提示
	var effects: Array[String] = []
	if game.market_downturn_weeks_left > 0:
		effects.append("📉 寒冬中（剩 %d 周）" % game.market_downturn_weeks_left)
	if game.double_xp_this_week:
		effects.append("💡 双倍XP")
	var effects_line := ("    " + "  |  ".join(effects)) if effects.size() > 0 else ""

	status_label.text = (
		"专业：系统 Lv.%d(%s)  应用 Lv.%d(%s)  C++ Lv.%d(%s)\n" % [
			s[ST.SYSTEM], game.get_skill_xp_progress(ST.SYSTEM),
			s[ST.APPLICATION], game.get_skill_xp_progress(ST.APPLICATION),
			s[ST.CPP], game.get_skill_xp_progress(ST.CPP)] +
		"通用：面试技巧 Lv.%d(%s)  英语 Lv.%d(%s)\n" % [
			s[ST.INTERVIEW], game.get_skill_xp_progress(ST.INTERVIEW),
			s[ST.ENGLISH], game.get_skill_xp_progress(ST.ENGLISH)] +
		"人脉：%d/%d    作品集：系统 %d/%d  应用 %d/%d\n" % [
			game.networking_points, GameData.MAX_NETWORKING_POINTS,
			game.portfolio_system, GameData.MAX_PORTFOLIO_POINTS,
			game.portfolio_application, GameData.MAX_PORTFOLIO_POINTS] +
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


func _update_action_list() -> void:
	for child in action_list.get_children():
		child.queue_free()

	var free := game.get_free_energy()
	var ST := GameData.SkillType

	# ── 学习按钮 ──
	_add_study_btn("学习系统开发", ST.SYSTEM, free)
	_add_study_btn("学习应用开发", ST.APPLICATION, free)
	_add_study_btn("练习C++", ST.CPP, free)
	_add_study_btn("练习面试技巧", ST.INTERVIEW, free)
	_add_study_btn("学习英语", ST.ENGLISH, free)

	# ── 零工按钮 ──
	_add_action_button(
		"兼职零工（能量 -%d，+$%d）" % [GameData.GIG_ENERGY_PARTTIME, GameData.GIG_INCOME_PARTTIME],
		free >= GameData.GIG_ENERGY_PARTTIME, _on_gig_parttime)
	_add_action_button(
		"全职零工（能量 -%d，+$%d）" % [GameData.GIG_ENERGY_FULLTIME, GameData.GIG_INCOME_FULLTIME],
		free >= GameData.GIG_ENERGY_FULLTIME, _on_gig_fulltime)

	# ── 人脉 ──
	var net_full := game.networking_points >= GameData.MAX_NETWORKING_POINTS
	_add_action_button(
		"维护人脉（能量 -1，人脉 %d → %d/%d）" % [
			game.networking_points,
			mini(game.networking_points + 1, GameData.MAX_NETWORKING_POINTS),
			GameData.MAX_NETWORKING_POINTS],
		free >= 1 and not net_full, _on_networking)

	# ── 作品集 ──
	_add_portfolio_btn(GameData.SkillType.SYSTEM, free)
	_add_portfolio_btn(GameData.SkillType.APPLICATION, free)

	# ── 投递（打开多选菜单）──
	_add_action_button("投递简历（能量 -1，可一次投 1-3 家）", free >= 1, _on_apply)

	# ── 面试按钮 ──
	for listing_id in game.applications:
		var app: GameData.JobApplication = game.applications[listing_id]
		if app.status == GameData.ApplicationStatus.HAS_INTERVIEW:
			var btn_text := "参加面试：%s [%s]（能量 -2）" % [app.listing.job.title, app.listing.company]
			_add_action_button(btn_text, free >= 2, _on_interview.bind(listing_id))

	# ── Offer 操作 ──
	for listing_id in game.applications:
		var app: GameData.JobApplication = game.applications[listing_id]
		if app.status == GameData.ApplicationStatus.OFFER:
			_add_action_button(
				"接受 Offer：%s [%s]（$%d/周）" % [app.listing.job.title, app.listing.company, app.listing.actual_salary],
				true, _on_accept_offer.bind(listing_id))
			_add_action_button(
				"拒绝 Offer：%s [%s]" % [app.listing.job.title, app.listing.company],
				true, _on_reject_offer.bind(listing_id))

	# ── 辞职 ──
	if game.current_job_listing and not game.pending_quit:
		_add_action_button("辞职", true, _on_quit)

	_add_action_button(">>> 结束本周 <<<", true, _on_end_week)


func _add_portfolio_btn(skill_type: GameData.SkillType, free: int) -> void:
	var direction := "系统" if skill_type == GameData.SkillType.SYSTEM else "应用"
	var pts := game.portfolio_system if skill_type == GameData.SkillType.SYSTEM else game.portfolio_application
	var maxed := pts >= GameData.MAX_PORTFOLIO_POINTS
	var label := "做个人项目·%s（能量 -3，作品集 %d → %d/%d）" % [
		direction, pts, mini(pts + 1, GameData.MAX_PORTFOLIO_POINTS), GameData.MAX_PORTFOLIO_POINTS]
	_add_action_button(label, free >= GameData.PORTFOLIO_ENERGY_COST and not maxed,
		_on_portfolio.bind(skill_type))


func _add_study_btn(label: String, skill_type: GameData.SkillType, free: int) -> void:
	var progress := game.get_skill_xp_progress(skill_type)
	var can := free >= 1 and game.get_skill(skill_type) < GameData.MAX_SKILL_LEVEL
	_add_action_button("%s（能量 -1，进度 %s）" % [label, progress], can, _on_study.bind(skill_type))


func _add_action_button(text: String, enabled: bool, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.disabled = not enabled
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(callback)
	btn.add_theme_font_size_override("font_size", 18)
	action_list.add_child(btn)


# ════════════════════════════════════════
#  行动回调
# ════════════════════════════════════════

func _on_study(skill_type: GameData.SkillType) -> void:
	game.action_study(skill_type)
	_refresh_ui()

func _on_gig_parttime() -> void:
	game.action_gig_parttime()
	_refresh_ui()

func _on_gig_fulltime() -> void:
	game.action_gig_fulltime()
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


# ════════════════════════════════════════
#  投递子菜单（多选）
# ════════════════════════════════════════

func _show_apply_menu() -> void:
	sub_menu_panel.visible = true
	_rebuild_apply_menu()


func _rebuild_apply_menu() -> void:
	sub_menu_title.text = "选择投递岗位（本期市场：%s）\n选1个：正常概率 | 选2个：×80%% | 选3个：×65%%（最多3个）" % \
		game.get_market_bias_text()

	for child in sub_menu_list.get_children():
		child.queue_free()

	var selected_count: int = _apply_selection.values().count(true)

	for listing in game.current_listings:
		var job := listing.job
		var player_primary: int = game.skills[job.skill_type]
		var skill_name := "系统" if job.skill_type == GameData.SkillType.SYSTEM else "应用"
		var diff := player_primary - listing.actual_skill_required

		# 简单匹配度指示
		var match_hint := ""
		if diff >= 5:
			match_hint = " ⚠过高"
		elif diff >= 0:
			match_hint = " ✓"
		else:
			match_hint = " ✗(差%d级)" % absf(diff)

		# 英语和C++状态
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

		var text := "%s[%s] %s | 要求%s%d%s 英%d 周薪$%d%s%s" % [
			prefix, listing.company, job.title,
			skill_name, listing.actual_skill_required, match_hint,
			listing.actual_english_required, listing.actual_salary,
			eng_hint, cpp_hint]

		# 进行中的申请不可再选
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

	if not result.event_name.is_empty():
		lines.append("")
		lines.append("🎲 本周事件：%s" % result.event_name)
		lines.append("   %s" % result.event_desc)

	if result.market_downturn_started:
		lines.append("")
		lines.append("⚠ 行业寒冬来袭！岗位减少，竞争更激烈，持续 3 周。")
	if result.market_downturn_ended:
		lines.append("")
		lines.append("📈 寒冬已过，市场回暖！")

	if result.market_refreshed:
		lines.append("")
		var downturn_note := "（寒冬期，共 %d 个岗位）" % game.current_listings.size() \
			if game.market_downturn_weeks_left > 0 else ""
		lines.append("★ 岗位市场已刷新！当前：%s%s" % [game.get_market_bias_text(), downturn_note])

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
	settlement_panel.visible = false
	ending_panel.visible = false
	sub_menu_panel.visible = false
	_refresh_ui()


# ════════════════════════════════════════
#  工具
# ════════════════════════════════════════

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
