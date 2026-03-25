## 主界面控制器 V4: 左右分栏布局
extends Control

@onready var header_label: RichTextLabel = %HeaderLabel
@onready var action_list: VBoxContainer = %ActionList
@onready var info_label: RichTextLabel = %InfoLabel
@onready var settlement_panel: Panel = %SettlementPanel
@onready var settlement_label: RichTextLabel = %SettlementLabel
@onready var ending_panel: Panel = %EndingPanel
@onready var ending_label: RichTextLabel = %EndingLabel
@onready var sub_menu_panel: Panel = %SubMenuPanel
@onready var sub_menu_list: VBoxContainer = %SubMenuList
@onready var sub_menu_title: Label = %SubMenuTitle
@onready var skill_select_panel: Panel = %SkillSelectPanel
@onready var skill_buttons: VBoxContainer = %SkillButtons

var game: GameState
var _shop_mode: bool = false
var _replacing_tool_id: String = ""
var _company_mode: bool = false


func _ready() -> void:
	game = GameState.new()
	settlement_panel.visible = false
	ending_panel.visible = false
	sub_menu_panel.visible = false
	skill_select_panel.visible = true
	_setup_skill_select()


# ══════════════════════════════════════════
#  技能选择界面
# ══════════════════════════════════════════

func _setup_skill_select() -> void:
	for child in skill_buttons.get_children():
		child.queue_free()
	for skill_type in GameData.get_all_skill_types():
		var btn := Button.new()
		btn.text = GameData.get_skill_name(skill_type)
		btn.custom_minimum_size = Vector2(0, 45)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_skill_selected.bind(skill_type))
		skill_buttons.add_child(btn)


func _on_skill_selected(skill_type: GameData.SkillType) -> void:
	game.start_game(skill_type)
	skill_select_panel.visible = false
	_refresh_ui()


# ══════════════════════════════════════════
#  UI 刷新
# ══════════════════════════════════════════

func _refresh_ui() -> void:
	_update_header()
	_update_info_panel()
	_update_action_list()


func _update_header() -> void:
	var header := "第 %d 周 / %d 周    现金: $%s" % [
		game.week, GameData.MAX_WEEKS, _format_number(game.cash)]
	var wind := game.get_wind_text()
	if wind != "":
		header += "    📊 %s" % wind
	var event := game.get_market_event_text()
	if event != "":
		header += "    ⚡ %s" % event
	header_label.text = header


