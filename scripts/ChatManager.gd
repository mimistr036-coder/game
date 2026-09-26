extends Node
# Менеджер чатов - хранит все чаты, сообщения, сохранение

signal chat_list_changed
signal chat_updated(chat_id: String)
signal message_received(chat_id: String, msg: Dictionary)
signal current_chat_changed(chat_id: String)

var chats: Dictionary = {}
var current_chat_id: String = ""
var my_name: String = "Вы"
var my_id: int = randi() % 100000

var _msg_counter: int = 0

func _ready():
	load_chats()
	if chats.is_empty():
		_create_mock_data()
		save_chats()
	# Выбираем первый чат
	if current_chat_id == "" and not chats.is_empty():
		current_chat_id = chats.keys()[0]

func _create_mock_data():
	var now = Time.get_unix_time_from_system()
	
	chats = {
		"team": {
			"id": "team",
			"name": "Команда Godot",
			"avatar": "T",
			"color": Color("#ff7b00"),
			"is_group": true,
			"online": true,
			"unread": 3,
			"members": ["Вы", "Алексей", "Мария", "Иван"],
			"messages": [
				_make_msg("Алексей", "Ребят, кто делал мессенджер на Годоте?", now - 3600, false),
				_make_msg("Мария", "Я делала! ENet + WebSocket отлично работает", now - 3500, false),
				_make_msg("Вы", "Да, Godot идеален для кастомного UI", now - 3400, true),
				_make_msg("Иван", "Кидай прототип в общий чат 🚀", now - 100, false),
			]
		},
		"alex": {
			"id": "alex",
			"name": "Алексей",
			"avatar": "А",
			"color": Color("#2b88d8"),
			"is_group": false,
			"online": true,
			"unread": 0,
			"members": ["Вы", "Алексей"],
			"messages": [
				_make_msg("Алексей", "Привет! Как прогресс с мессенджером?", now - 7200, false),
				_make_msg("Вы", "Привет! Делаю на Godot, получается топ", now - 7000, true),
				_make_msg("Алексей", "Можешь показать код? Хочу тоже попробовать", now - 200, false),
			]
		},
		"design": {
			"id": "design",
			"name": "Дизайн-чат",
			"avatar": "D",
			"color": Color("#e0407b"),
			"is_group": true,
			"online": false,
			"unread": 12,
			"members": ["Вы", "Дизайнеры"],
			"messages": [
				_make_msg("Анна", "Залила новые макеты для мессенджера", now - 86400, false),
				_make_msg("Вы", "Вау, пузырьки как в телеге 🔥", now - 86000, true),
			]
		},
		"bot": {
			"id": "bot",
			"name": "Godot Bot",
			"avatar": "B",
			"color": Color("#4caf50"),
			"is_group": false,
			"online": true,
			"unread": 0,
			"members": ["Вы", "Bot"],
			"messages": [
				_make_msg("Godot Bot", "Привет! Я бот. Напиши мне что-нибудь, и я отвечу.\n\nПодсказка: Godot умеет в HTTPRequest, WebSocket, ENet, WebRTC - можно сделать полноценный мессенджер!", now - 5000, false),
			]
		},
		"general": {
			"id": "general",
			"name": "Общий чат",
			"avatar": "O",
			"color": Color("#9c27b0"),
			"is_group": true,
			"online": true,
			"unread": 0,
			"members": ["Вы", "Все"],
			"messages": [
				_make_msg("Система", "Добро пожаловать в Godot Messenger! Это полноценный прототип мессенджера на Godot 4.", now - 10000, false),
				_make_msg("Система", "Слева - список чатов, справа - сообщения. Попробуй Host/Join для LAN-чата по сети.", now - 9900, false),
			]
		}
	}

func _make_msg(sender: String, text: String, timestamp: float, is_me: bool) -> Dictionary:
	_msg_counter += 1
	return {
		"id": "m_%d" % _msg_counter,
		"sender": sender,
		"sender_id": my_id if is_me else randi(),
		"text": text,
		"time": timestamp,
		"is_me": is_me,
		"status": "read" if is_me else "delivered" # sent, delivered, read
	}

