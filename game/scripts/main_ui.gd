## 主界面控制器 V4: 蓝色科技风 UI
extends Control

# ══════════════════════════════════════════
#  节点引用
# ══════════════════════════════════════════

@onready var header_bar: PanelContainer = %HeaderBar
@onready var week_label: RichTextLabel = %WeekLabel
@onready var week_bar: RichTextLabel = %WeekBar
@onready var status_label: RichTextLabel = %StatusLabel
@onready var event_bar: RichTextLabel = %EventBar

@onready var left_panel: PanelContainer = %LeftPanel
@onready var right_panel: PanelContainer = %RightPanel
@onready var action_list: VBoxContainer = %ActionList
@onready var info_vbox: VBoxContainer = %InfoVBox

@onready var settlement_panel: Panel = %SettlementPanel
@onready var settlement_card: PanelContainer = %SettlementCard
@onready var settlement_label: RichTextLabel = %SettlementLabel
@onready var settlement_offer_box: VBoxContainer = %SettlementOfferBox

@onready var ending_panel: Panel = %EndingPanel
@onready var ending_card: PanelContainer = %EndingCard
@onready var ending_label: RichTextLabel = %EndingLabel

@onready var sub_menu_panel: Panel = %SubMenuPanel
@onready var sub_menu_card: PanelContainer = %SubMenuCard
@onready var sub_menu_list: VBoxContainer = %SubMenuList
@onready var sub_menu_title: RichTextLabel = %SubMenuTitle

@onready var skill_select_panel: Panel = %SkillSelectPanel
@onready var skill_buttons: HBoxContainer = %SkillButtons
@onready var company_button: Button = %CompanyButton
@onready var intro_panel: Panel = %IntroPanel
@onready var intro_label: RichTextLabel = %IntroLabel

var game: GameState
var _shop_mode: bool = false
var _replacing_tool_id: String = ""
var _company_mode: bool = false
var _flash_skill_key: String = ""  # 用于触发右侧信息卡闪烁


const INTRO_STORIES := [
	"[center][color=#60A5FA][font_size=32]Offer Not Found[/font_size][/color]\n\n[color=#E2E8F0]你是一个初出茅庐的程序员。\n\n毕业季的校园里，同学们纷纷拿到了心仪的 Offer，\n而你却还在为未来迷茫。\n\n怀揣着一笔不多的积蓄，\n你决定用接下来 12 周的时间，\n闯出属于自己的一片天。\n\n学技能，投简历，面试，接外包……\n每一个选择都至关重要。[/color][/center]",

	"[center][color=#60A5FA][font_size=32]Offer Not Found[/font_size][/color]\n\n[color=#E2E8F0]秋招季。\n\n你看着招聘网站上 99+ 的已读不回，\n关掉了第 47 个「感谢您的投递，\n但很遗憾……」的邮件。\n\n卡里的余额在一天天减少，\n但你知道只要坚持下去，\n总会有一扇门为你打开。\n\n12 周。这是你给自己定下的最后期限。[/color][/center]",

	"[center][color=#60A5FA][font_size=32]Offer Not Found[/font_size][/color]\n\n[color=#E2E8F0]\"您的简历已进入人才库。\"\n\n翻译：我们不要你。\n\n你合上笔记本电脑，深吸一口气，\n打开了 LeetCode。\n\n没关系。从今天开始，\n用 12 周时间，\n把自己打造成他们拒绝不了的人。\n\n毕竟，404 之后，总会有 200 OK。[/color][/center]",
]

func _ready() -> void:
	game = GameState.new()
	_apply_panel_styles()
	settlement_panel.visible = false
	ending_panel.visible = false
	sub_menu_panel.visible = false
	skill_select_panel.visible = false
	intro_panel.visible = true
	_show_intro()


# ══════════════════════════════════════════
#  面板样式初始化
# ══════════════════════════════════════════

func _apply_panel_styles() -> void:
	# Header bar
	header_bar.add_theme_stylebox_override("panel",
		UITheme.make_flat(UITheme.BG_PANEL, UITheme.CORNER_MD,
			UITheme.BORDER_BLUE, 1, 0, 0, 0, 0))

	# 左右面板
	var panel_bg := Color(UITheme.BG_PANEL.r, UITheme.BG_PANEL.g, UITheme.BG_PANEL.b, 0.6)
	left_panel.add_theme_stylebox_override("panel",
		UITheme.make_flat(panel_bg, UITheme.CORNER_MD,
			UITheme.BORDER_BLUE, 1, 0, 0, 0, 0))
	right_panel.add_theme_stylebox_override("panel",
		UITheme.make_flat(panel_bg, UITheme.CORNER_MD,
			UITheme.BORDER_BLUE, 1, 0, 0, 0, 0))

	# 弹窗卡片
	settlement_card.add_theme_stylebox_override("panel", UITheme.make_popup_panel())
	ending_card.add_theme_stylebox_override("panel", UITheme.make_popup_panel())
	sub_menu_card.add_theme_stylebox_override("panel", UITheme.make_popup_panel())

	# 弹窗按钮样式
	var continue_btn := settlement_panel.get_node("SettlementCenter/SettlementCard/SettlementMargin/VBox/ContinueButton")
	UITheme.style_primary_button(continue_btn)
	var restart_btn := ending_panel.get_node("EndingCenter/EndingCard/EndingMargin/VBox/RestartButton")
	UITheme.style_primary_button(restart_btn)

	# Header 公司列表按钮
	UITheme.style_menu_button(company_button, 13)
	company_button.custom_minimum_size = Vector2(90, 0)
	company_button.pressed.connect(_on_company_list_menu)


# ══════════════════════════════════════════
#  开场故事
# ══════════════════════════════════════════

func _show_intro() -> void:
	intro_label.text = INTRO_STORIES[randi() % INTRO_STORIES.size()]
	intro_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(intro_panel, "modulate", Color.WHITE, 1.0)


func _input(event: InputEvent) -> void:
	if intro_panel.visible and event is InputEventMouseButton and event.pressed:
		_dismiss_intro()


