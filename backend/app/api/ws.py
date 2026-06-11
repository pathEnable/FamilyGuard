import json
from typing import Dict, List
from jose import jwt, JWTError
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, status
from app.core.config import settings

router = APIRouter()

class ConnectionManager:
    def __init__(self):
        # parent_id -> list of WebSockets
        self.active_connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, parent_id: int):
        await websocket.accept()
        if parent_id not in self.active_connections:
            self.active_connections[parent_id] = []
        self.active_connections[parent_id].append(websocket)

    def disconnect(self, websocket: WebSocket, parent_id: int):
        if parent_id in self.active_connections:
            if websocket in self.active_connections[parent_id]:
                self.active_connections[parent_id].remove(websocket)
            if not self.active_connections[parent_id]:
                del self.active_connections[parent_id]

    async def send_personal_message(self, message: dict, websocket: WebSocket):
        await websocket.send_text(json.dumps(message))

    async def broadcast_to_parent(self, parent_id: int, message: dict):
        if parent_id in self.active_connections:
            dead_sockets = []
            for connection in self.active_connections[parent_id]:
                try:
                    await connection.send_text(json.dumps(message))
                except Exception:
                    dead_sockets.append(connection)
            
            for dead in dead_sockets:
                self.disconnect(dead, parent_id)

manager = ConnectionManager()

@router.websocket("/{parent_id}")
async def websocket_endpoint(websocket: WebSocket, parent_id: int, token: str = Query(...)):
    # Validate token
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None or int(user_id) != parent_id:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return
    except JWTError:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await manager.connect(websocket, parent_id)
    try:
        while True:
            # We don't expect messages from client, just keep connection alive
            data = await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket, parent_id)
