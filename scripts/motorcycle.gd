extends Resource
class_name Motorcycle
## Motorcycle — ресурс/класс данных одного мотоцикла.
## Хранит все параметры, умеет считать реальную стоимость, отдавать цвет
## в зависимости от состояния и применять к себе ремонт/тюнинг.

# Бренды
const BRANDS: Array[String] = [
	"Honda", "Yamaha", "Kawasaki", "Suzuki",
	"Ducati", "BMW", "KTM", "Harley-Davidson"
]

# Модели по брендам (для процедурной генерации)
const MODELS_BY_BRAND: Dictionary = {
	"Honda": ["CBR600RR", "CB1000R", "Africa Twin", "Shadow", "Gold Wing"],
	"Yamaha": ["YZF-R6", "MT-09", "Tenere 700", "VMAX", "FZ6"],
	"Kawasaki": ["Ninja ZX-6R", "Z900", "Versys", "Vulcan S", "Ninja H2"],
	"Suzuki": ["GSX-R750", "SV650", "V-Strom", "Hayabusa", "Bandit"],
	"Ducati": ["Panigale V4", "Monster", "Multistrada", "Scrambler", "Diavel"],
	"BMW": ["S1000RR", "R1250GS", "F900R", "K1600", "G310R"],
	"KTM": ["Duke 390", "RC 390", "1290 Super Duke", "Adventure 790", "EXC-F"],
	"Harley-Davidson": ["Sportster", "Fat Boy", "Street Glide", "Softail", "Iron 883"]
}

# Цвета покраски (доступные в мастерской)
const PAINT_COLORS: Array[Color] = [
	Color(0.85, 0.1, 0.1),   # красный
	Color(0.1, 0.1, 0.1),    # чёрный
	Color(0.95, 0.95, 0.95), # белый
	Color(0.0, 0.2, 0.75),   # синий
	Color(0.1, 0.7, 0.2),    # зелёный
	Color(0.95, 0.75, 0.05), # жёлтый
	Color(0.6, 0.15, 0.6),   # фиолетовый
	Color(0.9, 0.5, 0.0),    # оранжевый
]

@export var brand: String = "Honda"
@export var model: String = "CBR600RR"
@export var year: int = 2010
@export var mileage: int = 0           # пробег, км
@export var condition: float = 100.0   # состояние 0..100
@export var engine_hp: int = 100       # л/с
@export var price_buy: int = 0         # цена покупки (реальная), рассчитывается при генерации
@export var price_sell: int = 0        # запрашиваемая цена продавца
@export var rarity: float = 0.5        # редкость 0..1, влияет на цену
@export var base_value: int = 0        # базовая стоимость идеального состояния
@export var body_color: Color = Color(0.85, 0.1, 0.1)

# Флаги тюнинга, чтобы не делать его дважды
@export var exhaust_tuned: bool = false
@export var suspension_tuned: bool = false
@export var painted: bool = false


func _init() -> void:
	pass


# --- Вспомогательная информация --------------------------------------------

func get_full_name() -> String:
	return "%s %s (%d)" % [brand, model, year]


func get_condition_color() -> Color:
	"""Цвет материала в зависимости от состояния:
	100..80 — блестящий родной цвет, 80..50 — блеклый, 50..0 — ржавый."""
	var c: Color = body_color
	if condition >= 80.0:
		return c                               # почти новый
	elif condition >= 50.0:
		var k: float = (condition - 50.0) / 30.0
		return c.lerp(Color(0.35, 0.3, 0.25), 1.0 - k)  # блекнет к грязно-коричневому
	else:
		var k: float = condition / 50.0
		return Color(0.35, 0.3, 0.25).lerp(Color(0.45, 0.25, 0.1), 1.0 - k)  # ржавый


func get_roughness() -> float:
	"""Шероховатость материала — чем хуже состояние, тем матовее/грязнее."""
	return clamp(1.0 - condition / 100.0, 0.1, 0.95)


func calc_real_value() -> int:
	"""Реальная стоимость мотоцикла с учётом состояния, тюнинга, пробега."""
	var value: float = float(base_value)
	# Состояние
	value *= 0.4 + 0.6 * (condition / 100.0)
	# Пробег — каждые 10 000 км снижают цену на 2%
	value *= max(0.3, 1.0 - (mileage / 10000.0) * 0.02)
	# Тюнинг даёт прибавку
	if exhaust_tuned:
		value += 15000
	if suspension_tuned:
		value += 10000
	if painted:
		value += 3000
	# Редкость
	value *= 0.7 + 0.6 * rarity  # 0.7..1.3
	return int(value)


# --- Действия в мастерской --------------------------------------------------

func repair_engine() -> Dictionary:
	"""Ремонт двигателя. Возвращает словарь {cost, days, success}."""
	if condition >= 100.0:
		return { "cost": 0, "days": 0, "success": false, "msg": "Мотоцикл уже в идеальном состоянии" }
	var needed: float = 100.0 - condition
	var cost: int = int(needed * 200.0)          # 200 ₽ за единицу состояния
	var days: int = max(1, int(needed / 25.0))   # 1 день за 25 ед.
	condition = 100.0
	mileage = max(0, mileage - 5000)             # после ремонта как будто поменьше пробег
	return { "cost": cost, "days": days, "success": true, "msg": "Двигатель отремонтирован" }


func paint(new_color: Color) -> Dictionary:
	"""Покраска."""
	if painted and body_color == new_color:
		return { "cost": 0, "days": 0, "success": false, "msg": "Такой цвет уже стоит" }
	var cost: int = 5000
	var days: int = 1
	body_color = new_color
	painted = true
	condition = min(100.0, condition + 2.0)      # небольшой бонус
	return { "cost": cost, "days": days, "success": true, "msg": "Мотоцикл перекрашен" }


func tune_exhaust() -> Dictionary:
	"""Тюнинг выхлопа: +15 л/с."""
	if exhaust_tuned:
		return { "cost": 0, "days": 0, "success": false, "msg": "Выхлоп уже тюнингован" }
	var cost: int = 20000
	var days: int = 2
	engine_hp += 15
	exhaust_tuned = true
	return { "cost": cost, "days": days, "success": true, "msg": "Выхлоп тюнингован (+15 л/с)" }


func tune_suspension() -> Dictionary:
	"""Тюнинг подвески — не даёт л/с, но увеличивает цену."""
	if suspension_tuned:
		return { "cost": 0, "days": 0, "success": false, "msg": "Подвеска уже тюнингована" }
	var cost: int = 12000
	var days: int = 1
	suspension_tuned = true
	condition = min(100.0, condition + 3.0)
	return { "cost": cost, "days": days, "success": true, "msg": "Подвеска улучшена" }


# --- Сериализация в словарь (для удобства UI) -------------------------------

func to_dict() -> Dictionary:
	return {
		"brand": brand,
		"model": model,
		"year": year,
		"mileage": mileage,
		"condition": condition,
		"engine_hp": engine_hp,
		"price_sell": price_sell,
		"rarity": rarity,
		"real_value": calc_real_value(),
		"exhaust_tuned": exhaust_tuned,
		"suspension_tuned": suspension_tuned,
		"painted": painted,
	}