func _dismiss_intro() -> void:
	if not intro_panel.visible:
		return
	var tween := create_tween()
	tween.tween_property(intro_panel, "modulate", Color(1, 1, 1, 0), 0.6)
	tween.tween_callback(func():
		intro_panel.visible = false
		skill_select_panel.visible = true
		_setup_skill_select())


# ══════════════════════════════════════════
#  技能选择界面
# ══════════════════════════════════════════

func _setup_skill_select() -> void:
	for child in skill_buttons.get_children():
		child.queue_free()

	var skill_icons := {
		GameData.SkillType.BACKEND: "{ }",
		GameData.SkillType.FRONTEND: "< />",
		GameData.SkillType.ALGORITHM: "f(x)",
		GameData.SkillType.DATA_ENGINEERING: "ETL",
		GameData.SkillType.INFRASTRUCTURE: ">>>",
	}

	for skill_type in GameData.get_all_skill_types():
		var btn := Button.new()
		var icon_text: String = skill_icons.get(skill_type, "?")
		var name_text := GameData.get_skill_name(skill_type)
		var bonus_desc := GameData.get_skill_bonus_description(skill_type)
		btn.text = "%s\n%s\n%s" % [icon_text, name_text, bonus_desc]
		UITheme.style_skill_card(btn)
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
	# AP耗尽时 0.5s 后自动结算
	_check_auto_settle()


func _update_header() -> void:
	# 左: 周数
	week_label.text = "[b]第 %d 周[/b] / %d" % [game.week, GameData.MAX_WEEKS]

	# 中: 周进度条
	week_bar.text = "[center]%s[/center]" % UITheme.make_week_bar(game.week, GameData.MAX_WEEKS)

	# 右: 现金 + AP（三态：可用/工作锁定/已用）
	var free_energy := game.get_free_energy()
	var locked_energy := 0
	if game.current_job_listing:
		locked_energy = game.current_job_listing.job.energy_cost
	var cash_color := "#22C55E" if game.cash >= 2000 else ("#F59E0B" if game.cash >= 500 else "#EF4444")
	status_label.text = "[right][color=%s]$%s[/color]    AP %s[/right]" % [
		cash_color, _format_number(game.cash),
		UITheme.make_ap_indicator(free_energy, locked_energy, game.week_start_energy)]

	# 事件条
	var wind := game.get_wind_text()
	var event := game.get_market_event_text()
	if wind != "" or event != "":
		event_bar.visible = true
		var parts: Array[String] = []
		if wind != "":
			parts.append("  [color=#06B6D4]▶ %s[/color]" % wind)
		if event != "":
			parts.append("  [color=#F59E0B]▶ %s[/color]" % event)
		event_bar.text = "[center]%s[/center]" % "    ".join(parts)
	else:
		event_bar.visible = false


func _update_info_panel() -> void:
	for child in info_vbox.get_children():
		child.queue_free()

	_add_info_card_skills()
	_add_info_card_status()
	_add_info_card_job()
	_add_info_card_applications()
	_add_info_card_tools()
	_add_info_card_traits()
	if game.has_outsource_available():
		_add_info_card_outsource()

	# 清除未命中的闪烁 key
	_flash_skill_key = ""


## 角色属性卡（每行独立 HBox 对齐，支持单行闪烁）
func _add_info_card_skills() -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.make_card(UITheme.ACCENT_PRIMARY))
	card.layout_mode = 2

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)

	var title_label := RichTextLabel.new()
	title_label.bbcode_enabled = true
	title_label.fit_content = true
	title_label.scroll_active = false
	title_label.add_theme_font_size_override("normal_font_size", 14)
	title_label.text = "[color=#60A5FA][b]角色属性[/b][/color]"
	vbox.add_child(title_label)

	# 专业技能行（名称列固定宽度 80）
	for st in GameData.get_all_skill_types():
		var lv: int = game.skills[st]
		var progress := game.get_skill_xp_progress(st)
		var bar := UITheme.make_skill_bar(lv)
		var row := _make_skill_row_hbox(
			GameData.get_skill_name(st), "", lv, bar, progress, "skill_%d" % st)
		vbox.add_child(row)

	# 沟通 - 青色
	var comm_bar := UITheme.make_skill_bar(game.communication, GameData.MAX_GENERAL_SKILL_LEVEL)
	var comm_progress := game.get_general_skill_xp_progress(true)
	vbox.add_child(_make_skill_row_hbox(
		"沟通", "#06B6D4", game.communication, comm_bar, comm_progress, "communication"))

	# 面试技巧 - 紫色
	var int_bar := UITheme.make_skill_bar(game.interview_skill, GameData.MAX_GENERAL_SKILL_LEVEL)
	var int_progress := game.get_general_skill_xp_progress(false)
	vbox.add_child(_make_skill_row_hbox(
		"面试技巧", "#8B5CF6", game.interview_skill, int_bar, int_progress, "interview_skill"))

	card.add_child(vbox)
	info_vbox.add_child(card)

	if _flash_skill_key.begins_with("skill_") or _flash_skill_key == "communication" or _flash_skill_key == "interview_skill":
		_flash_skill_key = ""


## 创建对齐的技能行：名称(固定宽) | Lv | 进度条 | XP
func _make_skill_row_hbox(skill_name: String, name_color: String,
		lv: int, bar_bbcode: String, progress: String, row_key: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)

	# 列1: 技能名（固定宽 90，确保"数据工程""基础设施"等长名对齐）
	var col_name := RichTextLabel.new()
	col_name.bbcode_enabled = true
	col_name.fit_content = true
	col_name.scroll_active = false
	col_name.custom_minimum_size = Vector2(90, 0)
	col_name.size_flags_horizontal = 0
	col_name.add_theme_font_size_override("normal_font_size", 14)
	if name_color != "":
		col_name.text = "[color=%s]%s[/color]" % [name_color, skill_name]
	else:
		col_name.text = skill_name
		col_name.add_theme_color_override("default_color", UITheme.TEXT_PRIMARY)
	hbox.add_child(col_name)

	# 列2: 等级（固定宽 50）
	var col_lv := Label.new()
	col_lv.text = "Lv.%d" % lv
	col_lv.custom_minimum_size = Vector2(50, 0)
	col_lv.add_theme_font_size_override("font_size", 14)
	col_lv.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	hbox.add_child(col_lv)

	# 列3: 进度条（自适应）
	var col_bar := RichTextLabel.new()
	col_bar.bbcode_enabled = true
	col_bar.fit_content = true
	col_bar.scroll_active = false
	col_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_bar.add_theme_font_size_override("normal_font_size", 14)
	col_bar.text = bar_bbcode
	hbox.add_child(col_bar)

	# 列4: XP进度（固定宽 55，右对齐）
	var col_xp := Label.new()
	col_xp.text = progress
	col_xp.custom_minimum_size = Vector2(55, 0)
	col_xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col_xp.add_theme_font_size_override("font_size", 13)
	col_xp.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
	hbox.add_child(col_xp)

	# 闪烁
	if _flash_skill_key == row_key:
		hbox.modulate = Color(1.5, 1.5, 1.8, 1.0)
		var tween := create_tween()
		tween.tween_property(hbox, "modulate", Color.WHITE, 0.5).set_ease(Tween.EASE_OUT)

	return hbox


