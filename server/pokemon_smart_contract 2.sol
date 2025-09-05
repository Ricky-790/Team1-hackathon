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
        Move[5] moves; // Fixed-size array for gas efficiency
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
    // event PokemonCreated(uint256 indexed tokenId, string name, address indexed owner);
    // event BattleCompleted(uint256 indexed attackerId, uint256 indexed defenderId, bool attackerWon);
    // event RewardClaimed(address indexed player, uint256 amount);
    event PokemonCreated(
        uint256 indexed tokenId,
        address indexed owner,
        string name
    );

    event BattleStarted(
        uint256 indexed battleId,
        address indexed player1,
        uint256 indexed pokemon1Id,
        address player2,
        uint256 pokemon2Id,
        uint256 timestamp
    );

    event TurnResolved(
        uint256 indexed battleId,
        uint256 indexed pokemon1Id,
        uint256 indexed pokemon2Id,
        string move1,
        string move2,
        uint32 damageToP1,
        uint32 damageToP2,
        uint32 hp1After,
        uint32 hp2After
    );

    event BattleEnded(
        uint256 indexed battleId,
        address indexed winnerOwner,
        uint256 indexed winnerPokemonId,
        address loserOwner,
        uint256 loserPokemonId,
        uint8 totalTurns,
        uint256 timestamp
    );

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
        require(
            bytes(_name).length > 0 && bytes(_name).length <= 20,
            "Invalid name length"
        );

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);

        pokemon[newTokenId] = Pokemon({
            hp: 10,
            name: _name,
            moves: [
                Move("defend", 0, 100),
                Move(_move1, _move1atk, _move1agi),
                Move(_move2, _move2atk, _move2agi),
                Move("", 0, 0),
                Move("", 0, 0)
            ],
            owner: msg.sender,
            wins: 0,
            losses: 0,
            createdAt: block.timestamp
        });

        ownerToPokemon[msg.sender].push(newTokenId);
        pokemonExists[newTokenId] = true;

        emit PokemonCreated(newTokenId, msg.sender, _name);
        return newTokenId;
    }

    function battleTurn(
        uint256 battleId,
        uint256 pokemon1Id,
        uint256 pokemon2Id,
        uint8 moveIndex1,
        uint8 moveIndex2
    ) external nonReentrant {
        require(pokemonExists[pokemon1Id], "Pokemon1 does not exist");
        require(pokemonExists[pokemon2Id], "Pokemon2 does not exist");

        Pokemon storage p1 = pokemon[pokemon1Id];
        Pokemon storage p2 = pokemon[pokemon2Id];

        require(moveIndex1 < p1.moves.length, "Invalid move index for p1");
        require(moveIndex2 < p2.moves.length, "Invalid move index for p2");

        Move memory m1 = p1.moves[moveIndex1];
        Move memory m2 = p2.moves[moveIndex2];

        uint32 damageToP1 = 0;
        uint32 damageToP2 = 0;

        // --- Case 1: both defend ---
        if (
            keccak256(bytes(m1.name)) == keccak256("defend") &&
            keccak256(bytes(m2.name)) == keccak256("defend")
        ) {
            emit TurnResolved(
                battleId,
                pokemon1Id,
                pokemon2Id,
                m1.name,
                m2.name,
                0,
                0,
                p1.hp,
                p2.hp
            );
            return;
        }

        // --- Case 2: player1 defends, player2 attacks ---
        if (
            keccak256(bytes(m1.name)) == keccak256("defend") &&
            keccak256(bytes(m2.name)) != keccak256("defend")
        ) {
            // attack blocked
            emit TurnResolved(
                battleId,
                pokemon1Id,
                pokemon2Id,
                m1.name,
                m2.name,
                0,
                0,
                p1.hp,
                p2.hp
            );
            return;
        }

        // --- Case 3: player2 defends, player1 attacks ---
        if (
            keccak256(bytes(m2.name)) == keccak256("defend") &&
            keccak256(bytes(m1.name)) != keccak256("defend")
        ) {
            // attack blocked
            emit TurnResolved(
                battleId,
                pokemon1Id,
                pokemon2Id,
                m1.name,
                m2.name,
                0,
                0,
                p1.hp,
                p2.hp
            );
            return;
        }

        // --- Case 4: both attack ---
        if (
            keccak256(bytes(m1.name)) != keccak256("defend") &&
            keccak256(bytes(m2.name)) != keccak256("defend")
        ) {
            if (m1.agility > m2.agility) {
                // p1 attacks first
                damageToP2 = m1.attackPower;
                p2.hp = p2.hp > m1.attackPower ? p2.hp - m1.attackPower : 0;

                // if p2 survives, counterattack
                if (p2.hp > 0) {
                    damageToP1 = m2.attackPower;
                    p1.hp = p1.hp > m2.attackPower ? p1.hp - m2.attackPower : 0;
                }
            } else {
                // p2 attacks first
                damageToP1 = m2.attackPower;
                p1.hp = p1.hp > m2.attackPower ? p1.hp - m2.attackPower : 0;

                // if p1 survives, counterattack
                if (p1.hp > 0) {
                    damageToP2 = m1.attackPower;
                    p2.hp = p2.hp > m1.attackPower ? p2.hp - m1.attackPower : 0;
                }
            }
        }

        // Emit per-turn result
        emit TurnResolved(
            battleId,
            pokemon1Id,
            pokemon2Id,
            m1.name,
            m2.name,
            damageToP1,
            damageToP2,
            p1.hp,
            p2.hp
        );

        // --- End of turn: check win conditions ---
        if (p1.hp == 0 && p2.hp > 0) {
            p2.wins++;
            p1.losses++;
            emit BattleEnded(
                battleId,
                p2.owner,
                pokemon2Id,
                p1.owner,
                pokemon1Id,
                0,
                block.timestamp
            );
        } else if (p2.hp == 0 && p1.hp > 0) {
            p1.wins++;
            p2.losses++;
            emit BattleEnded(
                battleId,
                p1.owner,
                pokemon1Id,
                p2.owner,
                pokemon2Id,
                0,
                block.timestamp
            );
        } else if (p1.hp == 0 && p2.hp == 0) {
            // draw: both faint → you may want a special case
            emit BattleEnded(
                battleId,
                address(0),
                0,
                address(0),
                0,
                0,
                block.timestamp
            );
        }
    }

    function getMyPokemon()
        external
        view
        returns (
            uint256 tokenId,
            string memory name,
            uint32 hp,
            uint256 wins,
            uint256 losses,
            uint256 createdAt
        )
    {
        require(
            ownerToPokemon[msg.sender].length > 0,
            "You do not own a Pokemon"
        );
        tokenId = ownerToPokemon[msg.sender][0];
        Pokemon memory p = pokemon[tokenId];
        return (tokenId, p.name, p.hp, p.wins, p.losses, p.createdAt);
    }

    function getAllPokemon() external view returns (Pokemon[] memory) {
        uint256 total = _tokenIds.current();
        Pokemon[] memory result = new Pokemon[](total);
        for (uint256 i = 1; i <= total; i++) {
            result[i - 1] = pokemon[i];
        }
        return result;
    }

    function getLeaderboard()
        external
        view
        returns (
            uint256[10] memory tokenIds,
            string[10] memory names,
            uint256[10] memory wins
        )
    {
        uint256 total = _tokenIds.current();

        // temporary arrays for sorting
        uint256[] memory ids = new uint256[](total);
        for (uint256 i = 0; i < total; i++) {
            ids[i] = i + 1; // token IDs start at 1
        }

        // simple selection sort for top 10
        for (uint256 i = 0; i < total; i++) {
            for (uint256 j = i + 1; j < total; j++) {
                if (pokemon[ids[j]].wins > pokemon[ids[i]].wins) {
                    (ids[i], ids[j]) = (ids[j], ids[i]);
                }
            }
        }

        // take top 10
        for (uint256 k = 0; k < 10 && k < total; k++) {
            tokenIds[k] = ids[k];
            names[k] = pokemon[ids[k]].name;
            wins[k] = pokemon[ids[k]].wins;
        }
    }
}