func _update_info_panel() -> void:
	var lines: Array[String] = []

	# ── 角色属性 ──
	lines.append("[color=#99ccdd]── 角色属性 ──[/color]")
	for st in GameData.get_all_skill_types():
		var lv: int = game.skills[st]
		var progress := game.get_skill_xp_progress(st)
		var bar := _make_progress_bar(lv)
		lines.append("  %s  Lv.%d %s (%s)" % [
			GameData.get_skill_name(st), lv, bar, progress])
	# 沟通
	var comm_bar := _make_progress_bar(game.communication)
	var comm_progress := game.get_general_skill_xp_progress(true)
	lines.append("  沟通      Lv.%d %s (%s)" % [game.communication, comm_bar, comm_progress])
	# 面试技巧
	var int_bar := _make_progress_bar(game.interview_skill)
	var int_progress := game.get_general_skill_xp_progress(false)
	lines.append("  面试技巧  Lv.%d %s (%s)" % [game.interview_skill, int_bar, int_progress])

	lines.append("")

	# ── 状态 ──
	lines.append("[color=#99ccdd]── 状态 ──[/color]")
	lines.append("  工作经验：%d    大厂经验：%d" % [game.work_experience, game.bigco_experience])
	lines.append("  Gap时间：%d    人际关系：%d/%d" % [
		game.gap_time, game.networking_points, GameData.MAX_NETWORKING_POINTS])
	if game.personal_project_done:
		lines.append("  个人作品：已完成")
	else:
		lines.append("  个人作品：进度 %d/%d" % [
			game.personal_project_progress, GameData.PERSONAL_PROJECT_COST])
	lines.append("  外包完成：%d" % game.outsource_count)
	var free_energy := game.get_free_energy()
	lines.append("  行动力：%d/%d" % [free_energy, game.energy])
	if game.resume_faked:
		lines.append("  [color=#ff8888]简历包装中[/color]（技能+1，面试30%被拆穿风险）")

	lines.append("")

	# ── 在职 ──
	lines.append("[color=#99ccdd]── 在职 ──[/color]")
	if game.current_job_listing:
		var job := game.current_job_listing
		lines.append("  %s @ %s" % [job.job.title, job.company_def.name])
		lines.append("  周薪：$%s  占用：%dAP" % [
			_format_number(job.actual_salary), job.job.energy_cost])
		if game.pending_quit:
			lines.append("  [color=#ff8888]（已提出辞职，下周生效）[/color]")
	else:
		lines.append("  未就业")

	lines.append("")

	# ── 求职进度 ──
	lines.append("[color=#99ccdd]── 求职进度 ──[/color]")
	var has_progress := false
	for listing_id in game.applications:
		var app: GameData.JobApplication = game.applications[listing_id]
		var status_text := ""
		match app.status:
			GameData.ApplicationStatus.APPLIED:
				status_text = "已投递"
			GameData.ApplicationStatus.HAS_INTERVIEW:
				status_text = "[color=#88ff88]有面试机会[/color]"
			GameData.ApplicationStatus.INTERVIEWED:
				status_text = "面试中"
			GameData.ApplicationStatus.OFFER:
				status_text = "[color=#ffdd44]Offer（剩余%d周）[/color]" % app.offer_weeks_left
			_:
				continue
		var title := app.listing.get_display_title()
		lines.append("  · %s — %s" % [title, status_text])
		has_progress = true
	if not has_progress:
		lines.append("  （无）")

	lines.append("")

	# ── 工具 ──
	lines.append("[color=#99ccdd]── 工具 [%d/%d] ──[/color]" % [
		game.owned_tools.size(), GameData.MAX_TOOLS])
	if game.owned_tools.is_empty():
		lines.append("  （无）")
	else:
		for tid in game.owned_tools:
			var tdef := game._find_tool_def(tid)
			if tdef:
				lines.append("  %s %s（%s）" % [tdef.icon, tdef.name, tdef.description])

	lines.append("")

	# ── 特质 ──
	lines.append("[color=#99ccdd]── 特质 ──[/color]")
	if game.active_traits.is_empty():
		lines.append("  （无）")
	else:
		for tid in game.active_traits:
			var tdef := game._find_trait_def(tid)
			if tdef:
				lines.append("  %s（%s）" % [tdef.name, tdef.effect_text])

	# ── 外包机会 ──
	if game.has_outsource_available():
		lines.append("")
		lines.append("[color=#ddaa44]── 外包机会 ──[/color]")
		lines.append("  %s" % game.get_outsource_info())

	info_label.text = "\n".join(lines)


# ══════════════════════════════════════════
#  行动按钮列表（左侧面板）
# ══════════════════════════════════════════

