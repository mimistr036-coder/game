extends Control
# Главный UI мессенджера - весь интерфейс строится кодом для простоты

var chat_list_vbox: VBoxContainer
var message_list_vbox: VBoxContainer
var message_scroll: ScrollContainer
var message_input: LineEdit
var search_input: LineEdit
var top_name_label: Label
var top_status_label: Label
var top_avatar: Panel
var top_avatar_label: Label
var typing_label: Label
var network_status_label: Label
var ip_input: LineEdit

var chat_item_nodes: Dictionary = {} # chat_id -> Control

# Цвета как в Telegram
var COLOR_BG = Color("#0e1621")
var COLOR_SIDEBAR = Color("#17212b")
var COLOR_SIDEBAR_HOVER = Color("#202e3a")
var COLOR_BUBBLE_ME = Color("#2b5278")
var COLOR_BUBBLE_OTHER = Color("#182533")
var COLOR_ACCENT = Color("#2b88d8")
var COLOR_TEXT = Color("#f5f5f5")
var COLOR_TEXT_SECONDARY = Color("#a8b3c0")
var COLOR_INPUT = Color("#242f3d")

func _ready():
	_build_ui()
	_connect_signals()
	_refresh_chat_list()
	if ChatManager.current_chat_id != "":
		_show_chat(ChatManager.current_chat_id)

func _connect_signals():
	ChatManager.chat_list_changed.connect(_refresh_chat_list)
	ChatManager.chat_updated.connect(_on_chat_updated)
	ChatManager.current_chat_changed.connect(_show_chat)
	ChatManager.message_received.connect(_on_message_received)
	
	NetworkManager.server_started.connect(_on_server_started)
	NetworkManager.connected_to_server.connect(_on_connected)
	NetworkManager.disconnected_from_server.connect(_on_disconnected)
	NetworkManager.peer_joined.connect(_on_peer_joined)

