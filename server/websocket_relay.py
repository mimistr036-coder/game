#!/usr/bin/env python3
"""
Простой WebSocket сервер-ретранслятор для Godot Messenger
Запуск: python3 server/websocket_relay.py
Клиенты Godot подключаются через WebSocketPeer к ws://localhost:7001

Протокол: JSON {"chat_id": "general", "sender": "Имя", "text": "привет"}
Сервер рассылает всем кроме отправителя.
"""
import asyncio
import json
try:
    import websockets
except ImportError:
    print("Установи: pip install websockets")
    exit(1)

clients = set()

async def handle(websocket):
    print(f"Клиент подключился: {websocket.remote_address}")
    clients.add(websocket)
    try:
        async for message in websocket:
            print(f"Получено: {message}")
            try:
                data = json.loads(message)
                # Валидация
                if not all(k in data for k in ("chat_id", "sender", "text")):
                    continue
                # Рассылаем всем
                disconnected = set()
                for client in clients:
                    if client != websocket:
                        try:
                            await client.send(message)
                        except:
                            disconnected.add(client)
                for d in disconnected:
                    clients.discard(d)
            except json.JSONDecodeError:
                print("Не JSON")
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        clients.discard(websocket)
        print(f"Клиент отключился: {websocket.remote_address}")

async def main():
    print("WebSocket Relay запущен на ws://0.0.0.0:7001")
    print("Подключай Godot клиентов через WebSocketPeer")
    async with websockets.serve(handle, "0.0.0.0", 7001):
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
