# Godot Messenger - Мессенджер на Godot 4

Полноценный прототип мессенджера как в Telegram, сделанный на Godot.

## Можно ли сделать мессенджер на Godot? Да!

Godot - это не только про игры. Это мощный UI-фреймворк + сеть.

### Что умеет Godot для мессенджера:

**UI (лучше чем Electron):**
- Control ноды: VBox, HBox, ScrollContainer, Panel
- StyleBoxFlat для кастомных пузырьков, аватарок, скруглений
- Темы, анимации, всё как в мобильных приложениях
- Весит 30-50 МБ против 200+ МБ у Electron

**Сеть (всё из коробки):**
- `ENetMultiplayerPeer` - для LAN/P2P чата (сделано в проекте)
- `WebSocketPeer` - для интернет-чата через свой сервер
- `WebRTCPeerConnection` - для голосовых/видео звонков
- `HTTPRequest` - для REST API (Supabase, Firebase, свой бэкенд)
- `Crypto` - для E2E шифрования

### Архитектуры мессенджера на Godot:

#### 1. Локальный / Оффлайн (как в этом прототипе)
```
Godot Client <-> JSON сохранение
```
Подходит для: заметок, ботов, single-player чата

#### 2. LAN P2P (реализовано в проекте)
```
Godot (Host) <---ENet---> Godot (Client)
```
Один игрок жмет Host, другие Join по IP. Без сервера.

#### 3. Клиент-Сервер (для продакшена)
```
Godot Client --WebSocket--> Сервер (Go/Rust/Node/Godot headless) --DB--> PostgreSQL
                              |
Godot Client --WebSocket-->---+
```
- Сервер ретранслирует сообщения
- Хранит историю в БД
- Push-уведомления

Рекомендуемый стек:
- **Бэкенд:** Supabase (бесплатный, есть Realtime) или Firebase, или свой на Go + WebSocket
- **Клиент Godot:** WebSocketPeer подключается к Supabase Realtime
- **Файлы:** S3 / Supabase Storage через HTTPRequest

#### 4. Полный P2P с WebRTC
```
Godot --WebRTC--> Godot (без сервера, E2E шифрование)
```
Сигналинг через маленький WebSocket сервер, дальше напрямую.

### Что в этом проекте:

✅ UI как в Telegram:
- Список чатов слева с аватарками, последним сообщением, временем, счетчиком непрочитанных
- Пузырьки сообщений (свои/чужие, разного цвета)
- Поиск по чатам
- Статусы: в сети, время, галочки прочтения

✅ Логика:
- ChatManager - хранит чаты, сообщения, сохранение в user://chats.json
- Авто-ответчик бот
- Создание новых чатов

✅ Сеть:
- NetworkManager - Host/Join по LAN через ENet
- RPC для отправки сообщений
- Ретрансляция через сервер
- Заготовка под WebSocket для интернета

✅ Фишки:
- Смена имени
- Эмодзи
- Адаптивный UI
- Темная тема Telegram

### Как запустить:

1. Открыть проект в Godot 4.4+
2. Запустить Main.tscn (F5)
3. Для теста сети:
   - Запусти 2 окна Godot
   - В одном нажми Host
   - В другом введи 127.0.0.1 и нажми Join
   - Пишите сообщения - они летят по сети!

### Как расширить до реального мессенджера:

```gdscript
# 1. Подключи Supabase
var http = HTTPRequest.new()
http.request("https://xxx.supabase.co/rest/v1/messages", 
  ["apikey: ...", "Content-Type: application/json"], 
  HTTPClient.METHOD_POST, 
  JSON.stringify({"text": message, "user": my_name}))

# 2. WebSocket для Realtime
var ws = WebSocketPeer.new()
ws.connect_to_url("wss://xxx.supabase.co/realtime/v1/websocket?apikey=...")

# 3. Шифрование
var crypto = Crypto.new()
var key = CryptoKey.new()
# ... E2E

# 4. Файлы
var file = FileAccess.open("user://photo.jpg", FileAccess.READ)
http.request("https://s3.../upload", [], HTTPClient.METHOD_PUT, file.get_buffer(...))

# 5. Уведомления (Android/iOS)
OS.request_permission("POST_NOTIFICATIONS")
# + плагин
```

### Плюсы Godot vs Electron/Flutter для мессенджера:

| | Godot | Electron | Flutter |
|---|---|---|---|
| Размер | 30 МБ | 200 МБ | 20 МБ |
| Производительность UI | 60fps из коробки | Тормозит | 60fps |
| Сеть | ENet, WebRTC, WS | Только WS/HTTP | WS/HTTP |
| Кроссплатформа | Win/Mac/Linux/Android/iOS/Web | Win/Mac/Linux | Mobile/Web |
| Голос/Видео | WebRTC встроен | Нужен плагин | Плагин |
| 3D/Игры в чате | Да! | Нет | Нет |

**Вывод:** Godot идеален если хочешь:
- Легкий десктопный мессенджер
- Мессенджер с мини-играми / 3D аватарами
- Игровой чат (как Discord оверлей)
- Быстрый прототип за выходные

### Следующие шаги:

- [ ] Добавить Supabase Realtime
- [ ] Загрузка файлов/картинок
- [ ] Голосовые через WebRTC
- [ ] Push-уведомления
- [ ] Шифрование Crypto
- [ ] Экспорт на Android/iOS

Сделано с ❤️ на Godot 4
