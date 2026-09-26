extends Node
# Сетевой менеджер - LAN мессенджер на ENet
# Можно хостить сервер прямо из Godot клиента

signal server_started(port: int)
signal server_stopped
signal connected_to_server
signal disconnected_from_server
signal peer_joined(id: int, name: String)
signal peer_left(id: int)
signal message_received(chat_id: String, sender: String, text: String)

var is_server: bool = false
var is_client: bool = false
var peer: ENetMultiplayerPeer
var peers_info: Dictionary = {} # id -> name

const DEFAULT_PORT = 7000

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func is_connected_to_network() -> bool:
	return is_server or is_client

func host_server(port: int = DEFAULT_PORT, player_name: String = "") -> bool:
	if is_connected_to_network():
		stop_network()
	
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, 32)
	if err != OK:
		print("Не удалось создать сервер: ", err)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_server = true
	is_client = false
	peers_info[1] = player_name if player_name != "" else ChatManager.my_name
	
	print("Сервер запущен на порту %d" % port)
	server_started.emit(port)
	return true

func join_server(ip: String = "127.0.0.1", port: int = DEFAULT_PORT, player_name: String = "") -> bool:
	if is_connected_to_network():
		stop_network()
	
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		print("Не удалось подключиться: ", err)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_client = true
	is_server = false
	peers_info[multiplayer.get_unique_id()] = player_name if player_name != "" else ChatManager.my_name
	
	print("Подключаемся к %s:%d" % [ip, port])
	return true

func stop_network():
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	is_server = false
	is_client = false
	peers_info.clear()
	server_stopped.emit()
	disconnected_from_server.emit()
	print("Сеть остановлена")

func send_chat_message(chat_id: String, text: String):
	if not is_connected_to_network():
		return
	var sender = ChatManager.my_name
	rpc_send_message.rpc(chat_id, sender, text, Time.get_unix_time_from_system())

@rpc("any_peer", "call_local", "reliable")
func rpc_send_message(chat_id: String, sender: String, text: String, timestamp: float):
	# Не добавляем свое же сообщение второй раз (call_local уже вызовет локально)
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Если это наш собственный вызов с call_local, is_me уже обработано в ChatManager
	# Для сетевых сообщений - is_me = false
	if sender_id == 0: # локальный вызов
		return # уже добавлено через ChatManager.send_message
	
	print("Получено по сети [%s] %s: %s" % [chat_id, sender, text])
	ChatManager.send_message(chat_id, text, false, sender)
	message_received.emit(chat_id, sender, text)
	
	# Если мы сервер - ретранслируем всем кроме отправителя
	if is_server:
		rpc_relay_message.rpc(chat_id, sender, text, timestamp)

@rpc("authority", "call_local", "reliable")
func rpc_relay_message(chat_id: String, sender: String, text: String, timestamp: float):
	if is_server:
		return # сервер уже обработал
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 1: # от сервера
		# Проверяем не наше ли это сообщение
		if sender == ChatManager.my_name:
			return
		ChatManager.send_message(chat_id, text, false, sender)
		message_received.emit(chat_id, sender, text)

# Callbacks
func _on_peer_connected(id: int):
	print("Пир подключился: %d" % id)
	peers_info[id] = "User_%d" % id
	peer_joined.emit(id, peers_info[id])
	
	# Сервер приветствует
	if is_server:
		rpc_welcome_peer.rpc_id(id, ChatManager.my_name)

@rpc("authority", "reliable")
func rpc_welcome_peer(server_name: String):
	print("Подключен к серверу: ", server_name)

func _on_peer_disconnected(id: int):
	print("Пир отключился: %d" % id)
	peers_info.erase(id)
	peer_left.emit(id)

func _on_connected_to_server():
	print("Успешно подключились к серверу!")
	is_client = true
	connected_to_server.emit()

func _on_connection_failed():
	print("Не удалось подключиться к серверу")
	stop_network()

func _on_server_disconnected():
	print("Сервер отключился")
	stop_network()

# WebSocket версия (для интернета, не только LAN)
# Можно расширить:
var ws_peer: WebSocketPeer
var ws_url: String = ""

func connect_websocket(url: String):
	ws_url = url
	ws_peer = WebSocketPeer.new()
	ws_peer.connect_to_url(url)
	print("WebSocket подключается к ", url)

func _process(_delta):
	if ws_peer:
		ws_peer.poll()
		var state = ws_peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while ws_peer.get_available_packet_count():
				var packet = ws_peer.get_packet()
				var text = packet.get_string_from_utf8()
				print("WS получил: ", text)
				# Парсим JSON {chat_id, sender, text}
				var json = JSON.new()
				if json.parse(text) == OK:
					var data = json.data
					if data.has("chat_id"):
						ChatManager.send_message(data.chat_id, data.text, false, data.sender)
