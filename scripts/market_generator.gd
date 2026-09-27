extends RefCounted
## MarketGenerator — процедурно генерирует предложения для рынка.
## Статический утилитарный класс (доступен глобально через class_name).

class_name MarketGenerator


static func generate_offers(game: Node, count: int) -> void:
	game.market_offers.clear()
	for i in count:
		var bike: Motorcycle = _generate_bike(game.reputation)
		game.market_offers.append(bike)


static func _generate_bike(reputation: float) -> Motorcycle:
	var bike := Motorcycle.new()
	var brands: Array = Motorcycle.BRANDS
	bike.brand = brands[randi() % brands.size()]
	var models: Array = Motorcycle.MODELS_BY_BRAND[bike.brand]
	bike.model = models[randi() % models.size()]

	var year_min: int = 1990
	var year_max: int = 2024
	var year_floor: int = int(lerp(year_min, 2005, reputation))
	bike.year = randi_range(year_floor, year_max)

	var age: int = 2024 - bike.year
	bike.mileage = int(randf_range(float(age * 500), float(age * 2500)))
	bike.mileage = max(500, bike.mileage)

	var cond: float = 100.0 - age * 2.0 - bike.mileage / 500.0
	cond += randf_range(-10.0, 15.0)
	bike.condition = clamp(cond, 10.0, 100.0)

	bike.engine_hp = _generate_hp(bike.brand)

	bike.rarity = randf_range(0.0, 1.0)
	if randf() < reputation * 0.3:
		bike.rarity = randf_range(0.7, 1.0)

	bike.base_value = _generate_base_value(bike.brand, bike.rarity, bike.engine_hp)
	bike.body_color = Motorcycle.PAINT_COLORS[randi() % Motorcycle.PAINT_COLORS.size()]

	var real: int = bike.calc_real_value()
	bike.price_buy = real

	var markup: float = randf_range(-0.25, 0.25 + 0.2 * (1.0 - reputation))
	bike.price_sell = int(real * (1.0 + markup))
	bike.price_sell = max(bike.price_sell, 5000)

	return bike


static func _generate_hp(brand: String) -> int:
	var hp_ranges: Dictionary = {
		"Honda": Vector2i(40, 180),
		"Yamaha": Vector2i(45, 200),
		"Kawasaki": Vector2i(50, 230),
		"Suzuki": Vector2i(50, 200),
		"Ducati": Vector2i(70, 220),
		"BMW": Vector2i(60, 210),
		"KTM": Vector2i(40, 180),
		"Harley-Davidson": Vector2i(50, 110),
	}
	var rng: Vector2i = hp_ranges.get(brand, Vector2i(50, 150))
	return randi_range(rng.x, rng.y)


static func _generate_base_value(brand: String, rarity: float, hp: int) -> int:
	var brand_mult: Dictionary = {
		"Honda": 1.0, "Yamaha": 1.0, "Kawasaki": 1.0, "Suzuki": 0.95,
		"Ducati": 1.6, "BMW": 1.5, "KTM": 1.1, "Harley-Davidson": 1.4
	}
	var mult: float = float(brand_mult.get(brand, 1.0))
	var hp_value: int = hp * 600
	var rare_bonus: int = int(rarity * 150000)
	var base: int = int((hp_value + 80000 + rare_bonus) * mult)
	return max(base, 60000)