func get_chat_list() -> Array:
	var list = []
	for chat_id in chats.keys():
		list.append(chats[chat_id])
	# Сортировка по времени последнего сообщения
	list.sort_custom(func(a, b): 
		var ta = a.messages[-1].time if not a.messages.is_empty() else 0
		var tb = b.messages[-1].time if not b.messages.is_empty() else 0
		return ta > tb
	)
	return list

func get_current_chat() -> Dictionary:
	if chats.has(current_chat_id):
		return chats[current_chat_id]
	return {}

func set_current_chat(chat_id: String):
	if chats.has(chat_id):
		current_chat_id = chat_id
		chats[chat_id].unread = 0
		current_chat_changed.emit(chat_id)
		chat_list_changed.emit()
		save_chats()

func send_message(chat_id: String, text: String, is_me: bool = true, sender_name: String = ""):
	if not chats.has(chat_id):
		return
	if text.strip_edges() == "":
		return
	
	var sender = sender_name if sender_name != "" else my_name
	var msg = _make_msg(sender, text, Time.get_unix_time_from_system(), is_me)
	chats[chat_id].messages.append(msg)
	
	chat_updated.emit(chat_id)
	message_received.emit(chat_id, msg)
	chat_list_changed.emit()
	save_chats()
	
	# Авто-ответ для бота
	if chat_id == "bot" and is_me:
		_bot_reply(text)
	
	# Отправка по сети если подключены
	if NetworkManager.is_connected_to_network():
		NetworkManager.send_chat_message(chat_id, text)

func _bot_reply(user_text: String):
	await get_tree().create_timer(0.8 + randf() * 0.8).timeout
	var replies = [
		"Принял! В Godot это делается через WebSocketPeer или ENetMultiplayerPeer.",
		"Кстати, в Godot 4 есть WebRTC - можно даже голосовые звонки сделать!",
		"Если нужен бэкенд - бери Supabase / Firebase + HTTPRequest, или свой сервер на Go/Rust.",
		"UI на Control-нодах в Godot даже удобнее чем в Electron, и весит в 100 раз меньше.",
		"Для файлов - FileAccess + HTTPRequest для загрузки на S3.",
		"Хочешь шифрование? Используй Crypto класс в Godot для E2E.",
	]
	var reply = replies[randi() % replies.size()]
	if "привет" in user_text.to_lower():
		reply = "Привет! 👋 Да, на Godot можно сделать полноценный мессенджер. Смотри код в этом проекте."
	elif "как" in user_text.to_lower():
		reply = "Архитектура: Godot клиент (UI) + сервер (Godot headless / Node / Go) + WebSocket. Все как в обычном мессенджере."
	
	send_message("bot", reply, false, "Godot Bot")

func create_chat(name: String) -> String:
	var id = "chat_%d" % (Time.get_unix_time_from_system())
	chats[id] = {
		"id": id,
		"name": name,
		"avatar": name.substr(0,1).to_upper(),
		"color": Color.from_hsv(randf(), 0.7, 0.9),
		"is_group": false,
		"online": true,
		"unread": 0,
		"members": [my_name, name],
		"messages": []
	}
	chat_list_changed.emit()
	save_chats()
	return id

func get_last_message_text(chat: Dictionary) -> String:
	if chat.messages.is_empty():
		return "Нет сообщений"
	return chat.messages[-1].text

func format_time(timestamp: float) -> String:
	var diff = Time.get_unix_time_from_system() - timestamp
	if diff < 60:
		return "сейчас"
	elif diff < 3600:
		return "%d мин" % int(diff/60)
	elif diff < 86400:
		return Time.get_time_string_from_unix_time(timestamp).substr(0,5)
	else:
		return Time.get_date_string_from_unix_time(timestamp)

# Сохранение
func save_chats():
	# Конвертируем Color в html для JSON
	var to_save = {}
	for id in chats.keys():
		var c = chats[id].duplicate(true)
		if c.has("color") and c.color is Color:
			c.color = c.color.to_html()
		to_save[id] = c
	
	var file = FileAccess.open("user://chats.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(to_save))
		file.close()

func load_chats():
	if not FileAccess.file_exists("user://chats.json"):
		return
	var file = FileAccess.open("user://chats.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var loaded = json.data
			chats = {}
			for id in loaded.keys():
				var c = loaded[id]
				if c.has("color") and c.color is String:
					c.color = Color(c.color)
				# Восстанавливаем Color для сообщений если надо
				chats[id] = c
		file.close()