func _update_action_list() -> void:
	for child in action_list.get_children():
		child.queue_free()

	var free_energy := game.get_free_energy()

	# ── 学习 ──
	_add_section_label("── 学习 ──")
	for st in GameData.get_all_skill_types():
		var lv: int = game.skills[st]
		var progress := game.get_skill_xp_progress(st)
		var fatigue := game.get_study_fatigue(st)
		var fatigue_hint := ""
		var count: int = game.weekly_study_count.get(st, 0)
		if count >= GameData.STUDY_FATIGUE_THRESHOLD + game.fatigue_bonus_this_week - 1:
			fatigue_hint = " [疲劳:半效]"
		var label := "学习%s（-1AP, Lv.%d XP %s%s）" % [
			GameData.get_skill_name(st), lv, progress, fatigue_hint]
		var enabled := free_energy >= 1 and lv < GameData.MAX_SKILL_LEVEL
		_add_action_button(label, _on_study_skill.bind(st), enabled)

	# 沟通
	var comm_progress := game.get_general_skill_xp_progress(true)
	var comm_count: int = game.weekly_study_count.get("communication", 0)
	var comm_fatigue := ""
	if comm_count >= GameData.STUDY_FATIGUE_THRESHOLD + game.fatigue_bonus_this_week - 1:
		comm_fatigue = " [疲劳:半效]"
	_add_action_button(
		"学习沟通（-1AP, Lv.%d XP %s%s）" % [game.communication, comm_progress, comm_fatigue],
		_on_study_communication,
		free_energy >= 1 and game.communication < GameData.MAX_SKILL_LEVEL)

	# 面试技巧
	var int_progress := game.get_general_skill_xp_progress(false)
	var int_count: int = game.weekly_study_count.get("interview_skill", 0)
	var int_fatigue := ""
	if int_count >= GameData.STUDY_FATIGUE_THRESHOLD + game.fatigue_bonus_this_week - 1:
		int_fatigue = " [疲劳:半效]"
	_add_action_button(
		"学习面试技巧（-1AP, Lv.%d XP %s%s）" % [game.interview_skill, int_progress, int_fatigue],
		_on_study_interview,
		free_energy >= 1 and game.interview_skill < GameData.MAX_SKILL_LEVEL)

	# ── 求职 ──
	_add_section_label("── 求职 ──")
	_add_action_button("精投简历（-1AP）", _on_focused_apply_menu, free_energy >= 1)
	_add_action_button(
		"海投简历（-1AP，随机%d个岗位）" % GameData.MASS_APPLY_COUNT,
		_on_mass_apply, free_energy >= 1)

	# 面试
	var has_interview := false
	for lid in game.applications:
		var app: GameData.JobApplication = game.applications[lid]
		if app.status == GameData.ApplicationStatus.HAS_INTERVIEW:
			has_interview = true
			var title := app.listing.get_display_title()
			var rate := game.calc_interview_pass_rate(app.listing)
			_add_action_button(
				"参加面试：%s（-2AP, 预估%.0f%%）" % [title, rate * 100],
				_on_interview.bind(lid), free_energy >= 2)

	if not game.resume_faked:
		_add_action_button("包装简历（-2AP, 技能+1但面试有30%翻车风险）",
			_on_fake_resume, free_energy >= 2)
	else:
		_add_action_button("取消包装（0AP）", _on_cancel_fake_resume, true)

	# ── 社交 ──
	_add_section_label("── 社交 ──")
	_add_action_button(
		"维护人际关系（-1AP, %d→%d/%d）" % [
			game.networking_points,
			mini(game.networking_points + (2 if game.has_tool("linkedin") else 1), GameData.MAX_NETWORKING_POINTS),
			GameData.MAX_NETWORKING_POINTS],
		_on_networking,
		free_energy >= 1 and game.networking_points < GameData.MAX_NETWORKING_POINTS)

	var can_project := game.can_do_personal_project()
	var proj_text := "做个人作品（-1AP, 进度 %d/%d）" % [
		game.personal_project_progress, GameData.PERSONAL_PROJECT_COST]
	if game.personal_project_done:
		proj_text = "个人作品（已完成）"
	_add_action_button(proj_text, _on_personal_project,
		can_project and free_energy >= 1)

	# ── 生存 ──
	_add_section_label("── 生存 ──")
	_add_action_button(
		"打零工·兼职（-3AP, +$%s）" % _format_number(game.get_gig_income(false)),
		_on_gig_parttime, free_energy >= GameData.GIG_ENERGY_PARTTIME)
	_add_action_button(
		"打零工·全职（-5AP, +$%s）" % _format_number(game.get_gig_income(true)),
		_on_gig_fulltime, free_energy >= GameData.GIG_ENERGY_FULLTIME)

	if game.has_outsource_available():
		var oc := game.current_outsource
		_add_action_button(
			"接外包·%s（-%dAP, +$%s）" % [
				oc.get_level_text(), oc.energy_cost, _format_number(oc.income)],
			_on_take_outsource, free_energy >= oc.energy_cost)

	# ── 其他 ──
	_add_section_label("── 其他 ──")
	_add_action_button("查看公司列表", _on_company_list_menu, true)
	_add_action_button("逛二手市场（-1AP）", _on_shop_menu, free_energy >= GameData.SHOP_ENERGY_COST)

	# Offer处理
	for lid in game.applications:
		var app: GameData.JobApplication = game.applications[lid]
		if app.status == GameData.ApplicationStatus.OFFER:
			var title := app.listing.get_display_title()
			_add_action_button(
				"接受Offer：%s（$%s/周）" % [title, _format_number(app.listing.actual_salary)],
				_on_accept_offer.bind(lid), true)
			_add_action_button("拒绝Offer：%s" % title,
				_on_reject_offer.bind(lid), true)

	if game.current_job_listing and not game.pending_quit:
		_add_action_button("辞职（下周生效）", _on_quit, true)

	_add_section_label("")
	var settle_btn := Button.new()
	settle_btn.text = ">>> 结束本周 <<<"
	settle_btn.custom_minimum_size = Vector2(0, 45)
	settle_btn.add_theme_font_size_override("font_size", 18)
	settle_btn.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	settle_btn.pressed.connect(_on_settle_week)
	action_list.add_child(settle_btn)


