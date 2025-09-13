"use strict";
// import express from "express";
// import http from "http";
// import { Server } from "socket.io";
// import { v4 as uuidv4 } from "uuid";
// import { ethers } from "ethers";
// const app = express();
// const server = http.createServer(app);
// const io = new Server(server, { cors: { origin: "*" } });
// const activeBattles: Record<string, string[]> = {};
// // const provider = new ethers.providers.JsonRpcProvider("https://YOUR_RPC_URL");
// const signer = new ethers.Wallet("YOUR_PRIVATE_KEY", provider);
// const contractAddress = "YOUR_CONTRACT_ADDRESS";
// const contractABI = [
//   "function startGame(string battleId, address playerA, address playerB) public",
// ];
// const gameContract = new ethers.Contract(contractAddress, contractABI, signer);
// io.on("connection", (socket) => {
//   socket.on("createBattle", async (playerAddress: string) => {
//     const battleId = uuidv4();
//     activeBattles[battleId] = [socket.id];
//     socket.join(battleId);
//     socket.emit("battleCreated", battleId);
//     (socket as any).playerAddress = playerAddress;
//   });
//   socket.on("joinBattle", async (battleId: string, playerAddress: string) => {
//     if (activeBattles[battleId] && activeBattles[battleId].length < 2) {
//       activeBattles[battleId].push(socket.id);
//       socket.join(battleId);
//       (socket as any).playerAddress = playerAddress;
//       io.to(battleId).emit("battleReady", { players: activeBattles[battleId] });
//       const socketsInRoom = await io.in(battleId).fetchSockets();
//       const addresses = socketsInRoom.map((s) => (s as any).playerAddress);
//       try {
//         const tx = await gameContract.startGame(
//           battleId,
//           addresses[0],
//           addresses[1],
//         );
//         await tx.wait();
//         io.to(battleId).emit("gameStarted", { txHash: tx.hash });
//       } catch (error) {
//         console.error("call failed:", error);
//         io.to(battleId).emit("error", "Failed to start game");
//       }
//     } else {
//       socket.emit("joinError", "Battle not found or full");
//     }
//   });
//   socket.on("disconnect", () => {
//     for (const [battleId, players] of Object.entries(activeBattles)) {
//       if (players.includes(socket.id)) {
//         activeBattles[battleId] = players.filter((id) => id !== socket.id);
//         io.to(battleId).emit("playerLeft", socket.id);
//         if (activeBattles[battleId].length === 0)
//           delete activeBattles[battleId];
//       }
//     }
//   });
// });
// server.listen(3001, () => {
//   console.log("Server listening on http://localhost:3001");
// });
