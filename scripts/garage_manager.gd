extends Node3D
## GarageManager — 3D-сцена гаража.
## Создаёт из CSG пол/стены/ворота, управляет позициями слотов,
## расставляет 3D-модели мотоциклов, вращает камерой вокруг выбранного.

@onready var camera: Camera3D = $Camera3D
@onready var garage_root: Node3D = $GarageGeometry
@onready var bikes_anchor: Node3D = $BikesAnchor
@onready var ui_root: Control = $UIRoot
@onready var slot_info_label: Label = $UIRoot/SlotInfoLabel
@onready var selected_label: Label = $UIRoot/SelectedLabel
@onready var interact_panel: PanelContainer = $UIRoot/InteractPanel
@onready var send_workshop_btn: Button = $UIRoot/InteractPanel/VBox/SendWorkshopBtn
@onready var send_sell_btn: Button = $UIRoot/InteractPanel/VBox/SendSellBtn

const MOTORCYCLE_SCENE: PackedScene = preload("res://scenes/motorcycle_3d.tscn")
const SLOTS_MAX_VISUAL: int = 10   # визуальные позиции до максимума расширения
var _slots_positions: Array[Vector3] = []
var _bike_nodes: Array = []        # Motorcycle3D в том же порядке, что GameManager.garage
var _selected_index: int = -1

# Камера-орбита
var _cam_angle: float = -0.5
var _cam_pitch: float = 0.35
var _cam_distance: float = 4.5
var _cam_target: Vector3 = Vector3(0, 0.7, 0)
var _dragging: bool = false
var _drag_last: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_slots_positions()
	_build_garage_geometry()
	_refresh_bikes()
	GameManager.garage_changed.connect(_refresh_bikes)
	GameManager.money_changed.connect(_refresh_ui)
	GameManager.day_changed.connect(_refresh_ui)
	GameManager.reputation_changed.connect(_refresh_ui)
	send_workshop_btn.pressed.connect(_on_send_workshop)
	send_sell_btn.pressed.connect(_on_send_sell)
	interact_panel.visible = false
	_update_camera()


func _input(event: InputEvent) -> void:
	# ЛКМ — выбор мотоцикла рейкастом
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_motorcycle(event.position)
	# Вращение камеры ПКМ + колесо зум
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_dragging = true
			_drag_last = event.position
		elif event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_distance = max(2.0, _cam_distance - 0.3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_distance = min(9.0, _cam_distance + 0.3)
	if event is InputEventMouseMotion and _dragging:
		var delta: Vector2 = event.position - _drag_last
		_drag_last = event.position
		_cam_angle -= delta.x * 0.005
		_cam_pitch = clamp(_cam_pitch - delta.y * 0.005, -0.2, 1.2)


func _pick_motorcycle(mouse_pos: Vector2) -> void:
	if camera == null:
		return
	var space := get_world_3d().direct_space_state
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * 50.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var result := space.intersect_ray(query)
	if not result or not result.has("collider"):
		return
	var col: Node = result["collider"]
	# Идём вверх по родителям, ищем узел Motorcycle3D в группе
	var p: Node = col
	while p != null:
		if p.is_in_group("motorcycle3d"):
			# Найти индекс по списку _bike_nodes
			for i in _bike_nodes.size():
				if _bike_nodes[i] == p:
					_on_bike_clicked(p, i)
					return
			return
		p = p.get_parent()


func _process(_delta: float) -> void:
	_update_camera()


# --- Строительство гаража --------------------------------------------------

func _build_slots_positions() -> void:
	# 5 слотов в ряд вдоль стены; при расширении добавляются второй ряд
	_slots_positions.clear()
	var start_x: float = -4.0
	var spacing: float = 2.0
	for i in SLOTS_MAX_VISUAL:
		var row: int = i / 5
		var col: int = i % 5
		var pos := Vector3(start_x + col * spacing, 0.05, -3.5 + row * 2.5)
		_slots_positions.append(pos)


func _build_garage_geometry() -> void:
	# Пол
	var floor := CSGBox3D.new()
	floor.size = Vector3(14, 0.2, 10)
	floor.position = Vector3(0, -0.1, 0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.35, 0.35, 0.38)
	floor_mat.roughness = 0.8
	floor.material = floor_mat
	garage_root.add_child(floor)

	# Разметка пола в слотах — светлые прямоугольники
	for i in SLOTS_MAX_VISUAL:
		var slot_mark := CSGBox3D.new()
		slot_mark.size = Vector3(1.5, 0.02, 2.5)
		slot_mark.position = _slots_positions[i] + Vector3(0, 0.005, 0)
		var sm_mat := StandardMaterial3D.new()
		sm_mat.albedo_color = Color(0.45, 0.45, 0.48)
		sm_mat.roughness = 0.7
		slot_mark.material = sm_mat
		garage_root.add_child(slot_mark)

	# Задняя стена
	var back_wall := CSGBox3D.new()
	back_wall.size = Vector3(14, 5, 0.3)
	back_wall.position = Vector3(0, 2.5, -5.0)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.6, 0.6, 0.62)
	wall_mat.roughness = 0.9
	back_wall.material = wall_mat
	garage_root.add_child(back_wall)

	# Боковые стены
	for sx in [-1.0, 1.0]:
		var wall := CSGBox3D.new()
		wall.size = Vector3(0.3, 5, 10)
		wall.position = Vector3(sx * 7.0, 2.5, 0)
		wall.material = wall_mat
		garage_root.add_child(wall)

	# Ворота — коробка с вырезанным проёмом
	var gate_combiner := CSGCombiner3D.new()
	gate_combiner.position = Vector3(0, 2.5, 5.0)
	garage_root.add_child(gate_combiner)

	var gate := CSGBox3D.new()
	gate.size = Vector3(14, 5, 0.3)
	gate.position = Vector3.ZERO
	var gate_mat := StandardMaterial3D.new()
	gate_mat.albedo_color = Color(0.15, 0.15, 0.17)
	gate_mat.roughness = 0.6
	gate_mat.metallic = 0.6
	gate.material = gate_mat
	gate.operation = CSGShape3D.OPERATION_UNION
	gate_combiner.add_child(gate)

	# Проём в воротах
	var gate_hole := CSGBox3D.new()
	gate_hole.size = Vector3(6, 3.5, 0.5)
	gate_hole.position = Vector3(0, -0.75, 0.0)
	gate_hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	gate_combiner.add_child(gate_hole)

	# Свет: направленный с потолка + несколько омни
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.0
	sun.light_color = Color(1, 0.95, 0.85)
	garage_root.add_child(sun)

	for pos in [Vector3(-3, 4.5, -2), Vector3(3, 4.5, -2), Vector3(0, 4.5, 2)]:
		var omni := OmniLight3D.new()
		omni.position = pos
		omni.omni_range = 8.0
		omni.light_energy = 0.6
		omni.light_color = Color(1, 0.95, 0.85)
		garage_root.add_child(omni)

	# Небо/окружение
	var env := WorldEnvironment.new()
	var env_data := Environment.new()
	env_data.background_mode = Environment.BG_COLOR
	env_data.clear_color = Color(0.08, 0.08, 0.1)
	env_data.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_data.ambient_light_color = Color(0.5, 0.55, 0.6)
	env_data.ambient_light_energy = 0.4
	env.environment = env_data
	garage_root.add_child(env)


