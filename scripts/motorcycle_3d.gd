extends Node3D
## Motorcycle3D — визуальное представление мотоцикла в 3D.
## Строит прототип из CSG-примитивов в _ready(), если модели нет.
## Поддерживает загрузку настоящей .glb/.gltf модели через load_real_model().

@export var bike_data: Motorcycle = null

# Узлы CSG-прототипа (создаются в скрипте, чтобы не тащить их в редакторе)
var _root_prototype: Node3D
var _body_material: StandardMaterial3D
var _wheel_material: StandardMaterial3D
var _metal_material: StandardMaterial3D
var _seat_material: StandardMaterial3D

# Сигнал о клике (стреляет GarageManager, когда луч попал в этот мотоцикл)
signal clicked(motorcycle_node)


func _ready() -> void:
	_build_materials()
	_build_prototype()
	apply_data()


# Публичный метод, чтобы внешний код мог вызвать клик (используется GarageManager)
func notify_clicked() -> void:
	emit_signal("clicked", self)


## --- Построение прототипа из CSG ------------------------------------------

func _build_materials() -> void:
	# Материал кузова (будет менять цвет в зависимости от состояния)
	_body_material = StandardMaterial3D.new()
	_body_material.roughness = 0.4
	_body_material.metallic = 0.3

	_wheel_material = StandardMaterial3D.new()
	_wheel_material.albedo_color = Color(0.1, 0.1, 0.1)
	_wheel_material.roughness = 0.95

	_metal_material = StandardMaterial3D.new()
	_metal_material.albedo_color = Color(0.6, 0.6, 0.65)
	_metal_material.metallic = 0.85
	_metal_material.roughness = 0.3

	_seat_material = StandardMaterial3D.new()
	_seat_material.albedo_color = Color(0.15, 0.1, 0.08)
	_seat_material.roughness = 0.9


func _build_prototype() -> void:
	# Удаляем предыдущий прототип, если был
	if is_instance_valid(_root_prototype):
		_root_prototype.queue_free()

	_root_prototype = Node3D.new()
	_root_prototype.name = "Prototype"
	add_child(_root_prototype)

	# Заднее колесо (диски по X=0, поэтому цилиндр поворачиваем вокруг Z на 90°)
	var rear_wheel := CSGCylinder3D.new()
	rear_wheel.name = "RearWheel"
	rear_wheel.radius = 0.35
	rear_wheel.height = 0.18
	rear_wheel.rotation_degrees = Vector3(0, 0, 90)
	rear_wheel.position = Vector3(-0.8, 0.35, 0)
	rear_wheel.material = _wheel_material
	_root_prototype.add_child(rear_wheel)

	# Переднее колесо
	var front_wheel := CSGCylinder3D.new()
	front_wheel.name = "FrontWheel"
	front_wheel.radius = 0.35
	front_wheel.height = 0.18
	front_wheel.rotation_degrees = Vector3(0, 0, 90)
	front_wheel.position = Vector3(0.9, 0.35, 0)
	front_wheel.material = _wheel_material
	_root_prototype.add_child(front_wheel)

	# Рама (вытянутый бокс)
	var frame := CSGBox3D.new()
	frame.name = "Frame"
	frame.size = Vector3(1.8, 0.25, 0.35)
	frame.position = Vector3(0.0, 0.6, 0.0)
	frame.material = _metal_material
	_root_prototype.add_child(frame)

	# Бак (сплюснутая сфера)
	var tank := CSGSphere3D.new()
	tank.name = "Tank"
	tank.radius = 0.35
	tank.position = Vector3(0.1, 0.95, 0.0)
	tank.scale = Vector3(1.1, 0.7, 0.8)
	tank.material = _body_material
	_root_prototype.add_child(tank)

	# Сиденье (скруглённый бокс)
	var seat := CSGBox3D.new()
	seat.name = "Seat"
	seat.size = Vector3(0.7, 0.15, 0.3)
	seat.position = Vector3(-0.4, 0.85, 0.0)
	seat.material = _seat_material
	_root_prototype.add_child(seat)

	# Руль (тонкий цилиндр поперёк)
	var handle := CSGCylinder3D.new()
	handle.name = "Handlebar"
	handle.radius = 0.035
	handle.height = 0.7
	handle.rotation_degrees = Vector3(0, 90, 0)
	handle.position = Vector3(0.55, 1.15, 0)
	handle.material = _metal_material
	_root_prototype.add_child(handle)

	# Вилка переднего колеса
	var fork := CSGBox3D.new()
	fork.name = "Fork"
	fork.size = Vector3(0.08, 0.7, 0.08)
	fork.position = Vector3(0.75, 0.75, 0)
	fork.material = _metal_material
	_root_prototype.add_child(fork)

	# Выхлопная труба (если не тюнинг — обычный цилиндр)
	var exhaust := CSGCylinder3D.new()
	exhaust.name = "Exhaust"
	exhaust.radius = 0.06
	exhaust.height = 0.7
	exhaust.rotation_degrees = Vector3(0, 0, 90)
	exhaust.position = Vector3(-0.4, 0.4, 0.22)
	exhaust.material = _metal_material
	_root_prototype.add_child(exhaust)

	# Кузовные панели (боковые) — для цвета
	var body_panel := CSGBox3D.new()
	body_panel.name = "BodyPanel"
	body_panel.size = Vector3(0.9, 0.35, 0.35)
	body_panel.position = Vector3(0.1, 0.7, 0)
	body_panel.material = _body_material
	_root_prototype.add_child(body_panel)

	# Коллизия для кликов (один большой бокс, упрощённо)
	var col := StaticBody3D.new()
	col.name = "ClickBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.2, 0.7)
	shape.shape = box
	shape.position = Vector3(0, 0.7, 0)
	col.add_child(shape)
	_root_prototype.add_child(col)


