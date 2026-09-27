extends Control
## Workshop — меню ремонта и тюнинга.
## Принимает индекс мотоцикла в гараже, выполняет действия, берёт деньги,
## накидывает дни, обновляет визуал и вызывает возврат в гараж.

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var repair_btn: Button = $Panel/VBox/Actions/RepairBtn
@onready var exhaust_btn: Button = $Panel/VBox/Actions/ExhaustBtn
@onready var suspension_btn: Button = $Panel/VBox/Actions/SuspensionBtn
@onready var paint_grid: GridContainer = $Panel/VBox/PaintGrid
@onready var close_btn: Button = $Panel/VBox/CloseBtn
@onready var message_label: Label = $Panel/VBox/MessageLabel

var bike: Motorcycle = null
var bike_index: int = -1


func _ready() -> void:
	visible = false
	repair_btn.pressed.connect(_on_repair)
	exhaust_btn.pressed.connect(_on_exhaust)
	suspension_btn.pressed.connect(_on_suspension)
	close_btn.pressed.connect(_on_close)
	# Создаём кнопки цветов покраски
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
		var hover := sb.duplicate()
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
	visible = true
	message_label.text = ""
	_refresh()


func _refresh() -> void:
	title_label.text = "Мастерская — %s" % bike.get_full_name()
	stats_label.text = _build_stats_text()
	repair_btn.text = _build_repair_text()
	exhaust_btn.text = "Тюнинг выхлопа (+15 л/с) — 20 000 ₽, 2 дня"
	exhaust_btn.disabled = bike.exhaust_tuned or GameManager.money < 20000
	suspension_btn.text = "Тюнинг подвески — 12 000 ₽, 1 день"
	suspension_btn.disabled = bike.suspension_tuned or GameManager.money < 12000


func _build_stats_text() -> String:
	var real_value: int = bike.calc_real_value()
	var tuned: Array[String] = []
	if bike.exhaust_tuned: tuned.append("выхлоп")
	if bike.suspension_tuned: tuned.append("подвеска")
	if bike.painted: tuned.append("покраска")
	var tuned_str: String = ", ".join(tuned) if tuned.size() > 0 else "нет"
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
		return
	if not GameManager.spend_money(result.cost):
		message_label.text = "[color=red]Недостаточно денег[/color]"
		return
	for i in result.days:
		GameManager.next_day()
	message_label.text = "[color=green]%s — потрачено %d ₽, прошло %d дн.[/color]" % [
		result.msg, result.cost, result.days
	]
	# Обновляем 3D-визуал мотоцикла
	var ui := get_tree().get_first_node_in_group("ui_manager")
	if ui: ui.refresh_garage_bike(bike_index)
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
	if ui: ui.show_garage()