func _build_ui():
	# Фон
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 0)
	add_child(main_hbox)
	
	# === ЛЕВАЯ ПАНЕЛЬ ===
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 360
	left_panel.add_theme_constant_override("separation", 0)
	main_hbox.add_child(left_panel)
	
	var left_bg = ColorRect.new()
	left_bg.color = COLOR_SIDEBAR
	left_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_panel.add_child(left_bg)
	left_bg.show_behind_parent = true
	
	# Шапка левой панели
	var left_header = VBoxContainer.new()
	left_header.add_theme_constant_override("separation", 8)
	left_header.add_theme_constant_override("margin_left", 12)
	left_header.add_theme_constant_override("margin_right", 12)
	left_header.add_theme_constant_override("margin_top", 12)
	left_header.add_theme_constant_override("margin_bottom", 8)
	left_panel.add_child(left_header)
	
	var title_hbox = HBoxContainer.new()
	left_header.add_child(title_hbox)
	
	var title = Label.new()
	title.text = "Мессенджер"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title)
	
	var settings_btn = _make_icon_button("☰", 20)
	title_hbox.add_child(settings_btn)
	
	# Поиск
	search_input = LineEdit.new()
	search_input.placeholder_text = "Поиск"
	search_input.add_theme_color_override("font_color", COLOR_TEXT)
	search_input.add_theme_color_override("font_placeholder_color", COLOR_TEXT_SECONDARY)
	var search_style = StyleBoxFlat.new()
	search_style.bg_color = COLOR_INPUT
	search_style.corner_radius_top_left = 18
	search_style.corner_radius_top_right = 18
	search_style.corner_radius_bottom_left = 18
	search_style.corner_radius_bottom_right = 18
	search_style.content_margin_left = 14
	search_style.content_margin_right = 14
	search_style.content_margin_top = 8
	search_style.content_margin_bottom = 8
	search_input.add_theme_stylebox_override("normal", search_style)
	search_input.add_theme_stylebox_override("focus", search_style)
	left_header.add_child(search_input)
	search_input.text_changed.connect(_on_search_changed)
	
	# Сеть - Host/Join
	var net_hbox = HBoxContainer.new()
	net_hbox.add_theme_constant_override("separation", 6)
	left_header.add_child(net_hbox)
	
	ip_input = LineEdit.new()
	ip_input.placeholder_text = "127.0.0.1"
	ip_input.text = "127.0.0.1"
	ip_input.custom_minimum_size.x = 120
	ip_input.add_theme_color_override("font_color", COLOR_TEXT)
	var ip_style = StyleBoxFlat.new()
	ip_style.bg_color = COLOR_INPUT
	ip_style.corner_radius_top_left = 8
	ip_style.corner_radius_top_right = 8
	ip_style.corner_radius_bottom_left = 8
	ip_style.corner_radius_bottom_right = 8
	ip_style.content_margin_left = 8
	ip_style.content_margin_right = 8
	ip_style.content_margin_top = 6
	ip_style.content_margin_bottom = 6
	ip_input.add_theme_stylebox_override("normal", ip_style)
	ip_input.add_theme_stylebox_override("focus", ip_style)
	net_hbox.add_child(ip_input)
	
	var host_btn = _make_small_button("Host")
	host_btn.pressed.connect(_on_host_pressed)
	net_hbox.add_child(host_btn)
	
	var join_btn = _make_small_button("Join")
	join_btn.pressed.connect(_on_join_pressed)
	net_hbox.add_child(join_btn)
	
	var stop_btn = _make_small_button("✕")
	stop_btn.pressed.connect(func(): NetworkManager.stop_network())
	net_hbox.add_child(stop_btn)
	
	network_status_label = Label.new()
	network_status_label.text = "● Offline - локальный режим"
	network_status_label.add_theme_font_size_override("font_size", 12)
	network_status_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	left_header.add_child(network_status_label)
	
	# Список чатов
	var chat_scroll = ScrollContainer.new()
	chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(chat_scroll)
	
	chat_list_vbox = VBoxContainer.new()
	chat_list_vbox.add_theme_constant_override("separation", 0)
	chat_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_scroll.add_child(chat_list_vbox)
	
	# Низ левой панели - профиль
	var bottom_profile = HBoxContainer.new()
	bottom_profile.add_theme_constant_override("separation", 10)
	bottom_profile.custom_minimum_size.y = 54
	var bottom_style = StyleBoxFlat.new()
	bottom_style.bg_color = Color("#1b2734")
	bottom_style.content_margin_left = 12
	bottom_style.content_margin_right = 12
	bottom_style.content_margin_top = 8
	bottom_style.content_margin_bottom = 8
	var bottom_panel = PanelContainer.new()
	bottom_panel.add_theme_stylebox_override("panel", bottom_style)
	bottom_panel.add_child(bottom_profile)
	left_panel.add_child(bottom_panel)
	
	var my_avatar = _make_avatar("В", Color("#2b88d8"), 36)
	bottom_profile.add_child(my_avatar)
	
	var my_info = VBoxContainer.new()
	my_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_profile.add_child(my_info)
	
	var my_name_edit = LineEdit.new()
	my_name_edit.text = ChatManager.my_name
	my_name_edit.placeholder_text = "Ваше имя"
	my_name_edit.add_theme_color_override("font_color", COLOR_TEXT)
	my_name_edit.add_theme_font_size_override("font_size", 14)
	var trans_style = StyleBoxFlat.new()
	trans_style.bg_color = Color.TRANSPARENT
	my_name_edit.add_theme_stylebox_override("normal", trans_style)
	my_name_edit.add_theme_stylebox_override("focus", trans_style)
	my_name_edit.text_submitted.connect(func(t): ChatManager.my_name = t)
	my_info.add_child(my_name_edit)
	
	var my_status = Label.new()
	my_status.text = "в сети"
	my_status.add_theme_font_size_override("font_size", 12)
	my_status.add_theme_color_override("font_color", Color("#4fc3f7"))
	my_info.add_child(my_status)
	
	# === ПРАВАЯ ПАНЕЛЬ ===
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_constant_override("separation", 0)
	main_hbox.add_child(right_panel)
	
	# Топ-бар чата
	var top_bar = HBoxContainer.new()
	top_bar.custom_minimum_size.y = 56
	var top_style = StyleBoxFlat.new()
	top_style.bg_color = COLOR_SIDEBAR
	top_style.content_margin_left = 16
	top_style.content_margin_right = 16
	top_style.content_margin_top = 8
	top_style.content_margin_bottom = 8
	var top_panel = PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel", top_style)
	top_panel.add_child(top_bar)
	right_panel.add_child(top_panel)
	
	top_avatar = _make_avatar("?", Color.GRAY, 40)
	top_bar.add_child(top_avatar)
	top_avatar_label = top_avatar.get_child(0) as Label
	
	var top_info = VBoxContainer.new()
	top_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_info.add_theme_constant_override("separation", 0)
	top_bar.add_child(top_info)
	
	top_name_label = Label.new()
	top_name_label.text = "Выберите чат"
	top_name_label.add_theme_font_size_override("font_size", 15)
	top_name_label.add_theme_color_override("font_color", COLOR_TEXT)
	top_info.add_child(top_name_label)
	
	top_status_label = Label.new()
	top_status_label.text = ""
	top_status_label.add_theme_font_size_override("font_size", 12)
	top_status_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	top_info.add_child(top_status_label)
	
	var call_btn = _make_icon_button("📞", 18)
	top_bar.add_child(call_btn)
	var video_btn = _make_icon_button("📹", 18)
	top_bar.add_child(video_btn)
	var more_btn = _make_icon_button("⋯", 20)
	top_bar.add_child(more_btn)
	
	# Сообщения
	message_scroll = ScrollContainer.new()
	message_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(message_scroll)
	
	# Фон чата с паттерном (просто цвет)
	var msg_bg = ColorRect.new()
	msg_bg.color = COLOR_BG
	msg_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	msg_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_scroll.add_child(msg_bg)
	msg_bg.show_behind_parent = true
	
	message_list_vbox = VBoxContainer.new()
	message_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_list_vbox.add_theme_constant_override("separation", 4)
	message_list_vbox.add_theme_constant_override("margin_left", 16)
	message_list_vbox.add_theme_constant_override("margin_right", 16)
	message_list_vbox.add_theme_constant_override("margin_top", 12)
	message_list_vbox.add_theme_constant_override("margin_bottom", 12)
	message_scroll.add_child(message_list_vbox)
	
	# Индикатор набора
	typing_label = Label.new()
	typing_label.text = ""
	typing_label.add_theme_font_size_override("font_size", 12)
	typing_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	typing_label.add_theme_constant_override("margin_left", 20)
	typing_label.visible = false
	right_panel.add_child(typing_label)
	
	# Поле ввода
	var input_bar = HBoxContainer.new()
	input_bar.custom_minimum_size.y = 52
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = COLOR_SIDEBAR
	input_style.content_margin_left = 12
	input_style.content_margin_right = 12
	input_style.content_margin_top = 8
	input_style.content_margin_bottom = 8
	var input_panel = PanelContainer.new()
	input_panel.add_theme_stylebox_override("panel", input_style)
	input_panel.add_child(input_bar)
	right_panel.add_child(input_panel)
	
	var attach_btn = _make_icon_button("📎", 20)
	input_bar.add_child(attach_btn)
	
	message_input = LineEdit.new()
	message_input.placeholder_text = "Написать сообщение..."
	message_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_input.add_theme_color_override("font_color", COLOR_TEXT)
	message_input.add_theme_color_override("font_placeholder_color", COLOR_TEXT_SECONDARY)
	var input_field_style = StyleBoxFlat.new()
	input_field_style.bg_color = COLOR_INPUT
	input_field_style.corner_radius_top_left = 20
	input_field_style.corner_radius_top_right = 20
	input_field_style.corner_radius_bottom_left = 20
	input_field_style.corner_radius_bottom_right = 20
	input_field_style.content_margin_left = 16
	input_field_style.content_margin_right = 16
	input_field_style.content_margin_top = 10
	input_field_style.content_margin_bottom = 10
	message_input.add_theme_stylebox_override("normal", input_field_style)
	message_input.add_theme_stylebox_override("focus", input_field_style)
	message_input.text_submitted.connect(_on_message_submitted)
	input_bar.add_child(message_input)
	
	var emoji_btn = _make_icon_button("😊", 20)
	emoji_btn.pressed.connect(_on_emoji_pressed)
	input_bar.add_child(emoji_btn)
	
	var send_btn = Button.new()
	send_btn.text = "➤"
	send_btn.custom_minimum_size = Vector2(44, 44)
	var send_style = StyleBoxFlat.new()
	send_style.bg_color = COLOR_ACCENT
	send_style.corner_radius_top_left = 22
	send_style.corner_radius_top_right = 22
	send_style.corner_radius_bottom_left = 22
	send_style.corner_radius_bottom_right = 22
	send_btn.add_theme_stylebox_override("normal", send_style)
	send_btn.add_theme_stylebox_override("hover", send_style)
	send_btn.add_theme_color_override("font_color", Color.WHITE)
	send_btn.pressed.connect(_on_send_pressed)
	input_bar.add_child(send_btn)

