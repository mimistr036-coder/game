extends Node3D
## GarageManager — 3D-сцена гаража.
## Строит из CSG пол/стены/ворота, управляет слотами, расставляет
## 3D-модели мотоциклов, вращает камерой-орбитой вокруг выбранного.

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
const SLOTS_MAX_VISUAL: int = 10
var _slots_positions: Array = []
var _bike_nodes: Array = []
var _selected_index: int = -1

# Камера-орбита
var _cam_angle: float = -0.5
var _cam_pitch: float = 0.35
var _cam_distance: float = 5.0
var _cam_target: Vector3 = Vector3(0, 0.7, 0)
var _dragging: bool = false
var _drag_last: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_slots_positions()
	_build_garage_geometry()
	GameManager.garage_changed.connect(_refresh_bikes)
	GameManager.money_changed.connect(_refresh_ui)
	GameManager.day_changed.connect(_refresh_ui)
	GameManager.reputation_changed.connect(_refresh_ui)
	send_workshop_btn.pressed.connect(_on_send_workshop)
	send_sell_btn.pressed.connect(_on_send_sell)
	interact_panel.visible = false
	_refresh_bikes()
	_update_camera()


func _input(event: InputEvent) -> void:
	# ЛКМ или тач — рейкаст для выбора мотоцикла
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_motorcycle(event.position)
		_dragging = true
		_drag_last = event.position
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = false
	elif event is InputEventScreenTouch and event.pressed:
		_pick_motorcycle(event.position)
		_dragging = true
		_drag_last = event.position
	elif event is InputEventScreenTouch and not event.pressed:
		_dragging = false
	# Вращение ПКМ
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_dragging = true
			_drag_last = event.position
		elif event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_distance = max(2.0, _cam_distance - 0.3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_distance = min(10.0, _cam_distance + 0.3)
	# Тач-двумя пальцами — зум, одним — драг
	if event is InputEventScreenDrag:
		var delta: Vector2 = event.position - _drag_last
		_drag_last = event.position
		_cam_angle -= delta.x * 0.005
		_cam_pitch = clamp(_cam_pitch - delta.y * 0.005, -0.2, 1.2)
	# Мышью — поворот камеры
	if event is InputEventMouseMotion and _dragging:
		var delta: Vector2 = event.position - _drag_last
		_drag_last = event.position
		_cam_angle -= delta.x * 0.005
		_cam_pitch = clamp(_cam_pitch - delta.y * 0.005, -0.2, 1.2)
	# Клавиатура: WASD/стрелки — двигать камерой (имитация хотьбы)
	if event is InputEventKey and event.pressed and not event.echo:
		var move_speed: float = 1.2
		if event.keycode == KEY_W or event.keycode == KEY_UP:
			_cam_target += -transform.basis.z * move_speed
		elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
			_cam_target += transform.basis.z * move_speed
		elif event.keycode == KEY_A or event.keycode == KEY_LEFT:
			_cam_target += -transform.basis.x * move_speed
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			_cam_target += transform.basis.x * move_speed
		elif event.keycode == KEY_ESCAPE:
			# Сброс камеры в центр гаража
			_selected_index = -1
			interact_panel.visible = false
			_cam_target = Vector3(0, 0.8, 0)
			_refresh_ui()


func _pick_motorcycle(mouse_pos: Vector2) -> void:
	if camera == null:
		return
	# Ждём один кадр, чтобы физика успела обновиться
	var space_state := get_world_3d().direct_space_state
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * 50.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty() or not result.has("collider"):
		return
	var col: Object = result["collider"]
	if not (col is Node):
		return
	var p: Node = col as Node
	while p != null:
		if p.is_in_group("motorcycle3d"):
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
	_slots_positions.clear()
	var start_x: float = -4.0
	var spacing: float = 2.0
	for i in SLOTS_MAX_VISUAL:
		var row: int = int(i / 5)
		var col: int = i % 5
		var pos := Vector3(start_x + col * spacing, 0.05, -3.5 + row * 2.5)
		_slots_positions.append(pos)


func _build_garage_geometry() -> void:
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.6, 0.6, 0.62)
	wall_mat.roughness = 0.9

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.35, 0.35, 0.38)
	floor_mat.roughness = 0.85

	var gate_mat := StandardMaterial3D.new()
	gate_mat.albedo_color = Color(0.15, 0.15, 0.17)
	gate_mat.roughness = 0.6
	gate_mat.metallic = 0.6

	# Пол
	var floor_mesh := CSGBox3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.size = Vector3(14, 0.2, 10)
	floor_mesh.position = Vector3(0, -0.1, 0)
	floor_mesh.material = floor_mat
	garage_root.add_child(floor_mesh)

	# Разметка слотов
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
	back_wall.material = wall_mat
	garage_root.add_child(back_wall)

	# Боковые стены
	for sx in [-1.0, 1.0]:
		var wall := CSGBox3D.new()
		wall.size = Vector3(0.3, 5, 10)
		wall.position = Vector3(sx * 7.0, 2.5, 0)
		wall.material = wall_mat
		garage_root.add_child(wall)

	# Потолок
	var ceiling := CSGBox3D.new()
	ceiling.size = Vector3(14, 0.2, 10)
	ceiling.position = Vector3(0, 5.1, 0)
	ceiling.material = wall_mat
	garage_root.add_child(ceiling)

	# Ворота — CSGCombiner3D с вырезанным проёмом
	var gate_combiner := CSGCombiner3D.new()
	gate_combiner.position = Vector3(0, 2.5, 5.0)
	garage_root.add_child(gate_combiner)

	var gate := CSGBox3D.new()
	gate.size = Vector3(14, 5, 0.3)
	gate.material = gate_mat
	gate.operation = CSGShape3D.OPERATION_UNION
	gate_combiner.add_child(gate)

	var gate_hole := CSGBox3D.new()
	gate_hole.size = Vector3(6, 3.5, 0.5)
	gate_hole.position = Vector3(0, -0.75, 0.0)
	gate_hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	gate_combiner.add_child(gate_hole)

	# Направленный свет (имитация солнца через ворота)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 150, 0)
	sun.light_energy = 0.8
	sun.light_color = Color(1, 0.95, 0.85)
	sun.shadow_enabled = true
	garage_root.add_child(sun)

	# Несколько потолочных ламп
	for pos in [Vector3(-3, 4.8, -2), Vector3(3, 4.8, -2), Vector3(0, 4.8, 1)]:
		var omni := OmniLight3D.new()
		omni.position = pos
		omni.omni_range = 8.0
		omni.light_energy = 0.7
		omni.light_color = Color(1, 0.95, 0.85)
		garage_root.add_child(omni)

	# Окружение (фон за воротами + амбиент)
	var env := WorldEnvironment.new()
	var env_data := Environment.new()
	env_data.background_mode = Environment.BG_COLOR
	env_data.background_color = Color(0.08, 0.08, 0.1)
	env_data.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_data.ambient_light_color = Color(0.55, 0.6, 0.65)
	env_data.ambient_light_energy = 0.5
	# Явно приводим tonemap_mode через тип enum, чтобы не было ворнинга
	env_data.tonemap_mode = Environment.ToneMapper(0)
	env.environment = env_data
	garage_root.add_child(env)


