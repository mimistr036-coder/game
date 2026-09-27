extends Node3D
## Motorcycle3D — 3D-представление мотоцикла в гараже.
## В _ready() строит прототип из CSG-примитивов. Метод load_real_model()
## позволяет подменить прототип на импортированную .glb/.gltf-модель.

@export var bike_data: Motorcycle = null

var _root_prototype: Node3D
var _body_material: StandardMaterial3D
var _wheel_material: StandardMaterial3D
var _metal_material: StandardMaterial3D
var _seat_material: StandardMaterial3D

signal clicked(motorcycle_node)


func _ready() -> void:
	_build_materials()
	_build_prototype()
	apply_data()


# --- Материалы -------------------------------------------------------------

func _build_materials() -> void:
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


# --- Строительство CSG-прототипа -------------------------------------------

func _build_prototype() -> void:
	if is_instance_valid(_root_prototype):
		_root_prototype.queue_free()

	_root_prototype = Node3D.new()
	_root_prototype.name = "Prototype"
	add_child(_root_prototype)

	# Заднее колесо (цилиндр, повёрнутый вокруг Z на 90° — ось вдоль X)
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

	# Рама
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

	# Сиденье
	var seat := CSGBox3D.new()
	seat.name = "Seat"
	seat.size = Vector3(0.7, 0.15, 0.3)
	seat.position = Vector3(-0.4, 0.85, 0.0)
	seat.material = _seat_material
	_root_prototype.add_child(seat)

	# Руль (поперёк)
	var handle := CSGCylinder3D.new()
	handle.name = "Handlebar"
	handle.radius = 0.035
	handle.height = 0.7
	handle.rotation_degrees = Vector3(0, 90, 0)
	handle.position = Vector3(0.55, 1.15, 0)
	handle.material = _metal_material
	_root_prototype.add_child(handle)

	# Вилка
	var fork := CSGBox3D.new()
	fork.name = "Fork"
	fork.size = Vector3(0.08, 0.7, 0.08)
	fork.position = Vector3(0.75, 0.75, 0)
	fork.material = _metal_material
	_root_prototype.add_child(fork)

	# Выхлоп
	var exhaust := CSGCylinder3D.new()
	exhaust.name = "Exhaust"
	exhaust.radius = 0.06
	exhaust.height = 0.7
	exhaust.rotation_degrees = Vector3(0, 0, 90)
	exhaust.position = Vector3(-0.4, 0.4, 0.22)
	exhaust.material = _metal_material
	_root_prototype.add_child(exhaust)

	# Боковые кузовные панели (окрашены в цвет кузова)
	var body_panel := CSGBox3D.new()
	body_panel.name = "BodyPanel"
	body_panel.size = Vector3(0.9, 0.35, 0.35)
	body_panel.position = Vector3(0.1, 0.7, 0)
	body_panel.material = _body_material
	_root_prototype.add_child(body_panel)

	# Коллизия для кликов
	var col := StaticBody3D.new()
	col.name = "ClickBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.2, 0.7)
	shape.shape = box
	shape.position = Vector3(0, 0.7, 0)
	col.add_child(shape)
	_root_prototype.add_child(col)


# --- Применение данных из Motorcycle ---------------------------------------

func apply_data() -> void:
	if bike_data == null:
		return
	if not is_instance_valid(_body_material):
		return
	_body_material.albedo_color = bike_data.get_condition_color()
	_body_material.roughness = bike_data.get_roughness()
	# Визуальный эффект тюнинга выхлопа
	if is_instance_valid(_root_prototype):
		var exhaust: CSGCylinder3D = _root_prototype.get_node_or_null("Exhaust")
		if is_instance_valid(exhaust) and bike_data.exhaust_tuned:
			exhaust.radius = 0.09
			var tuned_mat := _metal_material.duplicate() as StandardMaterial3D
			tuned_mat.albedo_color = Color(0.2, 0.2, 0.25)
			tuned_mat.metallic = 1.0
			exhaust.material = tuned_mat


func notify_clicked() -> void:
	emit_signal("clicked", self)


# --- Загрузка реальной модели ----------------------------------------------

func load_real_model(path: String) -> bool:
	"""Загрузить .glb/.gltf и заменить CSG-прототип. Подробнее в models/README.md."""
	if not ResourceLoader.exists(path):
		push_warning("Модель не найдена: %s" % path)
		return false
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_warning("Не удалось загрузить модель: %s" % path)
		return false
	# Удалить прототип
	if is_instance_valid(_root_prototype):
		_root_prototype.queue_free()
		_root_prototype = null
	var instance: Node3D = packed.instantiate() as Node3D
	if instance == null:
		push_warning("Корень модели не является Node3D: %s" % path)
		return false
	instance.name = "RealModel"
	add_child(instance)
	# Подгонка масштаба
	var aabb: AABB = _calculate_aabb(instance)
	if aabb.size.length() > 0.001:
		var target_height: float = 1.3
		var s: float = target_height / max(aabb.size.y, 0.01)
		instance.scale = Vector3(s, s, s)
		var scaled_aabb := _calculate_aabb(instance)
		instance.position.y -= scaled_aabb.position.y
	return true


func _calculate_aabb(node: Node3D) -> AABB:
	var aabb := AABB()
	var first := true
	for child in node.get_children():
		var child_aabb := AABB()
		var has_child := false
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi.mesh:
				child_aabb = mi.get_aabb()
				# Переводим в локальные координаты корня
				var global_origin := mi.to_global(child_aabb.position)
				var global_end := mi.to_global(child_aabb.position + child_aabb.size)
				var local_origin := node.to_local(global_origin)
				var local_end := node.to_local(global_end)
				child_aabb = AABB(local_origin, local_end - local_origin)
				has_child = true
		elif child is Node3D:
			var sub := _calculate_aabb(child as Node3D)
			if sub.size.length() > 0.001:
				child_aabb = sub
				has_child = true
		if has_child:
			if first:
				aabb = child_aabb
				first = false
			else:
				aabb = aabb.merge(child_aabb)
	return aabb
