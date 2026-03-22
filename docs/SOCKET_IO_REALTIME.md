# Socket.IO realtime (LuhaRide)

## Why Socket.IO (not raw WebSocket)?

The backend already used **Socket.IO** on Node. It gives:

- Automatic **reconnection** and transport fallback
- **Rooms** (`trip:{id}`, `user:{id}`) for targeted broadcasts
- Compatible **Flutter** client (`socket_io_client`)

Raw WebSockets would duplicate protocol work and not match the server.

## Server

- **Monolith:** `server.js` attaches Socket.IO to the same HTTP port as REST.
- **Microservices:** **`gateway/server.js`** owns `/socket.io` — point Flutter `SOCKET_URL` at the gateway (same host/port as API base, **without** `/api`).

## Auth

Clients send the JWT in the handshake:

```text
auth: { token: "<access_token>" }
```

The server verifies it and joins the socket to room `user:{userId}` for **`notification:new`**.

## Events

| Direction | Event | Purpose |
|-----------|--------|---------|
| Client → server | `join-trip` / `leave-trip` | Subscribe to trip room `trip:{id}` |
| Client → server | `location-update` | Driver GPS → broadcast as `driver-location` to trip room |
| Server → client | `trip-updated` | Booking/seat change — **trip details** & **seat selection** refresh |
| Server → client | `notification:new` | New DB notification row for this user |
| Server → client | `driver-location` | Live map for passengers |

## Flutter

- `lib/services/realtime_socket_service.dart` — singleton; connects after login / restored session.
- `EnvConfig.socketUrl` — e.g. `http://host:3000` (must match API host; path is only for REST `/api`).

## Operations

- If Socket.IO fails in production, check **firewall**, **HTTPS/WSS** (use `wss://` when API is HTTPS), and **same host** as API.
