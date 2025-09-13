// src/server.ts
import express from "express";
import cors from "cors";
import { createServer } from "http";
import { Server } from "socket.io";
import { v4 as uuidv4 } from "uuid";

const app = express();
app.use(cors());
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: { origin: "*" },
});
// --- REST route: Create a new battle ---
app.get("/battle/create", (req, res) => {
  const battleId = uuidv4(); // unique battle room
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

  socket.on("join-battle-room", (battleId: string) => {
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
