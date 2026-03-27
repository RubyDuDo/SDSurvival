## UI主题构建器 - 蓝色科技风色块风格
class_name UITheme

# ══════════════════════════════════════════
#  色彩体系
# ══════════════════════════════════════════

# 背景
const BG_DEEP := Color("#0A0E1A")
const BG_PANEL := Color("#111827")
const BG_CARD := Color("#1A2332")

# 边框 / 分隔
const BORDER_BLUE := Color("#1E3A5F")
const BORDER_LIGHT := Color("#2A4A6F")

# 强调色
const ACCENT_PRIMARY := Color("#3B82F6")    # 主蓝
const ACCENT_SECONDARY := Color("#06B6D4")  # 青
const ACCENT_PURPLE := Color("#8B5CF6")     # 紫
const ACCENT_ORANGE := Color("#F97316")     # 橙

# 语义色
const COLOR_SUCCESS := Color("#22C55E")
const COLOR_WARNING := Color("#F59E0B")
const COLOR_DANGER := Color("#EF4444")
const COLOR_GOLD := Color("#FBBF24")

# 文字
const TEXT_PRIMARY := Color("#E2E8F0")
const TEXT_SECONDARY := Color("#94A3B8")
const TEXT_TITLE := Color("#60A5FA")
const TEXT_HEADER := Color("#F8FAFC")

# 按钮
const BTN_BG := Color("#1E293B")
const BTN_BG_HOVER := Color("#2D3B4F")
const BTN_BG_PRESSED := Color("#1A2540")
const BTN_BG_DISABLED := Color("#151C28")
const BTN_TEXT_DISABLED := Color("#4A5568")

# 分类色条 (按钮左边框)
const CAT_STUDY := ACCENT_PRIMARY      # 学习 - 蓝
const CAT_JOB := ACCENT_SECONDARY      # 求职 - 青
const CAT_SOCIAL := ACCENT_PURPLE      # 社交 - 紫
const CAT_SURVIVAL := ACCENT_ORANGE    # 生存 - 橙
const CAT_OTHER := Color("#64748B")    # 其他 - 灰蓝

# 圆角
const CORNER_SM := 4
const CORNER_MD := 6
const CORNER_LG := 8

# ══════════════════════════════════════════
#  StyleBox 工厂方法
# ══════════════════════════════════════════