func _make_avatar(letter: String, color: Color, size: int) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(size, size)
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = size/2
	style.corner_radius_top_right = size/2
	style.corner_radius_bottom_left = size/2
	style.corner_radius_bottom_right = size/2
	panel.add_theme_stylebox_override("panel", style)
	
	var lbl = Label.new()
	lbl.text = letter
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", int(size * 0.45))
	panel.add_child(lbl)
	return panel

func _make_icon_button(icon: String, font_size: int) -> Button:
	var btn = Button.new()
	btn.text = icon
	btn.custom_minimum_size = Vector2(36, 36)
	btn.flat = true
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	return btn

func _make_small_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#242f3d")
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = Color("#2b5278")
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_font_size_override("font_size", 12)
	return btn

func _refresh_chat_list():
	# Очистка
	for child in chat_list_vbox.get_children():
		child.queue_free()
	chat_item_nodes.clear()
	
	var filter_text = search_input.text.to_lower() if search_input else ""
	
	for chat in ChatManager.get_chat_list():
		if filter_text != "" and not filter_text in chat.name.to_lower():
			continue
		
		var item = _create_chat_item(chat)
		chat_list_vbox.add_child(item)
		chat_item_nodes[chat.id] = item

func _create_chat_item(chat: Dictionary) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size.y = 72
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = COLOR_SIDEBAR_HOVER
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_style = hover.duplicate()
	pressed_style.bg_color = Color("#2b5278")
	btn.add_theme_stylebox_override("pressed", pressed_style)
	if chat.id == ChatManager.current_chat_id:
		btn.add_theme_stylebox_override("normal", pressed_style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("margin_left", 10)
	hbox.add_theme_constant_override("margin_right", 10)
	hbox.add_theme_constant_override("margin_top", 6)
	hbox.add_theme_constant_override("margin_bottom", 6)
	btn.add_child(hbox)
	
	var avatar = _make_avatar(chat.avatar, chat.color, 52)
	hbox.add_child(avatar)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)
	
	var top_hbox = HBoxContainer.new()
	vbox.add_child(top_hbox)
	
	var name_lbl = Label.new()
	name_lbl.text = chat.name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_hbox.add_child(name_lbl)
	
	var time_lbl = Label.new()
	time_lbl.text = ChatManager.format_time(chat.messages[-1].time) if not chat.messages.is_empty() else ""
	time_lbl.add_theme_font_size_override("font_size", 11)
	time_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	top_hbox.add_child(time_lbl)
	
	var bottom_hbox = HBoxContainer.new()
	vbox.add_child(bottom_hbox)
	
	var last_lbl = Label.new()
	last_lbl.text = ChatManager.get_last_message_text(chat)
	last_lbl.add_theme_font_size_override("font_size", 13)
	last_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	last_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	last_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	last_lbl.max_lines_visible = 1
	bottom_hbox.add_child(last_lbl)
	
	if chat.unread > 0:
		var unread_panel = Panel.new()
		unread_panel.custom_minimum_size = Vector2(22, 22)
		var unread_style = StyleBoxFlat.new()
		unread_style.bg_color = COLOR_ACCENT
		unread_style.corner_radius_top_left = 11
		unread_style.corner_radius_top_right = 11
		unread_style.corner_radius_bottom_left = 11
		unread_style.corner_radius_bottom_right = 11
		unread_panel.add_theme_stylebox_override("panel", unread_style)
		var unread_lbl = Label.new()
		unread_lbl.text = str(chat.unread) if chat.unread < 100 else "99+"
		unread_lbl.add_theme_font_size_override("font_size", 11)
		unread_lbl.add_theme_color_override("font_color", Color.WHITE)
		unread_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unread_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unread_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		unread_panel.add_child(unread_lbl)
		bottom_hbox.add_child(unread_panel)
	
	btn.pressed.connect(func(): ChatManager.set_current_chat(chat.id))
	return btn