## 状态卡（每行2组 key-value 并排，行动力单独末行，支持单行闪烁）
func _add_info_card_status() -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.make_card(UITheme.ACCENT_SECONDARY))
	card.layout_mode = 2

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)

	var title_label := RichTextLabel.new()
	title_label.bbcode_enabled = true
	title_label.fit_content = true
	title_label.scroll_active = false
	title_label.add_theme_font_size_override("normal_font_size", 14)
	title_label.text = "[color=#60A5FA][b]状态[/b][/color]"
	vbox.add_child(title_label)

	# 第1行: 工作经验 | 大厂经验
	vbox.add_child(_make_status_2col(
		"工作经验", str(game.work_experience), "",
		"大厂经验", str(game.bigco_experience), ""))

	# 第2行: Gap时间 | 外包完成
	vbox.add_child(_make_status_2col(
		"Gap时间", str(game.gap_time), "",
		"外包完成", str(game.outsource_count), ""))

	# 第3行: 人际关系 | 个人作品（各自支持闪烁）
	var proj_val: String
	var proj_color := ""
	if game.personal_project_done:
		proj_val = "已完成"
		proj_color = "#22C55E"
	else:
		proj_val = "%d/%d" % [game.personal_project_progress, GameData.PERSONAL_PROJECT_COST]
	var row3 := _make_status_2col(
		"人际关系", "%d/%d" % [game.networking_points, GameData.MAX_NETWORKING_POINTS], "",
		"个人作品", proj_val, proj_color)
	# 闪烁人际关系或个人作品时闪整行
	if _flash_skill_key == "networking" or _flash_skill_key == "personal_project":
		row3.modulate = Color(1.5, 1.5, 1.8, 1.0)
		var tw := create_tween()
		tw.tween_property(row3, "modulate", Color.WHITE, 0.5).set_ease(Tween.EASE_OUT)
		_flash_skill_key = ""
	vbox.add_child(row3)

	# 末行: 行动力（单独占满宽）
	var free_energy := game.get_free_energy()
	var row_ap := _make_status_kv("行动力",
		"%d/%d" % [free_energy, game.week_start_energy], "#3B82F6")
	vbox.add_child(row_ap)

	if game.resume_faked:
		var warn := RichTextLabel.new()
		warn.bbcode_enabled = true
		warn.fit_content = true
		warn.scroll_active = false
		warn.add_theme_font_size_override("normal_font_size", 13)
		warn.text = "[color=#EF4444]简历包装中[/color] [color=#94A3B8]技能+1，面试30%翻车风险[/color]"
		vbox.add_child(warn)

	card.add_child(vbox)
	info_vbox.add_child(card)


## 单个 key-value 对
func _make_status_kv(label_text: String, value_text: String, value_color: String = "") -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var col_label := Label.new()
	col_label.text = label_text
	col_label.custom_minimum_size = Vector2(70, 0)
	col_label.add_theme_font_size_override("font_size", 14)
	col_label.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
	hbox.add_child(col_label)

	var col_value := Label.new()
	col_value.text = value_text
	col_value.add_theme_font_size_override("font_size", 14)
	if value_color != "":
		col_value.add_theme_color_override("font_color", Color(value_color))
	else:
		col_value.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	hbox.add_child(col_value)

	return hbox


## 一行放2组 key-value
func _make_status_2col(
		l1: String, v1: String, c1: String,
		l2: String, v2: String, c2: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)

	var left := _make_status_kv(l1, v1, c1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left)

	var right := _make_status_kv(l2, v2, c2)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right)

	return hbox


## 在职卡
func _add_info_card_job() -> void:
	var lines: Array[String] = []
	lines.append("[color=#60A5FA][b]在职[/b][/color]")
	lines.append("")
	var border_color: Color
	if game.current_job_listing:
		var job := game.current_job_listing
		lines.append("  [color=#E2E8F0]%s[/color] @ %s" % [job.job.title, job.company_def.name])
		lines.append("  周薪 [color=#22C55E]$%s[/color]  占用 %dAP" % [
			_format_number(job.actual_salary), job.job.energy_cost])
		if game.pending_quit:
			lines.append("  [color=#EF4444]已提出辞职，下周生效[/color]")
		border_color = UITheme.COLOR_SUCCESS
	else:
		lines.append("  [color=#94A3B8]未就业[/color]")
		border_color = UITheme.CAT_OTHER

	_add_info_card(lines, border_color)


## 求职进度卡
func _add_info_card_applications() -> void:
	var lines: Array[String] = []
	lines.append("[color=#60A5FA][b]求职进度[/b][/color]")
	lines.append("")
	var has_progress := false
	for listing_id in game.applications:
		var app: GameData.JobApplication = game.applications[listing_id]
		var dot := ""
		var status_text := ""
		match app.status:
			GameData.ApplicationStatus.APPLIED:
				dot = UITheme.status_dot(UITheme.ACCENT_PRIMARY)
				status_text = "已投递"
			GameData.ApplicationStatus.HAS_INTERVIEW:
				dot = UITheme.status_dot(UITheme.COLOR_SUCCESS)
				status_text = "[color=#22C55E]有面试机会[/color]"
			GameData.ApplicationStatus.INTERVIEWED:
				dot = UITheme.status_dot(UITheme.ACCENT_SECONDARY)
				status_text = "面试中"
			GameData.ApplicationStatus.OFFER:
				dot = UITheme.status_dot(UITheme.COLOR_GOLD)
				status_text = "[color=#FBBF24]Offer（剩余%d周）[/color]" % app.offer_weeks_left
			_:
				continue
		var title := app.listing.get_display_title()
		lines.append("  %s %s — %s" % [dot, title, status_text])
		has_progress = true
	if not has_progress:
		lines.append("  [color=#94A3B8]（无）[/color]")

	_add_info_card(lines, UITheme.ACCENT_PRIMARY)