# --- Управление мотоциклами на слотах --------------------------------------

func _refresh_bikes() -> void:
	for n in _bike_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_bike_nodes.clear()
	for i in GameManager.garage.size():
		var bike_data: Motorcycle = GameManager.garage[i]
		var node3d: Node3D = MOTORCYCLE_SCENE.instantiate()
		node3d.set("bike_data", bike_data)
		node3d.add_to_group("motorcycle3d")
		node3d.position = _slots_positions[i] + Vector3(0, 0, 0.4)
		node3d.rotation_degrees = Vector3(0, 180, 0)
		bikes_anchor.add_child(node3d)
		node3d.call("apply_data")
		_bike_nodes.append(node3d)
	_refresh_ui()


func _on_bike_clicked(_node: Node, index: int) -> void:
	_selected_index = index
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
	if ui:
		ui.call("show_workshop", _selected_index)


func _on_send_sell() -> void:
	if _selected_index < 0:
		return
	var ui := get_tree().get_first_node_in_group("ui_manager")
	if ui:
		ui.call("show_sell_menu", _selected_index)


# --- Камера ----------------------------------------------------------------

func _update_camera() -> void:
	var target: Vector3 = Vector3(0, 0.8, 0)
	if _selected_index >= 0 and _selected_index < _bike_nodes.size():
		target = _bike_nodes[_selected_index].global_position + Vector3(0, 0.7, 0)
	_cam_target = _cam_target.lerp(target, 0.12)
	camera.global_position = _cam_target + Vector3(
		cos(_cam_angle) * cos(_cam_pitch) * _cam_distance,
		sin(_cam_pitch) * _cam_distance,
		sin(_cam_angle) * cos(_cam_pitch) * _cam_distance
	)
	camera.look_at(_cam_target, Vector3.UP)


# --- Расширение гаража ------------------------------------------------------

func try_expand_garage() -> bool:
	return GameManager.buy_upgrade_slot()
