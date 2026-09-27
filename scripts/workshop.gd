extends Control
## Workshop — меню ремонта и тюнинга мотоцикла.

@onready var title_label: Label = $WorkshopDialog/WorkshopVBox/TitleLabel
@onready var stats_label: Label = $WorkshopDialog/WorkshopVBox/StatsLabel
@onready var repair_btn: Button = $WorkshopDialog/WorkshopVBox/Actions/RepairBtn
@onready var exhaust_btn: Button = $WorkshopDialog/WorkshopVBox/Actions/ExhaustBtn
@onready var suspension_btn: Button = $WorkshopDialog/WorkshopVBox/Actions/SuspensionBtn
@onready var paint_grid: GridContainer = $WorkshopDialog/WorkshopVBox/PaintGrid
@onready var close_btn: Button = $WorkshopDialog/WorkshopVBox/CloseBtn
@onready var message_label: Label = $WorkshopDialog/WorkshopVBox/MessageLabel

var bike: Motorcycle = null
var bike_index: int = -1


func _ready() -> void:
	visible = false
	repair_btn.pressed.connect(_on_repair)
	exhaust_btn.pressed.connect(_on_exhaust)
	suspension_btn.pressed.connect(_on_suspension)
	close_btn.pressed.connect(_on_close)
	for c in Motorcycle.PAINT_COLORS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(40, 40)
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.1, 0.1, 0.1)
		btn.add_theme_stylebox_override("normal", sb)
		var hover: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
		hover.border_color = Color(1, 1, 1)
		btn.add_theme_stylebox_override("hover", hover)
		paint_grid.add_child(btn)
		btn.pressed.connect(_on_paint.bind(c))


func show_for(bike_idx: int) -> void:
	bike_index = bike_idx
	bike = GameManager.get_garage_bike(bike_idx)
	if bike == null:
		visible = false
		return
	if not is_instance_valid(title_label) or not is_instance_valid(stats_label) or not is_instance_valid(repair_btn):
		# Узлы ещё не готовы — откладываем на следующий кадр
		call_deferred("show_for", bike_idx)
		return
	visible = true
	message_label.text = ""
	_refresh()


func _refresh() -> void:
	title_label.text = "Мастерская — %s" % bike.get_full_name()
	stats_label.text = _build_stats_text()
	repair_btn.text = _build_repair_text()
	repair_btn.disabled = bike.condition >= 100.0 or GameManager.money < int((100.0 - bike.condition) * 200.0)
	exhaust_btn.text = "Тюнинг выхлопа (+15 л/с) — 20 000 ₽, 2 дня"
	exhaust_btn.disabled = bike.exhaust_tuned or GameManager.money < 20000
	suspension_btn.text = "Тюнинг подвески — 12 000 ₽, 1 день"
	suspension_btn.disabled = bike.suspension_tuned or GameManager.money < 12000


func _build_stats_text() -> String:
	var real_value: int = bike.calc_real_value()
	var tuned: Array = []
	if bike.exhaust_tuned:
		tuned.append("выхлоп")
	if bike.suspension_tuned:
		tuned.append("подвеска")
	if bike.painted:
		tuned.append("покраска")
	var tuned_str: String = ", ".join(tuned) if tuned.is_empty() == false else "нет"
	return "Состояние: %d%%   •   Пробег: %d км   •   Мощность: %d л/с\nРеальная стоимость: %d ₽   •   Тюнинг: %s" % [
		int(bike.condition), bike.mileage, bike.engine_hp, real_value, tuned_str
	]


func _build_repair_text() -> String:
	if bike.condition >= 100.0:
		return "Двигатель в идеале"
	var needed: float = 100.0 - bike.condition
	var cost: int = int(needed * 200.0)
	var days: int = max(1, int(needed / 25.0))
	return "Ремонт двигателя (до 100%%) — %d ₽, %d дн." % [cost, days]


func _apply_result(result: Dictionary) -> void:
	if not result.success:
		message_label.text = "[color=yellow]%s[/color]" % result.msg
		message_label.bbcode_enabled = true
		return
	if not GameManager.spend_money(result.cost):
		message_label.text = "[color=red]Недостаточно денег[/color]"
		message_label.bbcode_enabled = true
		return
	var d_count: int = result.days
	for i in d_count:
		GameManager.next_day()
	message_label.text = "[color=green]%s — потрачено %d ₽, прошло %d дн.[/color]" % [
		result.msg, result.cost, result.days
	]
	message_label.bbcode_enabled = true
	var ui := get_tree().get_first_node_in_group("ui_manager")
	if ui:
		ui.call("refresh_garage_bike", bike_index)
	_refresh()


func _on_repair() -> void:
	_apply_result(bike.repair_engine())


func _on_exhaust() -> void:
	_apply_result(bike.tune_exhaust())


func _on_suspension() -> void:
	_apply_result(bike.tune_suspension())


func _on_paint(color: Color) -> void:
	_apply_result(bike.paint(color))


func _on_close() -> void:
	visible = false
	var ui := get_tree().get_first_node_in_group("ui_manager")
	if ui:
		ui.call("show_garage")
