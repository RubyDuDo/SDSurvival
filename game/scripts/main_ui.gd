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
	var skill_sys: int = game.get_skill(GameData.SkillType.SYSTEM)
	var skill_app: int = game.get_skill(GameData.SkillType.APPLICATION)
	var skill_int: int = game.get_skill(GameData.SkillType.INTERVIEW)
	var xp_sys: String = game.get_skill_xp_progress(GameData.SkillType.SYSTEM)
	var xp_app: String = game.get_skill_xp_progress(GameData.SkillType.APPLICATION)
	var xp_int: String = game.get_skill_xp_progress(GameData.SkillType.INTERVIEW)

	var job_text := "失业"
	if game.current_job:
		job_text = "在职 - %s（周薪 $%d，占用 %d 能量）" % [
			game.current_job.title, game.current_job.weekly_salary, game.current_job.energy_cost]
		if game.pending_quit:
			job_text += " [已提辞职]"

	var free_energy := game.get_free_energy()
	status_label.text = (
		"技能：系统开发 Lv.%d(%s)  应用开发 Lv.%d(%s)  面试技巧 Lv.%d(%s)\n" % [
			skill_sys, xp_sys, skill_app, xp_app, skill_int, xp_int] +
		"状态：%s\n" % job_text +
		"可用能量：%d / %d" % [free_energy, GameData.ENERGY_PER_WEEK]
	)


func _update_job_progress() -> void:
	if game.applications.is_empty():
		job_progress_label.text = "（无求职进度）"
		return
	var lines: Array[String] = []
	for job_id in game.applications:
		var app: GameData.JobApplication = game.applications[job_id]
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
			lines.append("· %s — %s" % [app.job.title, status_text])
	job_progress_label.text = "\n".join(lines) if lines.size() > 0 else "（无求职进度）"


func _update_action_list() -> void:
	# 清除旧按钮
	for child in action_list.get_children():
		child.queue_free()

	var free := game.get_free_energy()

	var xp_sys_str: String = game.get_skill_xp_progress(GameData.SkillType.SYSTEM)
	var xp_app_str: String = game.get_skill_xp_progress(GameData.SkillType.APPLICATION)
	var xp_int_str: String = game.get_skill_xp_progress(GameData.SkillType.INTERVIEW)
	_add_action_button("学习系统开发（能量 -1，进度 %s）" % xp_sys_str,
			free >= 1 and game.get_skill(GameData.SkillType.SYSTEM) < GameData.MAX_SKILL_LEVEL,
			_on_study_system)
	_add_action_button("学习应用开发（能量 -1，进度 %s）" % xp_app_str,
			free >= 1 and game.get_skill(GameData.SkillType.APPLICATION) < GameData.MAX_SKILL_LEVEL,
			_on_study_app)
	_add_action_button("练习面试（能量 -1，进度 %s）" % xp_int_str,
			free >= 1 and game.get_skill(GameData.SkillType.INTERVIEW) < GameData.MAX_SKILL_LEVEL,
			_on_study_interview)
	_add_action_button("兼职零工（能量 -%d，+$%d）" % [GameData.GIG_ENERGY_PARTTIME, GameData.GIG_INCOME_PARTTIME],
			free >= GameData.GIG_ENERGY_PARTTIME, _on_gig_parttime)
	_add_action_button("全职零工（能量 -%d，+$%d）" % [GameData.GIG_ENERGY_FULLTIME, GameData.GIG_INCOME_FULLTIME],
			free >= GameData.GIG_ENERGY_FULLTIME, _on_gig_fulltime)
	_add_action_button("投递简历（能量 -1）", free >= 1, _on_apply)

	# 面试按钮 - 列出有面试机会的岗位
	for job_id in game.applications:
		var app: GameData.JobApplication = game.applications[job_id]
		if app.status == GameData.ApplicationStatus.HAS_INTERVIEW:
			var btn_text := "参加面试：%s（能量 -2）" % app.job.title
			_add_action_button(btn_text, free >= 2, _on_interview.bind(job_id))

	# Offer 操作
	for job_id in game.applications:
		var app: GameData.JobApplication = game.applications[job_id]
		if app.status == GameData.ApplicationStatus.OFFER:
			_add_action_button(
				"接受 Offer：%s（$%d/周）" % [app.job.title, app.job.weekly_salary],
				true, _on_accept_offer.bind(job_id))
			_add_action_button(
				"拒绝 Offer：%s" % app.job.title,
				true, _on_reject_offer.bind(job_id))

	# 辞职
	if game.current_job and not game.pending_quit:
		_add_action_button("辞职", true, _on_quit)

	# 结束本周
	_add_action_button(">>> 结束本周 <<<", true, _on_end_week)


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

