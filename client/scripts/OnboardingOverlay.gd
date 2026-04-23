extends Control

signal onboarding_completed

const SLIDES = [
	{
		"title": "성좌 배틀로얄에 오신 것을 환영합니다!",
		"body": "AI 캐릭터들이 콜로세움에서 싸우는 배틀로얄입니다.\n당신은 신(神)으로서 신탁으로 결과에 개입합니다.",
		"icon": "⚔️"
	},
	{
		"title": "신탁(Oracle)이란?",
		"body": "채팅창에 명령을 입력하면 Gemini AI가 해석해\n당신의 캐릭터 행동에 영향을 줍니다.\n예: \"적진을 피해 도망쳐라\" / \"가장 약한 적을 공격해\"",
		"icon": "🔮"
	},
	{
		"title": "포인트와 랭킹",
		"body": "신탁을 보낼 때마다 성좌 포인트가 소모됩니다.\n캐릭터가 살아남을수록 포인트를 획득합니다.\n전략적으로 신탁을 사용해 리더보드 1위를 노리세요!",
		"icon": "🏆"
	}
]

var _current_slide: int = 0
var _slide_title: Label
var _slide_body: Label
var _slide_icon: Label
var _next_btn: Button
var _skip_btn: Button
var _dots: HBoxContainer

func _ready() -> void:
	_build_ui()
	_show_slide(0)

func _build_ui() -> void:
	# 반투명 배경
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 카드 컨테이너
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(420, 300)
	add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	_slide_icon = Label.new()
	_slide_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slide_icon.add_theme_font_size_override("font_size", 48)
	vbox.add_child(_slide_icon)

	_slide_title = Label.new()
	_slide_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slide_title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_slide_title)

	_slide_body = Label.new()
	_slide_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slide_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slide_body.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_slide_body)

	# 페이지 도트
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_dots)

	# 버튼
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_skip_btn = Button.new()
	_skip_btn.text = "건너뛰기"
	_skip_btn.pressed.connect(_on_finish)
	btn_row.add_child(_skip_btn)

	_next_btn = Button.new()
	_next_btn.text = "다음 >"
	_next_btn.pressed.connect(_on_next)
	btn_row.add_child(_next_btn)

	# 도트 초기화
	for i in SLIDES.size():
		var dot := Label.new()
		dot.text = "●"
		_dots.add_child(dot)

func _show_slide(idx: int) -> void:
	_current_slide = idx
	var s := SLIDES[idx]
	_slide_icon.text = s["icon"]
	_slide_title.text = s["title"]
	_slide_body.text = s["body"]
	_next_btn.text = "시작하기!" if idx == SLIDES.size() - 1 else "다음 >"

	for i in _dots.get_child_count():
		_dots.get_child(i).modulate.a = 1.0 if i == idx else 0.35

func _on_next() -> void:
	if _current_slide < SLIDES.size() - 1:
		_show_slide(_current_slide + 1)
	else:
		_on_finish()

func _on_finish() -> void:
	emit_signal("onboarding_completed")
	queue_free()
