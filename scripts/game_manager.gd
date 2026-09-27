extends Node
## GameManager — глобальный синглтон (автозагрузка).
## Хранит деньги, день, репутацию, список мотоциклов в гараже и список
## текущих предложений на рынке. Оповещает UI через сигналы.

signal money_changed(new_amount: int)
signal day_changed(new_day: int)
signal reputation_changed(new_rep: float)
signal garage_changed()
signal market_changed()

const STARTING_MONEY: int = 50000            # Стартовый капитал, ₽
const STARTING_REPUTATION: float = 0.5       # Репутация от 0 до 1
const STARTING_GARAGE_SLOTS: int = 5         # Базовое число слотов в гараже
const SLOT_UPGRADE_COST: int = 30000         # Стоимость расширения гаража на +1 слот
const DAY_DURATION_SEC: float = 30.0         # Длительность игрового дня в секундах (для автопереключения)

var money: int = STARTING_MONEY
var day: int = 1
var reputation: float = STARTING_REPUTATION
var garage_slots: int = STARTING_GARAGE_SLOTS

# Мотоциклы в гараже (объекты Motorcycle)
var garage: Array = []
# Текущие предложения на рынке (объекты Motorcycle)
var market_offers: Array = []

var _day_timer: float = 0.0
var _auto_advance: bool = false  # Авто-перемотка дней по таймеру (по желанию можно включить)


func _ready() -> void:
	randomize()
	MarketGenerator.generate_offers(self, 5)


func _process(delta: float) -> void:
	if not _auto_advance:
		return
	_day_timer += delta
	if _day_timer >= DAY_DURATION_SEC:
		_day_timer = 0.0
		next_day()


## --- Деньги -----------------------------------------------------------------

func add_money(amount: int) -> void:
	money += amount
	emit_signal("money_changed", money)


func spend_money(amount: int) -> bool:
	"""Возвращает true если удалось потратить деньги."""
	if money < amount:
		return false
	money -= amount
	emit_signal("money_changed", money)
	return true


## --- Дни --------------------------------------------------------------------

func next_day() -> void:
	day += 1
	# Обновляем предложения на рынке
	MarketGenerator.generate_offers(self, randi_range(3, 7))
	emit_signal("day_changed", day)
	emit_signal("market_changed")


## --- Репутация --------------------------------------------------------------

func add_reputation(delta_rep: float) -> void:
	reputation = clamp(reputation + delta_rep, 0.0, 1.0)
	emit_signal("reputation_changed", reputation)


## --- Гараж ------------------------------------------------------------------

func add_to_garage(bike: Motorcycle) -> bool:
	if garage.size() >= garage_slots:
		return false
	garage.append(bike)
	emit_signal("garage_changed")
	return true


func remove_from_garage(bike: Motorcycle) -> void:
	if bike in garage:
		garage.erase(bike)
		emit_signal("garage_changed")


func get_garage_bike(index: int) -> Motorcycle:
	if index < 0 or index >= garage.size():
		return null
	return garage[index]


func buy_upgrade_slot() -> bool:
	"""Расширить гараж на 1 слот."""
	if spend_money(SLOT_UPGRADE_COST):
		garage_slots += 1
		emit_signal("garage_changed")
		return true
	return false


## --- Рынок ------------------------------------------------------------------

func buy_from_market(offer_index: int) -> bool:
	"""Купить мотоцикл с рынка по индексу предложения."""
	if offer_index < 0 or offer_index >= market_offers.size():
		return false
	var bike: Motorcycle = market_offers[offer_index]
	if money < bike.price_sell:
		return false
	if garage.size() >= garage_slots:
		return false
	spend_money(bike.price_sell)
	market_offers.remove_at(offer_index)
	add_to_garage(bike)
	emit_signal("market_changed")
	return true


func refresh_market() -> void:
	"""Обновить предложения на рынке (кнопка «Новый день»)."""
	next_day()
