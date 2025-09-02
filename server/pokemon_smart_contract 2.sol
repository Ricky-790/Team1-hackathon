// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PokemonGame is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct Move {
        string name;
        uint32 attackPower;
        uint32 agility;
    }

    struct Pokemon {
        uint32 hp;
        string name;
        Move[2] moves; // Fixed-size array for gas efficiency
        address owner;
        uint256 wins;
        uint256 losses;
        uint256 createdAt;
    }

    struct Battle {
        address Player1;
        address Player2;
        uint256 pokemon1Id;
        uint256 pokemon2Id;
        address winner_owner;
        uint256 winner_mon;
        uint256 timestamp;
    }

    // Mappings
    mapping(uint256 => Pokemon) public pokemon;
    mapping(address => uint256[]) public ownerToPokemon;
    mapping(uint256 => bool) public pokemonExists;

    // Battle tracking
    Battle[] public battles;
    uint256 public battleCount;

    // Game economics
    uint256 public creationFee = 0.01 ether;
    uint256 public battleReward = 0.005 ether;

    // Events
    event PokemonCreated(uint256 indexed tokenId, string name, address indexed owner);
    event BattleCompleted(uint256 indexed attackerId, uint256 indexed defenderId, bool attackerWon);
    event RewardClaimed(address indexed player, uint256 amount);

    constructor()
        ERC721("Pokemon Game", "POKEMON")
        Ownable(msg.sender)
        ReentrancyGuard()
    {}

    function createPokemon(
        string memory _name,
        string memory _move1,
        uint32 _move1atk,
        uint32 _move1agi,
        string memory _move2,
        uint32 _move2atk,
        uint32 _move2agi
    ) external payable nonReentrant returns (uint256) {
        require(msg.value >= creationFee, "Insufficient creation fee");
        require(bytes(_name).length > 0 && bytes(_name).length <= 20, "Invalid name length");

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);

        pokemon[newTokenId] = Pokemon({
            name: _name,
            hp: 20,
            owner: msg.sender,
            wins: 0,
            losses: 0,
            createdAt: block.timestamp,
            moves: [
                Move(_move1, _move1atk, _move1agi),
                Move(_move2, _move2atk, _move2agi)
            ]
        });

        ownerToPokemon[msg.sender].push(newTokenId);
        pokemonExists[newTokenId] = true;
        emit PokemonCreated(newTokenId, _name, msg.sender);

        return newTokenId;
    }

    function battle(
    uint256 pokemon1Id,
    uint256 pokemon2Id,
    uint8 player1MoveIndex, // 0 or 1
    uint8 player2MoveIndex  // 0 or 1
)
    external
    nonReentrant
    returns (string memory)
{
    require(pokemonExists[pokemon1Id], "Pokemon1 doesn't exist");
    require(pokemonExists[pokemon2Id], "Pokemon2 doesn't exist");
    require(player1MoveIndex < 2, "Invalid move index");
    require(player2MoveIndex < 2, "Invalid move index");
    require(address(this).balance >= battleReward, "Insufficient contract balance");

    Pokemon storage p1 = pokemon[pokemon1Id];
    Pokemon storage p2 = pokemon[pokemon2Id];

    // Store original move indices for later use
    uint8 originalP1Move = player1MoveIndex;
    uint8 originalP2Move = player2MoveIndex;

    // Check if either player is defending
    bool p1Defending = keccak256(bytes(p1.moves[player1MoveIndex].name)) == keccak256(bytes("defend"));
    bool p2Defending = keccak256(bytes(p2.moves[player2MoveIndex].name)) == keccak256(bytes("defend"));

    if (p1Defending && p2Defending) {
        return "both defended";
    } else if (p1Defending) {
        return "player1 defended";
    } else if (p2Defending) {
        return "player2 defended";
    }

    // Determine attacker (higher agility moves first)
    Pokemon storage attacker;
    Pokemon storage defender;
    uint32 attackPower;

    if (p1.moves[player1MoveIndex].agility >= p2.moves[player2MoveIndex].agility) {
        attacker = p1;
        defender = p2;
        attackPower = p1.moves[player1MoveIndex].attackPower;
    } else {
        attacker = p2;
        defender = p1;
        attackPower = p2.moves[player2MoveIndex].attackPower;
    }

    // First attack round
    string memory result = calculateBattlePower(attacker, defender, attackPower);

    if (keccak256(bytes(result)) == keccak256(bytes("continue"))) {
        // Swap attacker/defender for second round
        (attacker, defender) = (defender, attacker);

        // Use original move indices to get the correct attackPower
        attackPower = (attacker.owner == p1.owner)
            ? p1.moves[originalP1Move].attackPower
            : p2.moves[originalP2Move].attackPower;

        result = calculateBattlePower(attacker, defender, attackPower);
    }

    if (keccak256(bytes(result)) == keccak256(bytes("attacker won"))) {
        attacker.wins++;
        defender.losses++;
        battleCount++;

        // Distribute reward to the winner
        // payable(attacker.owner).transfer(battleReward);

        battles.push(Battle({
            Player1: p1.owner,
            Player2: p2.owner,
            pokemon1Id: pokemon1Id,
            pokemon2Id: pokemon2Id,
            winner_owner: attacker.owner,
            winner_mon: (attacker.owner == p1.owner) ? pokemon1Id : pokemon2Id,
            timestamp: block.timestamp
        }));

        emit BattleCompleted(pokemon1Id, pokemon2Id, attacker.owner == p1.owner);
        return string.concat("winner is ", attacker.name);  // ✅ Safe string concatenation
    }

    return "continue";
}

    function calculateBattlePower(
        Pokemon storage attacker,
        Pokemon storage defender,
        uint32 attackPower
    ) internal returns (string memory) {
        defender.hp -= attackPower;
        if (defender.hp <= 0) {
            return "attacker won";
        }
        return "continue";
    }

    // ... (keep all other existing functions like getPokemon, getLeaderboard, etc.)
    // Note: You'll need to update getPokemon and getPokemonWithStats since we removed attack/defense/agility from Pokemon struct
}