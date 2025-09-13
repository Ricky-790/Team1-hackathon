"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
// src/server.ts
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const http_1 = require("http");
const socket_io_1 = require("socket.io");
const uuid_1 = require("uuid");
const app = (0, express_1.default)();
app.use((0, cors_1.default)());
const httpServer = (0, http_1.createServer)(app);
const io = new socket_io_1.Server(httpServer, {
    cors: { origin: "*" },
});
// --- REST route: Create a new battle ---
app.get("/battle/create", (req, res) => {
    const battleId = (0, uuid_1.v4)(); // unique battle room
    console.log(battleId);
    res.json({ battleId });
});
// --- Socket.io: Manage battle rooms ---
io.on("connection", (socket) => {
    console.log("Player connected:", socket.id);
    socket.on("joinGame", ({ battleId: battleId }) => {
        socket.join("game-" + battleId);
        console.log(`Socket ${socket.id} joined room game-${battleId}`);
    });
    socket.on("join-battle-room", (battleId) => {
        socket.join(battleId);
        console.log(`Player ${socket.id} joined battle room ${battleId}`);
        // notify all players in the room
        io.to(battleId).emit("player-joined", { playerId: socket.id });
    });
    socket.on("disconnect", () => {
        console.log("Player disconnected:", socket.id);
    });
});
httpServer.listen(3000, () => {
    console.log("Running on http://localhost:3000");
});