## 工具卡
func _add_info_card_tools() -> void:
	var lines: Array[String] = []
	lines.append("[color=#60A5FA][b]工具 [%d/%d][/b][/color]" % [
		game.owned_tools.size(), GameData.MAX_TOOLS])
	lines.append("")
	if game.owned_tools.is_empty():
		lines.append("  [color=#94A3B8]（无）[/color]")
	else:
		for tid in game.owned_tools:
			var tdef := game._find_tool_def(tid)
			if tdef:
				lines.append("  %s [color=#E2E8F0]%s[/color] [color=#94A3B8]%s[/color]" % [
					tdef.icon, tdef.name, tdef.description])

	_add_info_card(lines, UITheme.ACCENT_PURPLE)


## 特质卡
func _add_info_card_traits() -> void:
	var lines: Array[String] = []
	lines.append("[color=#60A5FA][b]特质[/b][/color]")
	lines.append("")
	if game.active_traits.is_empty():
		lines.append("  [color=#94A3B8]（无）[/color]")
	else:
		for tid in game.active_traits:
			var tdef := game._find_trait_def(tid)
			if tdef:
				lines.append("  [color=#FBBF24]%s[/color] [color=#94A3B8]%s[/color]" % [
					tdef.name, tdef.effect_text])

	_add_info_card(lines, UITheme.COLOR_GOLD)


## 外包机会卡
func _add_info_card_outsource() -> void:
	var lines: Array[String] = []
	lines.append("[color=#F59E0B][b]外包机会[/b][/color]")
	lines.append("")
	lines.append("  %s" % game.get_outsource_info())
	_add_info_card(lines, UITheme.COLOR_WARNING)


## 创建信息卡片，flash_key 匹配时触发闪烁
func _add_info_card(lines: Array[String], left_color: Color, card_flash_key: String = "") -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.make_card(left_color))
	card.layout_mode = 2

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.layout_mode = 2
	label.add_theme_color_override("default_color", UITheme.TEXT_SECONDARY)
	label.add_theme_font_size_override("normal_font_size", 14)
	label.text = "\n".join(lines)

	card.add_child(label)
	info_vbox.add_child(card)

	# 闪烁动画
	if card_flash_key != "" and _flash_skill_key == card_flash_key:
		_flash_skill_key = ""
		_play_card_flash(card)


# ══════════════════════════════════════════
#  行动按钮列表（左侧面板）
# ══════════════════════════════════════════