func _show_chat(chat_id: String):
	var chat = ChatManager.chats.get(chat_id, {})
	if chat.is_empty():
		return
	
	top_name_label.text = chat.name
	top_avatar_label.text = chat.avatar
	var avatar_style = top_avatar.get_theme_stylebox("panel") as StyleBoxFlat
	if avatar_style:
		avatar_style.bg_color = chat.color
	
	if chat.is_group:
		top_status_label.text = "%d участников, %d онлайн" % [chat.members.size(), 2 if chat.online else 0]
	else:
		top_status_label.text = "в сети" if chat.online else "был(а) недавно"
	
	# Очистка сообщений
	for child in message_list_vbox.get_children():
		child.queue_free()
	
	# Добавляем сообщения
	for msg in chat.messages:
		_add_message_bubble(msg)
	
	_refresh_chat_list()
	
	# Скролл вниз
	await get_tree().process_frame
	_scroll_to_bottom()

func _add_message_bubble(msg: Dictionary):
	var outer = HBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 8)
	
	var is_me = msg.is_me
	
	# Для выравнивания
	if is_me:
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.custom_minimum_size.x = 80
		outer.add_child(spacer)
	
	var bubble_container = VBoxContainer.new()
	bubble_container.size_flags_horizontal = Control.SIZE_SHRINK_END if is_me else Control.SIZE_SHRINK_BEGIN
	bubble_container.custom_minimum_size.x = 60
	bubble_container.add_theme_constant_override("separation", 2)
	outer.add_child(bubble_container)
	
	# Имя отправителя для групп
	if not is_me and ChatManager.get_current_chat().is_group:
		var sender_lbl = Label.new()
		sender_lbl.text = msg.sender
		sender_lbl.add_theme_font_size_override("font_size", 12)
		sender_lbl.add_theme_color_override("font_color", Color("#4fc3f7"))
		bubble_container.add_child(sender_lbl)
	
	var bubble = PanelContainer.new()
	var bubble_style = StyleBoxFlat.new()
	bubble_style.bg_color = COLOR_BUBBLE_ME if is_me else COLOR_BUBBLE_OTHER
	bubble_style.corner_radius_top_left = 12
	bubble_style.corner_radius_top_right = 12
	bubble_style.corner_radius_bottom_left = 12 if is_me else 2
	bubble_style.corner_radius_bottom_right = 2 if is_me else 12
	bubble_style.content_margin_left = 12
	bubble_style.content_margin_right = 12
	bubble_style.content_margin_top = 8
	bubble_style.content_margin_bottom = 8
	bubble.add_theme_stylebox_override("panel", bubble_style)
	bubble_container.add_child(bubble)
	
	var text_lbl = Label.new()
	text_lbl.text = msg.text
	text_lbl.add_theme_font_size_override("font_size", 14)
	text_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.custom_minimum_size.x = 10
	text_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# Ограничим ширину пузыря
	text_lbl.custom_minimum_size.x = 0
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.add_child(text_lbl)
	# Ограничение ширины через контейнер
	bubble.custom_minimum_size.x = 0
	bubble_container.custom_minimum_size.x = 200
	if bubble_container.custom_minimum_size.x > 400:
		bubble_container.custom_minimum_size.x = 400
	
	var meta_hbox = HBoxContainer.new()
	meta_hbox.alignment = BoxContainer.ALIGNMENT_END
	meta_hbox.add_theme_constant_override("separation", 4)
	bubble_container.add_child(meta_hbox)
	
	var time_lbl = Label.new()
	time_lbl.text = Time.get_time_string_from_unix_time(msg.time).substr(0,5)
	time_lbl.add_theme_font_size_override("font_size", 11)
	time_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	meta_hbox.add_child(time_lbl)
	
	if is_me:
		var status_lbl = Label.new()
		status_lbl.text = "✓✓" if msg.status == "read" else "✓"
		status_lbl.add_theme_font_size_override("font_size", 11)
		status_lbl.add_theme_color_override("font_color", Color("#4fc3f7") if msg.status == "read" else COLOR_TEXT_SECONDARY)
		meta_hbox.add_child(status_lbl)
	
	if not is_me:
		var spacer2 = Control.new()
		spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer2.custom_minimum_size.x = 80
		outer.add_child(spacer2)
	
	message_list_vbox.add_child(outer)