func _on_study_system() -> void:
	game.action_study(GameData.SkillType.SYSTEM)
	_refresh_ui()

func _on_study_app() -> void:
	game.action_study(GameData.SkillType.APPLICATION)
	_refresh_ui()

func _on_study_interview() -> void:
	game.action_study(GameData.SkillType.INTERVIEW)
	_refresh_ui()

func _on_gig_parttime() -> void:
	game.action_gig_parttime()
	_refresh_ui()

func _on_gig_fulltime() -> void:
	game.action_gig_fulltime()
	_refresh_ui()

func _on_apply() -> void:
	_show_apply_menu()

func _on_interview(job_id: String) -> void:
	game.action_interview(job_id)
	_refresh_ui()

func _on_accept_offer(job_id: String) -> void:
	game.action_accept_offer(job_id)
	_refresh_ui()

func _on_reject_offer(job_id: String) -> void:
	game.action_reject_offer(job_id)
	_refresh_ui()

func _on_quit() -> void:
	game.action_quit()
	_refresh_ui()


# ════════════════════════════════════════
#  投递子菜单
# ════════════════════════════════════════

func _show_apply_menu() -> void:
	sub_menu_panel.visible = true
	sub_menu_title.text = "选择投递岗位："
	for child in sub_menu_list.get_children():
		child.queue_free()

	for job in game.all_jobs:
		var player_skill: int = game.skills[job.skill_type]
		var meets := player_skill >= job.skill_required
		var mark := "✓" if meets else "✗"
		var skill_name := "系统" if job.skill_type == GameData.SkillType.SYSTEM else "应用"
		var text := "%s - 要求%s %d | 你的%s %d %s  (周薪$%d)" % [
			job.title, skill_name, job.skill_required,
			skill_name, player_skill, mark, job.weekly_salary]

		# 检查是否可以投递
		var can_apply := true
		if game.applications.has(job.id):
			var app: GameData.JobApplication = game.applications[job.id]
			if app.status != GameData.ApplicationStatus.NONE and \
					app.status != GameData.ApplicationStatus.REJECTED:
				can_apply = false
				text += " [进行中]"

		var btn := Button.new()
		btn.text = text
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = not can_apply
		btn.pressed.connect(_on_apply_job.bind(job.id))
		btn.add_theme_font_size_override("font_size", 16)
		sub_menu_list.add_child(btn)

	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.pressed.connect(_on_close_sub_menu)
	back_btn.add_theme_font_size_override("font_size", 16)
	sub_menu_list.add_child(back_btn)


func _on_apply_job(job_id: String) -> void:
	game.action_apply(job_id)
	sub_menu_panel.visible = false
	_refresh_ui()


func _on_close_sub_menu() -> void:
	sub_menu_panel.visible = false


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

	if result.is_game_over:
		lines.append("")
		lines.append("[color=red]你的积蓄耗尽了……Game Over[/color]")

	settlement_label.text = "\n".join(lines)


func _on_settlement_continue() -> void:
	settlement_panel.visible = false
	var prev_result_game_over := game.cash < 0
	if prev_result_game_over:
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