func _update_action_list() -> void:
	for child in action_list.get_children():
		child.queue_free()

	var free_energy := game.get_free_energy()

	# ── 学习 ──
	_add_section_label("学习")
	for st in GameData.get_all_skill_types():
		var lv: int = game.skills[st]
		var count: int = game.weekly_study_count.get(st, 0)
		var fatigue_hint := ""
		if count >= GameData.STUDY_FATIGUE_THRESHOLD + game.fatigue_bonus_this_week - 1:
			fatigue_hint = "  ⚡疲劳"
		var label := "%s  +1XP%s" % [GameData.get_skill_name(st), fatigue_hint]
		var enabled := free_energy >= 1 and lv < GameData.MAX_SKILL_LEVEL
		_add_action_button(label, _on_study_skill.bind(st), UITheme.CAT_STUDY, enabled, "-1AP")

	# 沟通
	var comm_count: int = game.weekly_study_count.get("communication", 0)
	var comm_fatigue := ""
	if comm_count >= GameData.STUDY_FATIGUE_THRESHOLD + game.fatigue_bonus_this_week - 1:
		comm_fatigue = "  ⚡疲劳"
	_add_action_button(
		"沟通  +1XP%s" % comm_fatigue,
		_on_study_communication, UITheme.CAT_STUDY,
		free_energy >= 1 and game.communication < GameData.MAX_GENERAL_SKILL_LEVEL, "-1AP")

	# 面试技巧
	var int_count: int = game.weekly_study_count.get("interview_skill", 0)
	var int_fatigue := ""
	if int_count >= GameData.STUDY_FATIGUE_THRESHOLD + game.fatigue_bonus_this_week - 1:
		int_fatigue = "  ⚡疲劳"
	_add_action_button(
		"面试技巧  +1XP%s" % int_fatigue,
		_on_study_interview, UITheme.CAT_STUDY,
		free_energy >= 1 and game.interview_skill < GameData.MAX_GENERAL_SKILL_LEVEL, "-1AP")

	# ── 求职 ──
	_add_section_label("求职")
	_add_action_button("精投简历", _on_focused_apply_menu, UITheme.CAT_JOB,
		free_energy >= 1, "-1AP")
	_add_action_button("海投简历", _on_mass_apply, UITheme.CAT_JOB,
		free_energy >= 1, "-1AP", "随机投递%d个岗位" % GameData.MASS_APPLY_COUNT)

	# 面试
	var faked_tag := "  ★包装" if game.resume_faked else ""
	for lid in game.applications:
		var app: GameData.JobApplication = game.applications[lid]
		if app.status == GameData.ApplicationStatus.HAS_INTERVIEW:
			var title := app.listing.get_display_title()
			var rate := game.calc_interview_pass_rate(app.listing)
			var iv_cost := game.get_interview_cost()
			var faked_tip := ""
			if game.resume_faked:
				faked_tip = "包装简历生效中（技能+1），面试有30%翻车风险"
			_add_action_button(
				"面试：%s  ≈%.0f%%%s" % [title, rate * 100, faked_tag],
				_on_interview.bind(lid), UITheme.CAT_JOB,
				free_energy >= iv_cost, "-%dAP" % iv_cost, faked_tip)

	if not game.resume_faked:
		_add_action_button("包装简历", _on_fake_resume, UITheme.CAT_JOB,
			free_energy >= 2, "-2AP", "技能显示+1，但面试有30%翻车风险")
	else:
		_add_action_button("取消包装  ★生效中", _on_cancel_fake_resume, UITheme.CAT_JOB, true)

	# ── 社交 ──
	_add_section_label("社交")
	var net_gain := 2 if game.has_tool("linkedin") else 1
	_add_action_button(
		"人际关系  +%d" % net_gain,
		_on_networking, UITheme.CAT_SOCIAL,
		free_energy >= 1 and game.networking_points < GameData.MAX_NETWORKING_POINTS, "-1AP")

	var can_project := game.can_do_personal_project()
	var proj_text: String
	var proj_cost: String
	if game.personal_project_done:
		proj_text = "个人作品  ✔已完成"
		proj_cost = ""
	else:
		proj_text = "个人作品  +1进度  (%d/%d)" % [
			game.personal_project_progress, GameData.PERSONAL_PROJECT_COST]
		proj_cost = "-1AP"
	_add_action_button(proj_text, _on_personal_project, UITheme.CAT_SOCIAL,
		can_project and free_energy >= 1, proj_cost)

	# ── 生存 ──
	_add_section_label("生存")
	_add_action_button(
		"打零工·兼职  +$%s" % _format_number(game.get_gig_income(false)),
		_on_gig_parttime, UITheme.CAT_SURVIVAL,
		free_energy >= GameData.GIG_ENERGY_PARTTIME, "-3AP")
	_add_action_button(
		"打零工·全职  +$%s" % _format_number(game.get_gig_income(true)),
		_on_gig_fulltime, UITheme.CAT_SURVIVAL,
		free_energy >= GameData.GIG_ENERGY_FULLTIME, "-5AP")

	if game.has_outsource_available():
		var oc := game.current_outsource
		_add_action_button(
			"接外包·%s  +$%s" % [oc.get_level_text(), _format_number(oc.income)],
			_on_take_outsource, UITheme.CAT_SURVIVAL,
			free_energy >= oc.energy_cost, "-%dAP" % oc.energy_cost)

	# ── 其他 ──
	_add_section_label("其他")
	_add_action_button("逛二手市场", _on_shop_menu, UITheme.CAT_OTHER,
		free_energy >= GameData.SHOP_ENERGY_COST, "-1AP")

	# Offer处理
	var has_offers := false
	for lid in game.applications:
		var app: GameData.JobApplication = game.applications[lid]
		if app.status == GameData.ApplicationStatus.OFFER:
			if not has_offers:
				_add_section_label("Offer")
				has_offers = true
			var title := app.listing.get_display_title()
			var accept_btn := Button.new()
			accept_btn.text = "接受Offer：%s（$%s/周）" % [title, _format_number(app.listing.actual_salary)]
			UITheme.style_gold_button(accept_btn)
			accept_btn.pressed.connect(_on_accept_offer.bind(lid))
			action_list.add_child(accept_btn)

			var reject_btn := Button.new()
			reject_btn.text = "拒绝Offer：%s" % title
			UITheme.style_danger_button(reject_btn)
			reject_btn.pressed.connect(_on_reject_offer.bind(lid))
			action_list.add_child(reject_btn)

	if game.current_job_listing and not game.pending_quit:
		var quit_btn := Button.new()
		quit_btn.text = "辞职（下周生效）"
		UITheme.style_danger_button(quit_btn)
		quit_btn.pressed.connect(_on_quit)
		action_list.add_child(quit_btn)

	# 结束本周（手动提前结算）
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	action_list.add_child(spacer)

	var settle_btn := Button.new()
	settle_btn.text = "结 束 本 周"
	UITheme.style_primary_button(settle_btn, 15)
	settle_btn.custom_minimum_size = Vector2(0, 38)
	settle_btn.pressed.connect(_on_settle_week)
	action_list.add_child(settle_btn)


func _add_section_label(text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 2)
	action_list.add_child(spacer)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(0, 18)
	label.layout_mode = 2
	label.add_theme_font_size_override("normal_font_size", 12)
	label.add_theme_color_override("default_color", UITheme.TEXT_TITLE)
	label.text = "[b]%s[/b]" % text
	action_list.add_child(label)


## 添加行动按钮，cost_text 右对齐显示，tooltip_text 悬浮提示
func _add_action_button(label_text: String, callback: Callable,
		category_color: Color, enabled: bool = true,
		cost_text: String = "", tooltip_text: String = "") -> void:
	var btn := Button.new()
	# 不使用 Button 自带的 text，改用内嵌 HBoxContainer 实现左右布局
	btn.text = ""
	UITheme.style_action_button(btn, category_color)
	btn.disabled = not enabled
	btn.pressed.connect(callback)
	if tooltip_text != "":
		btn.tooltip_text = tooltip_text

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left_label := Label.new()
	left_label.text = label_text
	left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_label.add_theme_font_size_override("font_size", 14)
	left_label.add_theme_color_override("font_color",
		UITheme.BTN_TEXT_DISABLED if not enabled else UITheme.TEXT_PRIMARY)
	left_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(left_label)

	if cost_text != "":
		var right_label := Label.new()
		right_label.text = cost_text
		right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right_label.add_theme_font_size_override("font_size", 12)
		right_label.add_theme_color_override("font_color",
			UITheme.BTN_TEXT_DISABLED if not enabled else UITheme.TEXT_SECONDARY)
		right_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(right_label)

	margin.add_child(hbox)
	btn.add_child(margin)
	action_list.add_child(btn)


# ══════════════════════════════════════════
#  行动回调
# ══════════════════════════════════════════

func _on_study_skill(skill_type: GameData.SkillType) -> void:
	game.action_study_skill(skill_type)
	_flash_skill_key = "skill_%d" % skill_type
	_refresh_ui()

func _on_study_communication() -> void:
	game.action_study_communication()
	_flash_skill_key = "communication"
	_refresh_ui()

func _on_study_interview() -> void:
	game.action_study_interview()
	_flash_skill_key = "interview_skill"
	_refresh_ui()