func _add_section_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9, 1))
	label.add_theme_font_size_override("font_size", 15)
	action_list.add_child(label)


func _add_action_button(text: String, callback: Callable, enabled: bool = true) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 36)
	btn.add_theme_font_size_override("font_size", 15)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.disabled = not enabled
	btn.pressed.connect(callback)
	action_list.add_child(btn)


# ══════════════════════════════════════════
#  行动回调
# ══════════════════════════════════════════

func _on_study_skill(skill_type: GameData.SkillType) -> void:
	game.action_study_skill(skill_type)
	_refresh_ui()

func _on_study_communication() -> void:
	game.action_study_communication()
	_refresh_ui()

func _on_study_interview() -> void:
	game.action_study_interview()
	_refresh_ui()

func _on_focused_apply_menu() -> void:
	_shop_mode = false
	_company_mode = false
	sub_menu_title.text = "选择投递岗位："
	_populate_apply_menu()
	sub_menu_panel.visible = true

func _on_mass_apply() -> void:
	var applied := game.action_mass_apply()
	if applied.size() > 0:
		_refresh_ui()

func _on_interview(listing_id: String) -> void:
	game.action_interview(listing_id)
	_refresh_ui()

func _on_fake_resume() -> void:
	game.action_fake_resume()
	_refresh_ui()

func _on_cancel_fake_resume() -> void:
	game.action_cancel_fake_resume()
	_refresh_ui()

func _on_networking() -> void:
	game.action_networking()
	_refresh_ui()

func _on_personal_project() -> void:
	game.action_personal_project()
	_refresh_ui()

func _on_gig_parttime() -> void:
	game.action_gig_parttime()
	_refresh_ui()

func _on_gig_fulltime() -> void:
	game.action_gig_fulltime()
	_refresh_ui()

func _on_take_outsource() -> void:
	game.action_take_outsource()
	_refresh_ui()

func _on_accept_offer(listing_id: String) -> void:
	game.action_accept_offer(listing_id)
	_refresh_ui()

func _on_reject_offer(listing_id: String) -> void:
	game.action_reject_offer(listing_id)
	_refresh_ui()

func _on_quit() -> void:
	game.action_quit()
	_refresh_ui()


# ══════════════════════════════════════════
#  精投简历子菜单
# ══════════════════════════════════════════

func _populate_apply_menu() -> void:
	for child in sub_menu_list.get_children():
		child.queue_free()
	for listing in game.current_listings:
		if game.applications.has(listing.listing_id):
			var app: GameData.JobApplication = game.applications[listing.listing_id]
			if app.status != GameData.ApplicationStatus.REJECTED:
				continue
		var rate := game.calc_resume_pass_rate(listing)
		var reqs := listing.get_requirements_text()
		var btn := Button.new()
		btn.text = "%s  $%s/周  需要：%s  通过率≈%.0f%%" % [
			listing.get_display_title(),
			_format_number(listing.actual_salary),
			reqs, rate * 100]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.add_theme_font_size_override("font_size", 14)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_apply_to.bind(listing.listing_id))
		sub_menu_list.add_child(btn)

	# 关闭按钮
	_add_close_button()


func _on_apply_to(listing_id: String) -> void:
	game.action_focused_apply(listing_id)
	sub_menu_panel.visible = false
	_refresh_ui()