static func make_flat(bg: Color, corner: int = CORNER_MD,
		border_color: Color = Color.TRANSPARENT, border_width: int = 0,
		margin_left: int = 0, margin_top: int = 0,
		margin_right: int = 0, margin_bottom: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = corner
	sb.corner_radius_top_right = corner
	sb.corner_radius_bottom_left = corner
	sb.corner_radius_bottom_right = corner
	if border_width > 0:
		sb.border_color = border_color
		sb.border_width_left = border_width
		sb.border_width_top = border_width
		sb.border_width_right = border_width
		sb.border_width_bottom = border_width
	sb.content_margin_left = margin_left
	sb.content_margin_top = margin_top
	sb.content_margin_right = margin_right
	sb.content_margin_bottom = margin_bottom
	return sb


## 带左侧分类色条的按钮样式
static func make_category_btn(left_color: Color, state: String = "normal") -> StyleBoxFlat:
	var bg: Color
	match state:
		"hover": bg = BTN_BG_HOVER
		"pressed": bg = BTN_BG_PRESSED
		"disabled": bg = BTN_BG_DISABLED
		_: bg = BTN_BG
	var sb := make_flat(bg, CORNER_SM, Color.TRANSPARENT, 0, 10, 5, 8, 5)
	sb.border_color = left_color
	sb.border_width_left = 3
	return sb


## 信息卡片样式
static func make_card(left_border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := make_flat(BG_CARD, CORNER_MD, BORDER_BLUE, 1, 12, 10, 12, 10)
	if left_border_color != Color.TRANSPARENT:
		sb.border_width_left = 3
		sb.border_color = left_border_color
	return sb


## 弹窗面板样式
static func make_popup_panel() -> StyleBoxFlat:
	var sb := make_flat(BG_PANEL, CORNER_LG, ACCENT_PRIMARY, 1, 0, 0, 0, 0)
	sb.border_width_top = 2
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = ACCENT_PRIMARY
	return sb


# ══════════════════════════════════════════
#  应用主题到控件
# ══════════════════════════════════════════

## 给按钮应用分类色条样式
static func style_action_button(btn: Button, category_color: Color, font_size: int = 14) -> void:
	btn.add_theme_stylebox_override("normal", make_category_btn(category_color, "normal"))
	btn.add_theme_stylebox_override("hover", make_category_btn(category_color, "hover"))
	btn.add_theme_stylebox_override("pressed", make_category_btn(category_color, "pressed"))
	btn.add_theme_stylebox_override("disabled", make_category_btn(category_color, "disabled"))
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", TEXT_SECONDARY)
	btn.add_theme_color_override("font_disabled_color", BTN_TEXT_DISABLED)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.custom_minimum_size = Vector2(0, 32)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT


## 醒目按钮 (结束本周 / 继续 / 再来一局)
static func style_primary_button(btn: Button, font_size: int = 18) -> void:
	btn.add_theme_stylebox_override("normal",
		make_flat(ACCENT_PRIMARY, CORNER_MD, Color.TRANSPARENT, 0, 16, 10, 16, 10))
	btn.add_theme_stylebox_override("hover",
		make_flat(ACCENT_PRIMARY.lightened(0.15), CORNER_MD, Color.TRANSPARENT, 0, 16, 10, 16, 10))
	btn.add_theme_stylebox_override("pressed",
		make_flat(ACCENT_PRIMARY.darkened(0.15), CORNER_MD, Color.TRANSPARENT, 0, 16, 10, 16, 10))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_font_size_override("font_size", font_size)
	btn.custom_minimum_size = Vector2(0, 46)


## 金色按钮 (接受Offer)
static func style_gold_button(btn: Button, font_size: int = 16) -> void:
	btn.add_theme_stylebox_override("normal",
		make_flat(Color("#92400E"), CORNER_MD, COLOR_GOLD, 1, 14, 8, 14, 8))
	btn.add_theme_stylebox_override("hover",
		make_flat(Color("#A3510F"), CORNER_MD, COLOR_GOLD, 1, 14, 8, 14, 8))
	btn.add_theme_stylebox_override("pressed",
		make_flat(Color("#7C3610"), CORNER_MD, COLOR_GOLD, 1, 14, 8, 14, 8))
	btn.add_theme_color_override("font_color", COLOR_GOLD)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.custom_minimum_size = Vector2(0, 42)


## 危险按钮 (拒绝Offer / 辞职)
static func style_danger_button(btn: Button, font_size: int = 15) -> void:
	btn.add_theme_stylebox_override("normal",
		make_flat(Color("#3B1111"), CORNER_MD, COLOR_DANGER.darkened(0.3), 1, 14, 8, 14, 8))
	btn.add_theme_stylebox_override("hover",
		make_flat(Color("#4B1515"), CORNER_MD, COLOR_DANGER, 1, 14, 8, 14, 8))
	btn.add_theme_color_override("font_color", COLOR_DANGER)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.custom_minimum_size = Vector2(0, 38)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT


## 子菜单列表按钮
static func style_menu_button(btn: Button, font_size: int = 14) -> void:
	btn.add_theme_stylebox_override("normal",
		make_flat(BG_CARD, CORNER_SM, BORDER_BLUE, 1, 12, 8, 12, 8))
	btn.add_theme_stylebox_override("hover",
		make_flat(BTN_BG_HOVER, CORNER_SM, ACCENT_PRIMARY, 1, 12, 8, 12, 8))
	btn.add_theme_stylebox_override("pressed",
		make_flat(BTN_BG_PRESSED, CORNER_SM, ACCENT_PRIMARY, 1, 12, 8, 12, 8))
	btn.add_theme_stylebox_override("disabled",
		make_flat(BTN_BG_DISABLED, CORNER_SM, Color("#1A2030"), 1, 12, 8, 12, 8))
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", BTN_TEXT_DISABLED)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.custom_minimum_size = Vector2(0, 42)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT


## 标题页按钮（透明底 + 发光边框）
static func style_title_button(btn: Button, font_size: int = 18) -> void:
	var border_color := Color("#3B82F6", 0.6)
	var border_hover := Color("#60A5FA", 0.9)
	btn.add_theme_stylebox_override("normal",
		make_flat(Color(0.06, 0.09, 0.16, 0.4), CORNER_MD, border_color, 1, 24, 12, 24, 12))
	btn.add_theme_stylebox_override("hover",
		make_flat(Color(0.08, 0.12, 0.22, 0.6), CORNER_MD, border_hover, 2, 24, 12, 24, 12))
	btn.add_theme_stylebox_override("pressed",
		make_flat(Color(0.05, 0.07, 0.14, 0.5), CORNER_MD, ACCENT_PRIMARY, 2, 24, 12, 24, 12))
	btn.add_theme_color_override("font_color", Color("#93C5FD"))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color("#60A5FA"))
	btn.add_theme_font_size_override("font_size", font_size)
	btn.custom_minimum_size = Vector2(0, 50)


## 技能选择卡片按钮
static func style_skill_card(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal",
		make_flat(BG_CARD, CORNER_LG, BORDER_BLUE, 1, 12, 10, 12, 10))
	btn.add_theme_stylebox_override("hover",
		make_flat(Color("#1E2D42"), CORNER_LG, ACCENT_PRIMARY, 2, 12, 10, 12, 10))
	btn.add_theme_stylebox_override("pressed",
		make_flat(Color("#152030"), CORNER_LG, ACCENT_PRIMARY, 2, 12, 10, 12, 10))
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 1)
	btn.custom_minimum_size = Vector2(190, 100)


# ══════════════════════════════════════════
#  进度条组件
# ══════════════════════════════════════════

## 创建块状技能进度条 BBCode
static func make_skill_bar(level: int, max_level: int = 10) -> String:
	var filled := mini(level, max_level)
	var empty := max_level - filled
	return "[color=#3B82F6]%s[/color][color=#1E293B]%s[/color]" % [
		"▰".repeat(filled), "▱".repeat(empty)]


## 创建AP指示器 BBCode (色块圆点)
## AP指示器：free=可用(蓝), locked=工作锁定(橙), 剩余=已用(暗)
static func make_ap_indicator(free: int, locked: int, total: int) -> String:
	var result := ""
	for i in range(total):
		if i < free:
			result += "[color=#3B82F6]●[/color] "
		elif i < free + locked:
			result += "[color=#F97316]●[/color] "
		else:
			result += "[color=#1E293B]●[/color] "
	return result.strip_edges()


## 周进度条 BBCode
static func make_week_bar(current_week: int, max_weeks: int) -> String:
	var result := ""
	for i in range(1, max_weeks + 1):
		if i < current_week:
			result += "[color=#3B82F6]■[/color]"
		elif i == current_week:
			result += "[color=#60A5FA]■[/color]"
		else:
			result += "[color=#1E293B]■[/color]"
	return result


## 状态色点
static func status_dot(color: Color) -> String:
	return "[color=#%s]●[/color]" % color.to_html(false)