func _on_focused_apply_menu() -> void:
	_shop_mode = false
	_company_mode = false
	sub_menu_title.text = "[b]选择投递岗位[/b]"
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
	_flash_skill_key = "networking"
	_refresh_ui()

func _on_personal_project() -> void:
	game.action_personal_project()
	_flash_skill_key = "personal_project"
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

	if game.resume_faked:
		var hint := RichTextLabel.new()
		hint.bbcode_enabled = true
		hint.fit_content = true
		hint.scroll_active = false
		hint.layout_mode = 2
		hint.add_theme_font_size_override("normal_font_size", 13)
		hint.text = "[color=#F59E0B]★ 简历包装生效中：技能显示+1，通过率已提升[/color]"
		sub_menu_list.add_child(hint)

	# 筛选可投递岗位并计算通过率
	var apply_items: Array[Dictionary] = []
	for listing in game.current_listings:
		if game.applications.has(listing.listing_id):
			var app: GameData.JobApplication = game.applications[listing.listing_id]
			if app.status != GameData.ApplicationStatus.REJECTED:
				continue
		var rate := game.calc_resume_pass_rate(listing)
		apply_items.append({"listing": listing, "rate": rate})

	# 按通过率降序，同率按薪资降序
	apply_items.sort_custom(func(a, b):
		if a.rate != b.rate:
			return a.rate > b.rate
		return a.listing.actual_salary > b.listing.actual_salary)

	for item in apply_items:
		var listing: GameData.JobListing = item.listing
		var rate: float = item.rate
		_add_apply_listing_button(listing, rate)

	_add_close_button()


## 创建两行排版的岗位投递按钮
func _add_apply_listing_button(listing: GameData.JobListing, rate: float) -> void:
	var btn := Button.new()
	btn.text = ""
	# 用透明 StyleBox，内容完全由内嵌控件控制
	var sb_normal := UITheme.make_flat(UITheme.BG_CARD, UITheme.CORNER_SM,
		UITheme.BORDER_BLUE, 1, 14, 8, 14, 8)
	var sb_hover := UITheme.make_flat(UITheme.BTN_BG_HOVER, UITheme.CORNER_SM,
		UITheme.ACCENT_PRIMARY, 1, 14, 8, 14, 8)
	var sb_pressed := UITheme.make_flat(UITheme.BTN_BG_PRESSED, UITheme.CORNER_SM,
		UITheme.ACCENT_PRIMARY, 1, 14, 8, 14, 8)
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.custom_minimum_size = Vector2(0, 58)
	btn.pressed.connect(_on_apply_to.bind(listing.listing_id))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)

	# 第一行：岗位名 @ 公司  薪资
	var line1 := RichTextLabel.new()
	line1.bbcode_enabled = true
	line1.fit_content = true
	line1.scroll_active = false
	line1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line1.add_theme_font_size_override("normal_font_size", 15)
	line1.text = "[color=#E2E8F0]%s[/color]  [color=#94A3B8]@[/color]  %s    [color=#22C55E]$%s/周[/color]" % [
		listing.job.title, listing.company_def.name,
		_format_number(listing.actual_salary)]
	vbox.add_child(line1)

	# 第二行：通过率（左）  技能需求（右，颜色标注）
	var line2 := RichTextLabel.new()
	line2.bbcode_enabled = true
	line2.fit_content = true
	line2.scroll_active = false
	line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line2.add_theme_font_size_override("normal_font_size", 13)

	var rate_color := "#22C55E" if rate >= 0.5 else ("#F59E0B" if rate >= 0.3 else "#EF4444")
	var req_parts: Array[String] = []
	for req in listing.actual_skill_requirements:
		var player_lv: int = game.skills[req.skill]
		if game.resume_faked:
			player_lv += 1
		var color := "#22C55E" if player_lv >= req.level else "#EF4444"
		req_parts.append("[color=%s]%s Lv.%d[/color]" % [
			color, GameData.get_skill_name(req.skill), req.level])
	if listing.actual_comm_required > 0:
		var comm_lv: int = game.communication
		if game.resume_faked:
			comm_lv += 1
		var color := "#22C55E" if comm_lv >= listing.actual_comm_required else "#EF4444"
		req_parts.append("[color=%s]沟通 Lv.%d[/color]" % [color, listing.actual_comm_required])
	line2.text = "[color=%s]≈%.0f%%[/color]    %s" % [
		rate_color, rate * 100, "  ".join(req_parts)]
	vbox.add_child(line2)

	margin.add_child(vbox)
	btn.add_child(margin)
	sub_menu_list.add_child(btn)


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
	sub_menu_title.text = "[b]公司列表[/b]"
	_populate_company_list()
	sub_menu_panel.visible = true


func _populate_company_list() -> void:
	for child in sub_menu_list.get_children():
		child.queue_free()

	var sorted_companies: Array[GameData.CompanyDef] = []
	for c in game.companies:
		sorted_companies.append(c)
	sorted_companies.sort_custom(func(a, b): return a.scale < b.scale)

	for company in sorted_companies:
		var listing_count := game.get_company_listing_count(company.id)
		var scale_tag := _make_scale_tag(company.scale)
		var btn := Button.new()
		btn.text = "%s %s  福利：%s  经营：%s  倾向：%s  在招：%d" % [
			scale_tag, company.name,
			company.get_benefit_text(), company.get_status_text(),
			company.get_preferred_skills_text(), listing_count]
		UITheme.style_menu_button(btn)
		btn.pressed.connect(_on_company_detail.bind(company))
		sub_menu_list.add_child(btn)

	_add_close_button()


func _make_scale_tag(scale: GameData.CompanyScale) -> String:
	match scale:
		GameData.CompanyScale.BIG: return "[大厂]"
		GameData.CompanyScale.MEDIUM: return "[中厂]"
		GameData.CompanyScale.SMALL: return "[小厂]"
		_: return ""