func _scroll_to_bottom():
	await get_tree().process_frame
	if message_scroll:
		message_scroll.scroll_vertical = int(message_scroll.get_v_scroll_bar().max_value)

func _on_message_submitted(text: String):
	_send_current_message()

func _on_send_pressed():
	_send_current_message()

func _send_current_message():
	var text = message_input.text.strip_edges()
	if text == "":
		return
	if ChatManager.current_chat_id == "":
		return
	message_input.text = ""
	ChatManager.send_message(ChatManager.current_chat_id, text, true)
	_show_chat(ChatManager.current_chat_id)

func _on_chat_updated(chat_id: String):
	if chat_id == ChatManager.current_chat_id:
		_show_chat(chat_id)

func _on_message_received(chat_id: String, _msg: Dictionary):
	if chat_id != ChatManager.current_chat_id:
		# Увеличиваем счетчик непрочитанных
		if ChatManager.chats.has(chat_id):
			ChatManager.chats[chat_id].unread += 1
			_refresh_chat_list()

func _on_search_changed(text: String):
	_refresh_chat_list()

func _on_emoji_pressed():
	var emojis = ["😊", "😂", "❤️", "🔥", "👍", "🎉", "🚀", "👏"]
	message_input.text += emojis[randi() % emojis.size()]

