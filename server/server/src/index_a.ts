import { io } from "socket.io-client";
const socket = io("ws://localhost:3001");

const playerAddress = "0xYourEthereumAddress";

function createBattle() {
  socket.emit("createBattle", playerAddress);
}

socket.on("battleCreated", (battleId: string) => {
  console.log("Battle created, ID:", battleId);
});

function joinBattle(battleId: string) {
  socket.emit("joinBattle", battleId, playerAddress);
}

socket.on("battleReady", ({ players }) => {
  console.log("Players connected:", players);
});

socket.on("gameStarted", ({ txHash }) => {
  console.log("Game started on-chain, txHash:", txHash);
});

socket.on("joinError", (msg: string) => {
  console.error(msg);
});
