// Move object type
export interface Move {
  attackName: string;
  attackPower: number;
  agility: number;
}

// Ongoing battle type
export interface BattleState {
  battleId: string | null; // Unique UUID for the battle
  player1Address: string | null;
  player2Address: string | null;

  pokemon1Id: number | null;
  pokemon2Id: number | null;

  pokemon1Name: string | null;
  pokemon2Name: string | null;

  pokemon1HP: number | null;
  pokemon2HP: number | null;

  pokemon1Moves: Move[] | null;
  pokemon2Moves: Move[] | null;

  currentTurn: number | 0; //Keeps track of turn number
  winner?: string; // Optional, filled when battle ends (address)
  loser?: string; // Optional, filled when battle ends (address)
  isActive: boolean; // True while battle is ongoing
}
