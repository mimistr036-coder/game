extends Control
## Main — корневой узел главной сцены. Управляет переключением экранов
## (Рынок / Гараж / Мастерская / Продажа), обновляет верхнюю и нижнюю панели.
## Регистрирует себя в группе "ui_manager", чтобы другие скрипты могли вызывать
## его методы через get_tree().get_first_node_in_group("ui_manager").

@onready var money_label: Label = $TopBar/MoneyLabel
@onready var day_label: Label = $TopBar/DayLabel
@onready var rep_label: Label = $TopBar/RepLabel

@onready var market_btn: Button = $BottomBar/MarketBtn
@onready var garage_btn: Button = $BottomBar/GarageBtn
@onready var expand_garage_btn: Button = $BottomBar/ExpandBtn
@onready var next_day_btn: Button = $BottomBar/NextDayBtn

@onready var market_panel: Control = $MarketPanel
@onready var market_script: Node = $MarketPanel
@onready var garage_viewport: SubViewportContainer = $GarageViewportContainer
@onready var garage_script: Node = $GarageViewportContainer/SubViewport/Garage
@onready var workshop_panel: Control = $WorkshopPanel
@onready var workshop_script: Node = $WorkshopPanel
@onready var sell_panel: Control = $SellPanel
@onready var sell_script: Node = $SellPanel


func _ready() -> void:
	add_to_group("ui_manager")
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.day_changed.connect(_on_day_changed)
	GameManager.reputation_changed.connect(_on_rep_changed)
	market_btn.pressed.connect(show_market)
	garage_btn.pressed.connect(show_garage)
	expand_garage_btn.pressed.connect(_on_expand)
	next_day_btn.pressed.connect(func(): GameManager.next_day())
	$MarketPanel/Panel/VBox/CloseBtn.pressed.connect(show_garage)
	if market_script.has_method("refresh"):
		GameManager.market_changed.connect(market_script.refresh)
		GameManager.money_changed.connect(market_script.refresh)
	_on_money_changed(GameManager.money)
	_on_day_changed(GameManager.day)
	_on_rep_changed(GameManager.reputation)
	# После загрузки всего — показываем гараж
	await get_tree().process_frame
	show_garage()


func _on_money_changed(v: int) -> void:
	money_label.text = "Баланс: %d ₽" % v


func _on_day_changed(v: int) -> void:
	day_label.text = "День: %d" % v


func _on_rep_changed(v: float) -> void:
	rep_label.text = "Репутация: %d%%" % int(v * 100.0)


func _hide_all() -> void:
	market_panel.visible = false
	garage_viewport.visible = false
	workshop_panel.visible = false
	sell_panel.visible = false


func show_market() -> void:
	_hide_all()
	market_panel.visible = true
	# 3D гараж продолжает рендериться в фоне для красоты
	garage_viewport.visible = true
	market_panel.move_to_front()
	if market_script.has_method("refresh"):
		market_script.refresh()


func show_garage() -> void:
	_hide_all()
	garage_viewport.visible = true


func show_workshop(bike_index: int) -> void:
	_hide_all()
	garage_viewport.visible = true
	workshop_panel.visible = true
	workshop_panel.move_to_front()
	workshop_script.show_for(bike_index)


func show_sell_menu(bike_index: int) -> void:
	_hide_all()
	garage_viewport.visible = true
	sell_panel.visible = true
	sell_panel.move_to_front()
	sell_script.show_for(bike_index)


func refresh_garage_bike(_index: int) -> void:
	if garage_script and garage_script.has_method("_refresh_bikes"):
		garage_script._refresh_bikes()


func _on_expand() -> void:
	if garage_script and garage_script.has_method("try_expand_garage"):
		if not garage_script.try_expand_garage():
			var dlg := AcceptDialog.new()
			dlg.dialog_text = "Недостаточно денег для расширения гаража (%d ₽)." % GameManager.SLOT_UPGRADE_COST
			add_child(dlg)
			dlg.popup_centered()
			dlg.confirmed.connect(dlg.queue_free)


## Статический хелпер для других скриптов: получить UI-менеджер

static func get() -> Node:
	return Engine.get_main_loop().root.get_tree().get_first_node_in_group("ui_manager")