# ══════════════════════════════════════════
#  公司列表子菜单
# ══════════════════════════════════════════

func _on_company_list_menu() -> void:
	_shop_mode = false
	_company_mode = true
	sub_menu_title.text = "公司列表"
	_populate_company_list()
	sub_menu_panel.visible = true


func _populate_company_list() -> void:
	for child in sub_menu_list.get_children():
		child.queue_free()

	# 按规模排序
	var sorted_companies: Array[GameData.CompanyDef] = []
	for c in game.companies:
		sorted_companies.append(c)
	sorted_companies.sort_custom(func(a, b): return a.scale < b.scale)

	for company in sorted_companies:
		var listing_count := game.get_company_listing_count(company.id)
		var btn := Button.new()
		btn.text = "%s [%s]  福利：%s  经营：%s  倾向：%s  在招：%d个" % [
			company.name, company.get_scale_text(),
			company.get_benefit_text(), company.get_status_text(),
			company.get_preferred_skills_text(), listing_count]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.add_theme_font_size_override("font_size", 14)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_company_detail.bind(company))
		sub_menu_list.add_child(btn)

	_add_close_button()


func _on_company_detail(company: GameData.CompanyDef) -> void:
	for child in sub_menu_list.get_children():
		child.queue_free()

	sub_menu_title.text = "%s 详情" % company.name

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.layout_mode = 2
	info.add_theme_font_size_override("normal_font_size", 16)
	info.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))

	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % company.name)
	lines.append("规模：%s" % company.get_scale_text())
	lines.append("福利水平：%s（薪资倍率 ×%.2f）" % [company.get_benefit_text(), company.get_salary_multiplier()])
	lines.append("经营状况：%s" % company.get_status_text())
	lines.append("倾向技能：%s" % company.get_preferred_skills_text())
	lines.append("")
	lines.append("[b]当前在招岗位：[/b]")

	var found := false
	for listing in game.current_listings:
		if listing.company_def.id == company.id:
			lines.append("  · %s  $%s/周  需要：%s" % [
				listing.job.title,
				_format_number(listing.actual_salary),
				listing.get_requirements_text()])
			found = true
	if not found:
		lines.append("  （暂无在招岗位）")

	info.text = "\n".join(lines)
	sub_menu_list.add_child(info)

	# 返回按钮
	var back_btn := Button.new()
	back_btn.text = "← 返回公司列表"
	back_btn.custom_minimum_size = Vector2(0, 40)
	back_btn.add_theme_font_size_override("font_size", 15)
	back_btn.pressed.connect(func():
		sub_menu_title.text = "公司列表"
		_populate_company_list())
	sub_menu_list.add_child(back_btn)

	_add_close_button()


# ══════════════════════════════════════════
#  商店子菜单
# ══════════════════════════════════════════

func _on_shop_menu() -> void:
	if not game.shop_visited_this_week:
		game.action_browse_shop()
	_shop_mode = true
	_company_mode = false
	_replacing_tool_id = ""
	sub_menu_title.text = "二手市场（现金: $%s）" % _format_number(game.cash)
	_populate_shop()
	sub_menu_panel.visible = true


func _populate_shop() -> void:
	for child in sub_menu_list.get_children():
		child.queue_free()

	for tool_id in game.shop_available_tools:
		var tdef := game._find_tool_def(tool_id)
		if tdef == null:
			continue
		var cost_text := ""
		if tdef.weekly_cost > 0:
			cost_text = " + $%d/周" % tdef.weekly_cost
		var label_text := "%s %s  $%d%s  %s" % [
			tdef.icon, tdef.name, tdef.price, cost_text, tdef.description]
		var can_buy := game.cash >= tdef.price
		var btn := Button.new()
		btn.text = label_text
		btn.custom_minimum_size = Vector2(0, 40)
		btn.add_theme_font_size_override("font_size", 14)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = not can_buy
		if game.owned_tools.size() < GameData.MAX_TOOLS:
			btn.pressed.connect(_on_buy_tool.bind(tool_id))
		else:
			btn.pressed.connect(_on_replace_tool_menu.bind(tool_id))
		sub_menu_list.add_child(btn)

	if game.owned_tools.size() >= GameData.MAX_TOOLS:
		var hint := Label.new()
		hint.text = "背包已满，购买新工具需要替换一个旧工具"
		hint.add_theme_font_size_override("font_size", 13)
		hint.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
		sub_menu_list.add_child(hint)

	_add_close_button()


