extends Control
## SellMenu — меню продажи мотоцикла: генерирует 1–3 покупателей с разными
## предложениями, позволяет поторговаться и принять/отклонить сделку.

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var offers_container: VBoxContainer = $Panel/VBox/OffersContainer
@onready var new_offers_btn: Button = $Panel/VBox/NewOffersBtn
@onready var close_btn: Button = $Panel/VBox/CloseBtn
@onready var message_label: Label = $Panel/VBox/MessageLabel

var bike: Motorcycle = null
var bike_index: int = -1
var offers: Array = []  # массив {name, price, accepted}


const BUYER_NAMES: Array[String] = [
	"Алексей (начинающий)", "Дмитрий (механик)", "Илья (коллекционер)",
	"Мария (курьер)", "Артём (байкер)", "Сергей (из салона)",
	"Владимир (запчасти)", "Ольга (первый байк)"
]


func _ready() -> void:
	visible = false
	new_offers_btn.pressed.connect(_on_new_offers)
	close_btn.pressed.connect(_on_close)


func _on_new_offers() -> void:
	GameManager.next_day()
	_generate_offers()


func show_for(bike_idx: int) -> void:
	bike_index = bike_idx
	bike = GameManager.get_garage_bike(bike_idx)
	if bike == null:
		visible = false
		return
	visible = true
	message_label.text = ""
	title_label.text = "Продажа: %s" % bike.get_full_name()
	stats_label.text = "Состояние: %d%%   •   Мощность: %d л/с   •   Реальная стоимость ~%d ₽" % [
		int(bike.condition), bike.engine_hp, bike.calc_real_value()
	]
	_generate_offers()


func _generate_offers() -> void:
	# Очистить старые
	for c in offers_container.get_children():
		c.queue_free()
	offers.clear()
	message_label.text = ""
	var real: int = bike.calc_real_value()
	var count: int = randi_range(1, 3)
	# Репутация влияет: выше репутация — больше покупателей и выше цены
	if GameManager.reputation > 0.6:
		count = max(count, 2)
	for i in count:
		var name: String = BUYER_NAMES[randi() % BUYER_NAMES.size()]
		# Разброс предложения: от -25% до +20% от реальной цены
		var offer_price: int = int(real * randf_range(0.75, 1.2 + 0.1 * GameManager.reputation))
		offers.append({ "name": name, "price": offer_price })
		offers_container.add_child(_make_offer_row(i))


func _make_offer_row(idx: int) -> HBoxContainer:
	var data: Dictionary = offers[idx]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = "%s предлагает [b]%d ₽[/b]" % [data.name, data.price]
	lbl.bbcode_enabled = true
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var accept_btn := Button.new()
	accept_btn.text = "Принять"
	accept_btn.pressed.connect(func(): _accept(idx))
	row.add_child(accept_btn)

	var haggle_btn := Button.new()
	haggle_btn.text = "Торговаться"
	haggle_btn.pressed.connect(func(): _haggle(idx, haggle_btn))
	row.add_child(haggle_btn)

	var reject_btn := Button.new()
	reject_btn.text = "Отклонить"
	reject_btn.pressed.connect(func(): _reject(idx))
	row.add_child(reject_btn)

	return row


func _accept(idx: int) -> void:
	var price: int = offers[idx]["price"]
	GameManager.add_money(price)
	var delta_rep: float = 0.02
	if price > bike.calc_real_value() * 1.1:
		delta_rep += 0.01   # выгодная сделка даёт доп. репутацию
	GameManager.add_reputation(delta_rep)
	GameManager.remove_from_garage(bike)
	message_label.text = "[color=green]Сделка состоялась! Получено %d ₽[/color]" % price
	message_label.bbcode_enabled = true
	# Закрываем через секунду
	await get_tree().create_timer(1.2).timeout
	_on_close()


func _haggle(idx: int, btn: Button) -> void:
	var data: Dictionary = offers[idx]
	var old_price: int = data.price
	var chance: float = 0.5 + 0.2 * GameManager.reputation  # шанс выше с репутацией
	if randf() < chance:
		var increase: float = randf_range(0.1, 0.2)  # +10..20%
		var new_price: int = int(old_price * (1.0 + increase))
		offers[idx]["price"] = new_price
		message_label.text = "[color=green]Покупатель согласился поднять цену до %d ₽![/color]" % new_price
	else:
		# Покупатель уходит или сбивает цену
		if randf() < 0.5:
			offers.remove_at(idx)
			message_label.text = "[color=red]Покупатель отказался торговаться и ушёл.[/color]"
		else:
			var new_price: int = int(old_price * 0.9)
			offers[idx]["price"] = new_price
			message_label.text = "[color=yellow]Покупатель настаивает на цене %d ₽ (сбил на 10%%).[/color]" % new_price
	message_label.bbcode_enabled = true
	# Перерисовываем предложения
	for c in offers_container.get_children():
		c.queue_free()
	for i in offers.size():
		offers_container.add_child(_make_offer_row(i))
	if offers.is_empty():
		message_label.text += "\nВсе покупатели разошлись. Нажмите «Новые покупатели»."


func _reject(idx: int) -> void:
	offers.remove_at(idx)
	for c in offers_container.get_children():
		c.queue_free()
	for i in offers.size():
		offers_container.add_child(_make_offer_row(i))
	message_label.text = "[color=yellow]Предложение отклонено.[/color]"
	message_label.bbcode_enabled = true


func _on_close() -> void:
	visible = false
	var ui := get_tree().get_first_node_in_group("ui_manager")
	if ui: ui.show_garage()
