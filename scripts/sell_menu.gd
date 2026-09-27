extends Control
## SellMenu — меню продажи мотоцикла.

@onready var title_label: Label = $SellDialog/SellVBox/TitleLabel
@onready var stats_label: Label = $SellDialog/SellVBox/StatsLabel
@onready var offers_container: VBoxContainer = $SellDialog/SellVBox/Scroll/OffersContainer
@onready var new_offers_btn: Button = $SellDialog/SellVBox/NewOffersBtn
@onready var close_btn: Button = $SellDialog/SellVBox/CloseBtn
@onready var message_label: Label = $SellDialog/SellVBox/MessageLabel

var bike: Motorcycle = null
var bike_index: int = -1
var offers: Array = []

const BUYER_NAMES: Array = [
	"Алексей (начинающий)", "Дмитрий (механик)", "Илья (коллекционер)",
	"Мария (курьер)", "Артём (байкер)", "Сергей (из салона)",
	"Владимир (на запчасти)", "Ольга (первый байк)"
]


func _ready() -> void:
	visible = false
	new_offers_btn.pressed.connect(_on_new_offers)
	close_btn.pressed.connect(_on_close)


func show_for(bike_idx: int) -> void:
	bike_index = bike_idx
	bike = GameManager.get_garage_bike(bike_idx)
	if bike == null:
		visible = false
		return
	if not is_instance_valid(title_label) or not is_instance_valid(offers_container):
		call_deferred("show_for", bike_idx)
		return
	visible = true
	message_label.text = ""
	title_label.text = "Продажа: %s" % bike.get_full_name()
	stats_label.text = "Состояние: %d%%   •   Мощность: %d л/с   •   Реальная стоимость ~%d ₽" % [
		int(bike.condition), bike.engine_hp, bike.calc_real_value()
	]
	_generate_offers()


func _generate_offers() -> void:
	for c in offers_container.get_children():
		c.queue_free()
	offers.clear()
	message_label.text = ""
	var real: int = bike.calc_real_value()
	var count: int = randi_range(1, 3)
	if GameManager.reputation > 0.6:
		count = max(count, 2)
	for i in count:
		var buyer_name: String = BUYER_NAMES[randi() % BUYER_NAMES.size()]
		var offer_price: int = int(real * randf_range(0.75, 1.2 + 0.1 * GameManager.reputation))
		offers.append({"buyer_name": buyer_name, "price": offer_price})
		offers_container.add_child(_make_offer_row(i))


func _make_offer_row(idx: int) -> HBoxContainer:
	var data: Dictionary = offers[idx]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = "%s предлагает [b]%d ₽[/b]" % [data["buyer_name"], data["price"]]
	lbl.bbcode_enabled = true
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var accept_btn := Button.new()
	accept_btn.text = "Принять"
	accept_btn.pressed.connect(_on_accept.bind(idx))
	row.add_child(accept_btn)

	var haggle_btn := Button.new()
	haggle_btn.text = "Торговаться"
	haggle_btn.pressed.connect(_on_haggle.bind(idx))
	row.add_child(haggle_btn)

	var reject_btn := Button.new()
	reject_btn.text = "Отклонить"
	reject_btn.pressed.connect(_on_reject.bind(idx))
	row.add_child(reject_btn)

	return row


func _on_accept(idx: int) -> void:
	if idx < 0 or idx >= offers.size():
		return
	var price: int = offers[idx]["price"]
	GameManager.add_money(price)
	var delta_rep: float = 0.02
	if price > int(bike.calc_real_value() * 1.1):
		delta_rep += 0.01
	GameManager.add_reputation(delta_rep)
	GameManager.remove_from_garage(bike)
	message_label.text = "[color=green]Сделка состоялась! Получено %d ₽[/color]" % price
	message_label.bbcode_enabled = true
	await get_tree().create_timer(1.0).timeout
	_on_close()


func _on_haggle(idx: int) -> void:
	if idx < 0 or idx >= offers.size():
		return
	var old_price: int = offers[idx]["price"]
	var chance: float = 0.5 + 0.2 * GameManager.reputation
	if randf() < chance:
		var increase: float = randf_range(0.1, 0.2)
		var new_price: int = int(float(old_price) * (1.0 + increase))
		offers[idx]["price"] = new_price
		message_label.text = "[color=green]Покупатель согласился поднять цену до %d ₽![/color]" % new_price
	else:
		if randf() < 0.5:
			offers.remove_at(idx)
			message_label.text = "[color=red]Покупатель отказался торговаться и ушёл.[/color]"
		else:
			var new_price: int = int(float(old_price) * 0.9)
			offers[idx]["price"] = new_price
			message_label.text = "[color=yellow]Покупатель настаивает на цене %d ₽ (сбил на 10%%).[/color]" % new_price
	message_label.bbcode_enabled = true
	for c in offers_container.get_children():
		c.queue_free()
	for i in offers.size():
		offers_container.add_child(_make_offer_row(i))
	if offers.is_empty():
		message_label.text += "\nВсе покупатели разошлись. Нажмите «Новые покупатели»."


func _on_reject(idx: int) -> void:
	if idx < 0 or idx >= offers.size():
		return
	offers.remove_at(idx)
	for c in offers_container.get_children():
		c.queue_free()
	for i in offers.size():
		offers_container.add_child(_make_offer_row(i))
	message_label.text = "[color=yellow]Предложение отклонено.[/color]"
	message_label.bbcode_enabled = true


func _on_new_offers() -> void:
	GameManager.next_day()
	_generate_offers()


func _on_close() -> void:
	visible = false
	var ui := get_tree().get_first_node_in_group("ui_manager")
	if ui:
		ui.call("show_garage")