func _on_company_detail(company: GameData.CompanyDef) -> void:
	for child in sub_menu_list.get_children():
		child.queue_free()

	sub_menu_title.text = "[b]%s 详情[/b]" % company.name

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.layout_mode = 2
	info.add_theme_font_size_override("normal_font_size", 15)
	info.add_theme_color_override("default_color", UITheme.TEXT_PRIMARY)

	var lines: Array[String] = []
	lines.append("[color=#60A5FA][b]%s[/b][/color]" % company.name)
	lines.append("")
	lines.append("规模：%s" % company.get_scale_text())
	lines.append("福利水平：%s（薪资倍率 ×%.2f）" % [company.get_benefit_text(), company.get_salary_multiplier()])
	lines.append("经营状况：%s" % company.get_status_text())
	lines.append("倾向技能：%s" % company.get_preferred_skills_text())
	lines.append("")
	lines.append("[color=#60A5FA][b]当前在招岗位[/b][/color]")

	var found := false
	for listing in game.current_listings:
		if listing.company_def.id == company.id:
			lines.append("  · %s  [color=#22C55E]$%s/周[/color]  需要：%s" % [
				listing.job.title,
				_format_number(listing.actual_salary),
				listing.get_requirements_text()])
			found = true
	if not found:
		lines.append("  [color=#94A3B8]暂无在招岗位[/color]")

	info.text = "\n".join(lines)
	sub_menu_list.add_child(info)

	var back_btn := Button.new()
	back_btn.text = "← 返回公司列表"
	UITheme.style_menu_button(back_btn, 15)
	back_btn.pressed.connect(func():
		sub_menu_title.text = "[b]公司列表[/b]"
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
	sub_menu_title.text = "[b]二手市场[/b]  [color=#94A3B8]现金: $%s[/color]" % _format_number(game.cash)
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
		UITheme.style_menu_button(btn)
		btn.disabled = not can_buy
		if game.owned_tools.size() < GameData.MAX_TOOLS:
			btn.pressed.connect(_on_buy_tool.bind(tool_id))
		else:
			btn.pressed.connect(_on_replace_tool_menu.bind(tool_id))
		sub_menu_list.add_child(btn)

	if game.owned_tools.size() >= GameData.MAX_TOOLS:
		var hint := RichTextLabel.new()
		hint.bbcode_enabled = true
		hint.fit_content = true
		hint.scroll_active = false
		hint.layout_mode = 2
		hint.add_theme_font_size_override("normal_font_size", 13)
		hint.text = "[color=#F59E0B]背包已满，购买新工具需要替换一个旧工具[/color]"
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
	sub_menu_title.text = "[b]选择要替换的工具[/b]  [color=#94A3B8]购买 %s[/color]" % new_def.name

	for old_id in game.owned_tools:
		var old_def := game._find_tool_def(old_id)
		if old_def == null:
			continue
		var btn := Button.new()
		btn.text = "替换 %s %s（%s）" % [old_def.icon, old_def.name, old_def.description]
		UITheme.style_menu_button(btn, 15)
		btn.pressed.connect(_on_replace_tool.bind(old_id, new_tool_id))
		sub_menu_list.add_child(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "← 取消"
	UITheme.style_menu_button(cancel_btn, 15)
	cancel_btn.pressed.connect(func():
		_replacing_tool_id = ""
		sub_menu_title.text = "[b]二手市场[/b]  [color=#94A3B8]现金: $%s[/color]" % _format_number(game.cash)
		_populate_shop())
	sub_menu_list.add_child(cancel_btn)


func _on_replace_tool(old_id: String, new_id: String) -> void:
	game.action_replace_tool(old_id, new_id)
	sub_menu_panel.visible = false
	_refresh_ui()


# ══════════════════════════════════════════
#  结算与结局
# ══════════════════════════════════════════

var _auto_settle_timer: SceneTreeTimer = null

func _check_auto_settle() -> void:
	var free_energy := game.get_free_energy()
	# 还有未处理的 Offer 不自动结算
	var has_pending_offer := false
	for lid in game.applications:
		var app: GameData.JobApplication = game.applications[lid]
		if app.status == GameData.ApplicationStatus.OFFER:
			has_pending_offer = true
			break
	if free_energy <= 0 and not has_pending_offer and not settlement_panel.visible:
		if _auto_settle_timer == null:
			_auto_settle_timer = get_tree().create_timer(0.5)
			_auto_settle_timer.timeout.connect(_on_settle_week)

func _on_settle_week() -> void:
	_auto_settle_timer = null
	if settlement_panel.visible or ending_panel.visible:
		return
	var result := game.settle_week()
	_show_settlement(result)


func _show_settlement(result: GameState.WeekSettlement) -> void:
	var lines: Array[String] = []
	lines.append("[center][color=#60A5FA][b]第 %d 周结算[/b][/color][/center]" % (game.week - 1))
	lines.append("")

	if result.salary_earned > 0:
		lines.append("[color=#22C55E]▲ 工资收入  +$%s[/color]" % _format_number(result.salary_earned))
	lines.append("[color=#EF4444]▼ 生活支出  -$%s[/color]" % _format_number(result.living_cost))
	if result.tool_cost > 0:
		lines.append("[color=#EF4444]▼ 工具费用  -$%s[/color]" % _format_number(result.tool_cost))

	lines.append("")
	var arrow_color := "#22C55E" if result.cash_after >= result.cash_before else "#EF4444"
	lines.append("现金  $%s  [color=%s]→[/color]  $%s" % [
		_format_number(result.cash_before), arrow_color, _format_number(result.cash_after)])
	lines.append("")

	if result.did_quit:
		lines.append("[color=#F59E0B]你已离职[/color]")
		lines.append("")

	for note in result.notifications:
		lines.append(note)

	if result.expired_offers.size() > 0:
		for offer in result.expired_offers:
			lines.append("[color=#F59E0B]⏰ Offer已过期：%s[/color]" % offer)

	if result.new_traits.size() > 0:
		for tid in result.new_traits:
			var tdef := game._find_trait_def(tid)
			if tdef:
				lines.append("[color=#FBBF24]★ 获得特质：%s — %s[/color]" % [tdef.name, tdef.effect_text])

	if result.lost_traits.size() > 0:
		for tid in result.lost_traits:
			var tdef := game._find_trait_def(tid)
			if tdef:
				lines.append("[color=#94A3B8]☆ 失去特质：%s[/color]" % tdef.name)

	if result.event_name != "":
		lines.append("")
		lines.append("[color=#06B6D4]%s[/color]" % result.event_name)
		lines.append("  [color=#94A3B8]%s[/color]" % result.event_desc)

	settlement_label.text = "\n".join(lines)
	_populate_settlement_offers()
	settlement_panel.visible = true


func _on_settlement_continue() -> void:
	settlement_panel.visible = false
	if game.week > GameData.MAX_WEEKS:
		_show_ending()
	elif game.cash < 0:
		_show_ending()
	else:
		_refresh_ui()


func _populate_settlement_offers() -> void:
	for child in settlement_offer_box.get_children():
		child.queue_free()
	for lid in game.applications:
		var app: GameData.JobApplication = game.applications[lid]
		if app.status == GameData.ApplicationStatus.OFFER:
			var title := app.listing.get_display_title()
			var btn := Button.new()
			btn.text = "接受Offer：%s（$%s/周）" % [title, _format_number(app.listing.actual_salary)]
			UITheme.style_gold_button(btn)
			btn.pressed.connect(_on_settlement_accept_offer.bind(lid))
			settlement_offer_box.add_child(btn)


func _on_settlement_accept_offer(listing_id: String) -> void:
	game.action_accept_offer(listing_id)
	_populate_settlement_offers()


func _show_ending() -> void:
	var rank := game.get_ending()
	var projected := game.calc_projected_income()
	var rank_letter := GameData.get_rank_letter(rank)
	var rank_name := GameData.get_ending_name(rank)
	var rank_desc := GameData.get_ending_description(rank)

	var rank_color := _get_rank_color(rank_letter)

	var lines: Array[String] = []
	lines.append("")
	lines.append("[center][color=%s][b][font_size=48]%s[/font_size][/b][/color][/center]" % [
		rank_color, rank_letter])
	lines.append("[center][color=%s][b]%s[/b][/color][/center]" % [rank_color, rank_name])
	lines.append("")

	# 最终状态
	lines.append("[color=#60A5FA][b]最终状态[/b][/color]")
	if game.current_job_listing:
		lines.append("  在职：%s @ %s  周薪 [color=#22C55E]$%s[/color]" % [
			game.current_job_listing.job.title,
			game.current_job_listing.company_def.name,
			_format_number(game.current_job_listing.actual_salary)])
	else:
		lines.append("  [color=#94A3B8]未就业[/color]")
	lines.append("  剩余现金：$%s" % _format_number(game.cash))
	lines.append("")

	# 预估年收入
	lines.append("[color=#60A5FA][b]预估年收入[/b][/color]")
	if game.current_job_listing:
		var weekly_net := game.current_job_listing.actual_salary - GameData.WEEKLY_LIVING_COST
		lines.append("  周薪 $%s - 生活费 $%s = 每周净收入 $%s" % [
			_format_number(game.current_job_listing.actual_salary),
			_format_number(GameData.WEEKLY_LIVING_COST),
			_format_number(weekly_net)])
		lines.append("  年净收入：$%s × 52 = [color=#22C55E]$%s[/color]" % [
			_format_number(weekly_net), _format_number(weekly_net * 52)])
		lines.append("  加上剩余现金：[color=#FBBF24]$%s[/color]" % _format_number(projected))
	else:
		lines.append("  预估收入：$%s" % _format_number(projected))
	lines.append("")

	# 成就统计
	lines.append("[color=#60A5FA][b]成就[/b][/color]")
	var best_skill_name := ""
	var best_skill_lv := 0
	for st in GameData.get_all_skill_types():
		if game.skills[st] > best_skill_lv:
			best_skill_lv = game.skills[st]
			best_skill_name = GameData.get_skill_name(st)
	lines.append("  技能最高：%s Lv.%d" % [best_skill_name, best_skill_lv])
	lines.append("  工作经验：%d周    外包完成：%d次" % [game.work_experience, game.outsource_count])
	lines.append("  投递：%d  面试：%d  Offer：%d  被拒：%d" % [
		game.stats_total_applications, game.stats_total_interviews,
		game.stats_total_offers, game.stats_total_rejections])
	if game.stats_highest_offer_salary > 0:
		lines.append("  最高薪Offer：[color=#FBBF24]$%s/周[/color]" % _format_number(game.stats_highest_offer_salary))
	lines.append("  零工/外包总收入：$%s" % _format_number(game.stats_total_gig_income))
	lines.append("  学习总次数：%d    人际关系：%d" % [game.stats_total_study_count, game.networking_points])

	if game.active_traits.size() > 0:
		var trait_names: Array[String] = []
		for tid in game.active_traits:
			var tdef := game._find_trait_def(tid)
			if tdef:
				trait_names.append(tdef.name)
		lines.append("  获得特质：[color=#FBBF24]%s[/color]" % "、".join(trait_names))

	lines.append("")
	lines.append("[center][i][color=#94A3B8]\"%s\"[/color][/i][/center]" % rank_desc)

	ending_label.text = "\n".join(lines)
	ending_panel.visible = true


func _on_restart() -> void:
	ending_panel.visible = false
	settlement_panel.visible = false
	sub_menu_panel.visible = false
	skill_select_panel.visible = false
	game = GameState.new()
	intro_panel.visible = true
	_show_intro()


# ══════════════════════════════════════════
#  工具函数
# ══════════════════════════════════════════

func _add_close_button() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	sub_menu_list.add_child(spacer)

	var btn := Button.new()
	btn.text = "关闭"
	UITheme.style_primary_button(btn, 15)
	btn.custom_minimum_size = Vector2(0, 38)
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


func _get_rank_color(rank_letter: String) -> String:
	match rank_letter:
		"S": return "#FBBF24"
		"A": return "#22C55E"
		"B": return "#3B82F6"
		"C": return "#06B6D4"
		"D": return "#F59E0B"
		_: return "#EF4444"


## 卡片闪烁动画：短暂高亮边框后恢复
func _play_card_flash(card: PanelContainer) -> void:
	var tween := create_tween()
	# 闪烁：先变亮再恢复
	card.modulate = Color(1.4, 1.4, 1.6, 1.0)
	tween.tween_property(card, "modulate", Color.WHITE, 0.5).set_ease(Tween.EASE_OUT)