func _on_buy_tool(tool_id: String) -> void:
	game.action_buy_tool(tool_id)
	sub_menu_panel.visible = false
	_refresh_ui()


func _on_replace_tool_menu(new_tool_id: String) -> void:
	_replacing_tool_id = new_tool_id
	for child in sub_menu_list.get_children():
		child.queue_free()

	var new_def := game._find_tool_def(new_tool_id)
	sub_menu_title.text = "选择要替换的工具（购买 %s）" % new_def.name

	for old_id in game.owned_tools:
		var old_def := game._find_tool_def(old_id)
		if old_def == null:
			continue
		var btn := Button.new()
		btn.text = "替换 %s %s（%s）" % [old_def.icon, old_def.name, old_def.description]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.add_theme_font_size_override("font_size", 14)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_replace_tool.bind(old_id, new_tool_id))
		sub_menu_list.add_child(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "← 取消"
	cancel_btn.custom_minimum_size = Vector2(0, 40)
	cancel_btn.add_theme_font_size_override("font_size", 15)
	cancel_btn.pressed.connect(func():
		_replacing_tool_id = ""
		sub_menu_title.text = "二手市场（现金: $%s）" % _format_number(game.cash)
		_populate_shop())
	sub_menu_list.add_child(cancel_btn)


func _on_replace_tool(old_id: String, new_id: String) -> void:
	game.action_replace_tool(old_id, new_id)
	sub_menu_panel.visible = false
	_refresh_ui()


# ══════════════════════════════════════════
#  结算与结局
# ══════════════════════════════════════════

func _on_settle_week() -> void:
	var result := game.settle_week()
	_show_settlement(result)


func _show_settlement(result: GameState.WeekSettlement) -> void:
	var lines: Array[String] = []
	lines.append("[b]═══ 第 %d 周结算 ═══[/b]" % (game.week - 1))
	lines.append("")

	if result.salary_earned > 0:
		lines.append("💰 工资收入：+$%s" % _format_number(result.salary_earned))
	lines.append("🏠 生活支出：-$%s" % _format_number(result.living_cost))
	if result.tool_cost > 0:
		lines.append("🔧 工具费用：-$%s" % _format_number(result.tool_cost))

	lines.append("💵 现金变化：$%s → $%s" % [
		_format_number(result.cash_before), _format_number(result.cash_after)])
	lines.append("")

	if result.did_quit:
		lines.append("📦 你已离职")
		lines.append("")

	for note in result.notifications:
		lines.append(note)

	if result.expired_offers.size() > 0:
		for offer in result.expired_offers:
			lines.append("⏰ Offer已过期：%s" % offer)

	if result.new_traits.size() > 0:
		for tid in result.new_traits:
			var tdef := game._find_trait_def(tid)
			if tdef:
				lines.append("🌟 获得特质：%s — %s" % [tdef.name, tdef.effect_text])

	if result.lost_traits.size() > 0:
		for tid in result.lost_traits:
			var tdef := game._find_trait_def(tid)
			if tdef:
				lines.append("💨 失去特质：%s" % tdef.name)

	if result.event_name != "":
		lines.append("")
		lines.append("%s" % result.event_name)
		lines.append("   %s" % result.event_desc)

	settlement_label.text = "\n".join(lines)
	settlement_panel.visible = true


func _on_settlement_continue() -> void:
	settlement_panel.visible = false
	if game.week > GameData.MAX_WEEKS:
		_show_ending()
	elif game.cash < 0:
		_show_ending()
	else:
		_refresh_ui()


func _show_ending() -> void:
	var rank := game.get_ending()
	var projected := game.calc_projected_income()
	var rank_letter := GameData.get_rank_letter(rank)
	var rank_name := GameData.get_ending_name(rank)
	var rank_desc := GameData.get_ending_description(rank)

	var lines: Array[String] = []
	lines.append("[center][b]════════════════════════════════════[/b][/center]")
	lines.append("[center][b]求职之旅结束！  最终评级：%s - %s[/b][/center]" % [rank_letter, rank_name])
	lines.append("[center][b]════════════════════════════════════[/b][/center]")
	lines.append("")

	# 最终状态
	lines.append("[b]最终状态[/b]")
	if game.current_job_listing:
		lines.append("  在职：%s @ %s（周薪 $%s）" % [
			game.current_job_listing.job.title,
			game.current_job_listing.company_def.name,
			_format_number(game.current_job_listing.actual_salary)])
	else:
		lines.append("  未就业")
	lines.append("  剩余现金：$%s" % _format_number(game.cash))
	lines.append("")

	# 预估年收入
	lines.append("[b]预估年收入[/b]")
	if game.current_job_listing:
		var weekly_net := game.current_job_listing.actual_salary - GameData.WEEKLY_LIVING_COST
		lines.append("  周薪 $%s - 生活费 $%s = 每周净收入 $%s" % [
			_format_number(game.current_job_listing.actual_salary),
			_format_number(GameData.WEEKLY_LIVING_COST),
			_format_number(weekly_net)])
		lines.append("  年净收入：$%s x 52 = $%s" % [
			_format_number(weekly_net), _format_number(weekly_net * 52)])
		lines.append("  加上剩余现金：$%s" % _format_number(projected))
	else:
		lines.append("  预估收入：$%s" % _format_number(projected))
	lines.append("")

	# 成就统计
	lines.append("[b]成就[/b]")
	var best_skill_name := ""
	var best_skill_lv := 0
	for st in GameData.get_all_skill_types():
		if game.skills[st] > best_skill_lv:
			best_skill_lv = game.skills[st]
			best_skill_name = GameData.get_skill_name(st)
	lines.append("  · 技能最高：%s Lv.%d" % [best_skill_name, best_skill_lv])
	lines.append("  · 工作经验：%d周" % game.work_experience)
	lines.append("  · 外包完成：%d次" % game.outsource_count)
	lines.append("  · 投递简历：%d / 获面试：%d / 拿到Offer：%d" % [
		game.stats_total_applications, game.stats_total_interviews, game.stats_total_offers])
	lines.append("  · 被拒次数：%d" % game.stats_total_rejections)
	if game.stats_highest_offer_salary > 0:
		lines.append("  · 最高薪Offer：$%s/周" % _format_number(game.stats_highest_offer_salary))
	lines.append("  · 零工/外包总收入：$%s" % _format_number(game.stats_total_gig_income))
	lines.append("  · 学习总次数：%d" % game.stats_total_study_count)
	lines.append("  · 人际关系：%d" % game.networking_points)
	if game.active_traits.size() > 0:
		var trait_names: Array[String] = []
		for tid in game.active_traits:
			var tdef := game._find_trait_def(tid)
			if tdef:
				trait_names.append(tdef.name)
		lines.append("  · 获得特质：%s" % "、".join(trait_names))
	lines.append("")
	lines.append("[i]\"%s\"[/i]" % rank_desc)

	ending_label.text = "\n".join(lines)
	ending_panel.visible = true


func _on_restart() -> void:
	ending_panel.visible = false
	settlement_panel.visible = false
	sub_menu_panel.visible = false
	game = GameState.new()
	skill_select_panel.visible = true
	_setup_skill_select()


# ══════════════════════════════════════════
#  工具函数
# ══════════════════════════════════════════

func _add_close_button() -> void:
	var btn := Button.new()
	btn.text = "关闭"
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(func(): sub_menu_panel.visible = false)
	sub_menu_list.add_child(btn)


func _format_number(n: int) -> String:
	var s := str(abs(n))
	var result := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			result += ","
		result += s[i]
	if n < 0:
		return "-" + result
	return result


func _make_progress_bar(level: int) -> String:
	var filled := mini(level, 10)
	var empty := 10 - filled
	return "[color=#44aa44]%s[/color][color=#333333]%s[/color]" % [
		"█".repeat(filled), "░".repeat(empty)]
