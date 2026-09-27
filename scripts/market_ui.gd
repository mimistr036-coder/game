extends Control
## MarketUI — панель рынка со списком карточек предложений.

@onready var list: VBoxContainer = $Panel/VBox/Scroll/List
@onready var refresh_btn: Button = $Panel/VBox/RefreshBtn


func _ready() -> void:
	refresh_btn.pressed.connect(_on_refresh)


func _on_refresh() -> void:
	GameManager.refresh_market()


func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	for i in GameManager.market_offers.size():
		var bike: Motorcycle = GameManager.market_offers[i]
		list.add_child(_make_card(bike, i))
	if GameManager.market_offers.is_empty():
		var l := Label.new()
		l.text = "На рынке сегодня пусто. Нажмите «Новый день»."
		l.add_theme_font_size_override("font_size", 20)
		list.add_child(l)


func _make_card(bike: Motorcycle, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "[b]%s[/b]" % bike.get_full_name()
	title.add_theme_font_size_override("font_size", 18)
	title.bbcode_enabled = true
	vbox.add_child(title)

	var info := Label.new()
	var real: int = bike.calc_real_value()
	var diff: int = bike.price_sell - real
	var deal_hint: String
	if diff < -1000:
		deal_hint = "[color=#5cff7a]▼ Выгодно! Ниже реальной цены[/color]"
	elif diff > 5000:
		deal_hint = "[color=#ff7a5c]▲ Завышено![/color]"
	else:
		deal_hint = "[color=white]≈ Справедливая цена[/color]"
	info.text = "Пробег: %d км   •   Состояние: %d%%   •   Мощность: %d л/с   •   Редкость: %d%%\nЗапрашивает продавец: [b]%d ₽[/b]   •   Реальная цена: ~%d ₽\n%s" % [
			bike.mileage, int(bike.condition), bike.engine_hp, int(bike.rarity * 100),
			bike.price_sell, real, deal_hint
		]
	info.bbcode_enabled = true
	# 3 = AUTOWRAP_WORD_SMART (совместимо с Godot 4.0)
	info.autowrap_mode = 3
	vbox.add_child(info)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	var buy_btn := Button.new()
	buy_btn.text = "Купить (%d ₽)" % bike.price_sell
	buy_btn.disabled = GameManager.money < bike.price_sell or GameManager.garage.size() >= GameManager.garage_slots
	buy_btn.pressed.connect(_on_buy.bind(index))
	hbox.add_child(buy_btn)

	var color_box := ColorRect.new()
	color_box.color = bike.get_condition_color()
	color_box.custom_minimum_size = Vector2(40, 28)
	hbox.add_child(color_box)

	return card


func _on_buy(index: int) -> void:
	if GameManager.buy_from_market(index):
		GameManager.add_reputation(0.01)
		refresh()