# --- Управление мотоциклами на слотах --------------------------------------

func _refresh_bikes() -> void:
	# Удалить все старые узлы мотоциклов
	for n in _bike_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_bike_nodes.clear()
	for i in GameManager.garage.size():
		var bike_data: Motorcycle = GameManager.garage[i]
		var node3d: Node3D = MOTORCYCLE_SCENE.instantiate()
		node3d.set("bike_data", bike_data)
		node3d.add_to_group("motorcycle3d")
		# Ставим на слот (разворачиваем лицом к зрителю, по -Z)
		node3d.position = _slots_positions[i] + Vector3(0, 0, 0.4)
		node3d.rotation_degrees = Vector3(0, 180, 0)
		bikes_anchor.add_child(node3d)
		node3d.apply_data()
		_bike_nodes.append(node3d)
	_refresh_ui()


func _on_bike_clicked(_node, index: int) -> void:
	_selected_index = index
	# Подсвечиваем выбранный (немного поднимаем)
	for i in _bike_nodes.size():
		var n: Node3D = _bike_nodes[i]
		n.position = Vector3(n.position.x, _slots_positions[i].y + (0.15 if i == index else 0.05), n.position.z)
	interact_panel.visible = true
	_refresh_ui()


func _refresh_ui() -> void:
	var used: int = GameManager.garage.size()
	var total: int = GameManager.garage_slots
	slot_info_label.text = "Гараж: %d/%d слотов   —   расширение +1 слот: %d ₽" % [used, total, GameManager.SLOT_UPGRADE_COST]
	if _selected_index >= 0 and _selected_index < GameManager.garage.size():
		var b: Motorcycle = GameManager.garage[_selected_index]
		selected_label.text = "Выбран: %s  •  состояние %d%%  •  реальная цена %d ₽" % [
			b.get_full_name(), int(b.condition), b.calc_real_value()
		]
	else:
		selected_label.text = "Кликните по мотоциклу, чтобы выбрать"
		interact_panel.visible = false


func _on_send_workshop() -> void:
	if _selected_index < 0:
		return
	var ui := get_tree().get_first_node_in_group("ui_manager")
	if ui: ui.show_workshop(_selected_index)


func _on_send_sell() -> void:
	if _selected_index < 0:
		return
	var ui := get_tree().get_first_node_in_group("ui_manager")
	if ui: ui.show_sell_menu(_selected_index)


# --- Камера ----------------------------------------------------------------

func _update_camera() -> void:
	# Если выбран мотоцикл — фокусируемся на нём; иначе — центр гаража
	var target := Vector3(0, 0.7, 0)
	if _selected_index >= 0 and _selected_index < _bike_nodes.size():
		target = _bike_nodes[_selected_index].global_position + Vector3(0, 0.6, 0)
	_cam_target = _cam_target.lerp(target, 0.1)
	camera.global_position = _cam_target + Vector3(
		cos(_cam_angle) * cos(_cam_pitch) * _cam_distance,
		sin(_cam_pitch) * _cam_distance,
		sin(_cam_angle) * cos(_cam_pitch) * _cam_distance
	)
	camera.look_at(_cam_target, Vector3.UP)


# --- Кнопка расширения гаража (UI вызывает этот метод) ---------------------

func try_expand_garage() -> bool:
	return GameManager.buy_upgrade_slot()
