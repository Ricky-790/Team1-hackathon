// src/server.ts
import express from "express";
import cors from "cors";
import { createServer } from "http";
import { Server } from "socket.io";
import { v4 as uuidv4 } from "uuid";
import { BattleState } from "./types";

const app = express();
app.use(cors());
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: { origin: "*" },
});

const battles: Map<String, BattleState> = new Map();

// --- REST route: Create a new battle ---
app.get("/battle/create", (req, res) => {
  const battleId = uuidv4(); // unique battle room
  console.log(battleId);
  battles.set(battleId, {
    battleId: battleId,
    isActive: true,
    currentTurn: 0,
    player1Address: null,
    player2Address: null,
    pokemon1Name: null,
    pokemon2Name: null,
    pokemon1Id: null,
    pokemon2Id: null,
    pokemon1HP: null,
    pokemon2HP: null,
    pokemon1Moves: null,
    pokemon2Moves: null,
  });
  res.json({ battleId });
});

app.get("/battle/:id/exists", (req, res) => {
  const battleId = req.params.id;

  if (battles.has(battleId)) {
    res.status(200);
    res.json({
      exists: true,
    });
  } else {
    res.status(404).json({
      exists: false,
      message: "Battle not found",
    });
  }
});

// --- Socket.io: Manage battle rooms ---
io.on("connection", (socket) => {
  console.log("Player connected:", socket.id);
  socket.on(
    "joinGame",
    ({
      battleId: battleId,
      playerAddress: playerAddress,
      name: name,
      pokemonId: pokemonId,
      hp: hp,
      moves: moves,
    }) => {
      if (
        battles.has(battleId) &&
        battles.get(battleId)?.player1Address != null &&
        battles.get(battleId)?.player2Address != null
      ) {
        socket.disconnect();
        return { error: "Battle already Full" };
      }
      socket.join("game-" + battleId);
      console.log("Player joined battle:", battleId);
      console.log("Player details:", playerAddress, name, pokemonId, hp, moves);
      // ✅ CORRECT - Check if battle DOESN'T exist (first player)
      if (
        battles.has(battleId) &&
        battles.get(battleId)?.player1Address == null
      ) {
        console.log("Adding Player1");
        // First player joining - create new battle with player1 details
        const newBattle: BattleState = {
          battleId: battleId,
          player1Address: playerAddress,
          player2Address: null, // Empty until second player joins
          pokemon1Id: pokemonId,
          pokemon2Id: null, // Default until second player joins
          pokemon1Name: name,
          pokemon2Name: null, // Empty until second player joins
          pokemon1HP: hp,
          pokemon2HP: null, // Default until second player joins
          pokemon1Moves: moves,
          pokemon2Moves: null, // Empty until second player joins
          currentTurn: 1,
          isActive: false, // Battle not active until both players join
        };

        battles.set(battleId, newBattle);
        console.log(`Player 1 (${playerAddress}) joined battle ${battleId}`);

        // Notify the player they're waiting for opponent
        socket.emit("waitingForOpponent", {
          battleId,
          playerNumber: 1,
          message: "Waiting for another player to join...",
        });
      } else {
        // Battle exists - this is the second player
        const battle = battles.get(battleId)!;

        // Check if battle is already full
        if (battle.player2Address != null) {
          socket.emit("battleFull", {
            battleId,
            message: "Battle room is already full",
          });
          return;
        }

        // Check if same player is trying to join twice
        if (
          battle.player1Address === playerAddress ||
          battle.player2Address === playerAddress
        ) {
          socket.emit("alreadyJoined", {
            battleId,
            message: "You are already in this battle",
          });
          return;
        }

        // Add second player details
        battle.player2Address = playerAddress;
        battle.pokemon2Id = pokemonId;
        battle.pokemon2Name = name;
        battle.pokemon2HP = hp;
        battle.pokemon2Moves = moves;
        battle.isActive = true;

        battles.set(battleId, battle);
        console.log(`Player 2 (${playerAddress}) joined battle ${battleId}`);

        // Notify both players that battle can start
        io.to("game-" + battleId).emit("battleReady", {
          battleId,
          battleState: battle,
          message: "Both players joined! Battle can begin!",
        });
      }
    },
  );

  socket.on("disconnect", () => {
    console.log("Player disconnected:", socket.id);
  });
});

httpServer.listen(3000, () => {
  console.log("Running on http://localhost:3000");
});