## --- Применение данных из Motorcycle ---------------------------------------

func apply_data() -> void:
	"""Обновить внешний вид по данным bike_data."""
	if bike_data == null:
		return
	if not is_instance_valid(_body_material):
		await ready
	_body_material.albedo_color = bike_data.get_condition_color()
	_body_material.roughness = bike_data.get_roughness()
	# Тюнинг выхлопа — меняем размер/цвет трубы
	var exhaust: CSGCylinder3D = _root_prototype.get_node_or_null("Exhaust") if is_instance_valid(_root_prototype) else null
	if exhaust and bike_data.exhaust_tuned:
		exhaust.radius = 0.09
		var tuned_mat := _metal_material.duplicate()
		tuned_mat.albedo_color = Color(0.2, 0.2, 0.25)
		tuned_mat.metallic = 1.0
		exhaust.material = tuned_mat


## --- Замена на реальную модель ---------------------------------------------

func load_real_model(path: String) -> bool:
	"""Загрузить настоящую .glb/.gltf модель и заменить CSG-прототип.
	Путь — например 'res://models/my_bike.glb'. Файл нужно положить в res://models/.
	После вызова прототип удаляется, а импортированная сцена становится
	дочерней. Метод возвращает true при успехе."""
	if not ResourceLoader.exists(path):
		push_warning("Модель не найдена: %s" % path)
		return false
	var packed: PackedScene = load(path)
	if packed == null:
		push_warning("Не удалось загрузить модель: %s" % path)
		return false
	# Удаляем прототип
	if is_instance_valid(_root_prototype):
		_root_prototype.queue_free()
		_root_prototype = null
	var instance: Node3D = packed.instantiate()
	instance.name = "RealModel"
	add_child(instance)
	# Подгоняем масштаб и положение (glb-модели часто огромные или смещённые)
	var aabb: AABB = _calculate_aabb(instance)
	if aabb.size.length() > 0.001:
		# Подогнать высоту под ~1.3 м
		var target_height: float = 1.3
		var s: float = target_height / max(aabb.size.y, 0.01)
		instance.scale = Vector3(s, s, s)
		# Выровнять по земле
		var scaled_aabb := _calculate_aabb(instance)
		instance.position.y -= scaled_aabb.position.y
	apply_data()
	return true


func _calculate_aabb(node: Node3D) -> AABB:
	"""Посчитать ограничивающий бокс всех MeshInstance3D в поддереве."""
	var aabb := AABB()
	var first := true
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child
			if mi.mesh:
				var m_aabb: AABB = mi.get_aabb()
				# Переводим в мировые координаты, потом в локальные корня
				var global_origin: Vector3 = mi.to_global(m_aabb.position)
				var global_end: Vector3 = mi.to_global(m_aabb.position + m_aabb.size)
				var local_origin: Vector3 = node.to_local(global_origin)
				var local_end: Vector3 = node.to_local(global_end)
				var local_aabb := AABB(local_origin, local_end - local_origin)
				if first:
					aabb = local_aabb
					first = false
				else:
					aabb = aabb.merge(local_aabb)
		elif child is Node3D:
			var child_aabb: AABB = _calculate_aabb(child as Node3D)
			if child_aabb.size.length() > 0.001:
				if first:
					aabb = child_aabb
					first = false
				else:
					aabb = aabb.merge(child_aabb)
	return aabb