# Сеть
func _on_host_pressed():
	var port = 7000
	var ok = NetworkManager.host_server(port, ChatManager.my_name)
	if ok:
		network_status_label.text = "● Сервер на порту %d - ждем подключений" % port
		network_status_label.add_theme_color_override("font_color", Color("#4caf50"))

func _on_join_pressed():
	var ip = ip_input.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	var ok = NetworkManager.join_server(ip, 7000, ChatManager.my_name)
	if ok:
		network_status_label.text = "● Подключаемся к %s..." % ip
		network_status_label.add_theme_color_override("font_color", Color("#ff9800"))

func _on_server_started(port: int):
	network_status_label.text = "● Хост %d - %d пиров" % [port, NetworkManager.peers_info.size()]
	network_status_label.add_theme_color_override("font_color", Color("#4caf50"))

func _on_connected():
	network_status_label.text = "● Подключен к серверу"
	network_status_label.add_theme_color_override("font_color", Color("#4caf50"))

func _on_disconnected():
	network_status_label.text = "● Offline"
	network_status_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

func _on_peer_joined(id: int, name: String):
	network_status_label.text = "● %d пиров онлайн" % NetworkManager.peers_info.size()
	# Добавляем системное сообщение
	if ChatManager.current_chat_id != "":
		ChatManager.send_message(ChatManager.current_chat_id, "%s подключился к чату" % name, false, "Система")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			# Очистка поиска
			if search_input.has_focus():
				search_input.text = ""
				_refresh_chat_list()
