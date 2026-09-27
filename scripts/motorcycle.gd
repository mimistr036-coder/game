extends Resource
class_name Motorcycle
## Motorcycle — Resource с данными одного мотоцикла.
## Хранит все параметры, умеет считать реальную стоимость, возвращать цвет
## по состоянию и применять ремонт/тюнинг/покраску.

const BRANDS: Array = [
	"Honda", "Yamaha", "Kawasaki", "Suzuki",
	"Ducati", "BMW", "KTM", "Harley-Davidson"
]

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

const PAINT_COLORS: Array = [
	Color(0.85, 0.1, 0.1),
	Color(0.1, 0.1, 0.1),
	Color(0.95, 0.95, 0.95),
	Color(0.0, 0.2, 0.75),
	Color(0.1, 0.7, 0.2),
	Color(0.95, 0.75, 0.05),
	Color(0.6, 0.15, 0.6),
	Color(0.9, 0.5, 0.0),
]

@export var brand: String = "Honda"
@export var model: String = "CBR600RR"
@export var year: int = 2010
@export var mileage: int = 0
@export var condition: float = 100.0
@export var engine_hp: int = 100
@export var price_buy: int = 0
@export var price_sell: int = 0
@export var rarity: float = 0.5
@export var base_value: int = 0
@export var body_color: Color = Color(0.85, 0.1, 0.1)
@export var exhaust_tuned: bool = false
@export var suspension_tuned: bool = false
@export var painted: bool = false


func get_full_name() -> String:
	return "%s %s (%d)" % [brand, model, year]


func get_condition_color() -> Color:
	"""Цвет зависит от состояния: чем хуже — тем ближе к ржаво-коричневому."""
	var c: Color = body_color
	if condition >= 80.0:
		return c
	elif condition >= 50.0:
		var k: float = (condition - 50.0) / 30.0
		return c.lerp(Color(0.35, 0.3, 0.25), 1.0 - k)
	else:
		var k: float = condition / 50.0
		return Color(0.35, 0.3, 0.25).lerp(Color(0.45, 0.25, 0.1), 1.0 - k)


func get_roughness() -> float:
	return clamp(1.0 - condition / 100.0, 0.1, 0.95)


func calc_real_value() -> int:
	var value: float = float(base_value)
	value *= 0.4 + 0.6 * (condition / 100.0)
	value *= max(0.3, 1.0 - (mileage / 10000.0) * 0.02)
	if exhaust_tuned:
		value += 15000
	if suspension_tuned:
		value += 10000
	if painted:
		value += 3000
	value *= 0.7 + 0.6 * rarity
	return int(value)


# --- Действия мастерской ---------------------------------------------------

func repair_engine() -> Dictionary:
	if condition >= 100.0:
		return {"cost": 0, "days": 0, "success": false, "msg": "Мотоцикл уже в идеальном состоянии"}
	var needed: float = 100.0 - condition
	var cost: int = int(needed * 200.0)
	var days: int = max(1, int(needed / 25.0))
	condition = 100.0
	mileage = max(0, mileage - 5000)
	return {"cost": cost, "days": days, "success": true, "msg": "Двигатель отремонтирован"}


func paint(new_color: Color) -> Dictionary:
	if painted and body_color == new_color:
		return {"cost": 0, "days": 0, "success": false, "msg": "Такой цвет уже стоит"}
	var cost: int = 5000
	var days: int = 1
	body_color = new_color
	painted = true
	condition = min(100.0, condition + 2.0)
	return {"cost": cost, "days": days, "success": true, "msg": "Мотоцикл перекрашен"}


func tune_exhaust() -> Dictionary:
	if exhaust_tuned:
		return {"cost": 0, "days": 0, "success": false, "msg": "Выхлоп уже тюнингован"}
	var cost: int = 20000
	var days: int = 2
	engine_hp += 15
	exhaust_tuned = true
	return {"cost": cost, "days": days, "success": true, "msg": "Выхлоп тюнингован (+15 л/с)"}


func tune_suspension() -> Dictionary:
	if suspension_tuned:
		return {"cost": 0, "days": 0, "success": false, "msg": "Подвеска уже тюнингована"}
	var cost: int = 12000
	var days: int = 1
	suspension_tuned = true
	condition = min(100.0, condition + 3.0)
	return {"cost": cost, "days": days, "success": true, "msg": "Подвеска улучшена"}


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
