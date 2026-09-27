extends Node
## GameManager — глобальный синглтон (автозагрузка).
## Деньги, день, репутация, список мотоциклов в гараже и текущие
## предложения рынка. Оповещает UI сигналами.

signal money_changed(new_amount: int)
signal day_changed(new_day: int)
signal reputation_changed(new_rep: float)
signal garage_changed()
signal market_changed()

const STARTING_MONEY: int = 50000
const STARTING_REPUTATION: float = 0.5
const STARTING_GARAGE_SLOTS: int = 5
const SLOT_UPGRADE_COST: int = 30000
const DAY_DURATION_SEC: float = 30.0

var money: int = STARTING_MONEY
var day: int = 1
var reputation: float = STARTING_REPUTATION
var garage_slots: int = STARTING_GARAGE_SLOTS

var garage: Array = []           # объекты Motorcycle
var market_offers: Array = []    # объекты Motorcycle

var _day_timer: float = 0.0
var _auto_advance: bool = false


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


# --- Деньги -----------------------------------------------------------------

func add_money(amount: int) -> void:
	money += amount
	emit_signal("money_changed", money)


func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	emit_signal("money_changed", money)
	return true


# --- Дни --------------------------------------------------------------------

func next_day() -> void:
	day += 1
	var count: int = randi_range(3, 7)
	MarketGenerator.generate_offers(self, count)
	emit_signal("day_changed", day)
	emit_signal("market_changed")


# --- Репутация --------------------------------------------------------------

func add_reputation(delta_rep: float) -> void:
	reputation = clamp(reputation + delta_rep, 0.0, 1.0)
	emit_signal("reputation_changed", reputation)


# --- Гараж ------------------------------------------------------------------

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
	if spend_money(SLOT_UPGRADE_COST):
		garage_slots += 1
		emit_signal("garage_changed")
		return true
	return false


# --- Рынок ------------------------------------------------------------------

func buy_from_market(offer_index: int) -> bool:
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
	next_day()
