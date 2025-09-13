// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/security/Pausable.sol";

contract PokemonGame is ERC721Enumerable, Ownable, ReentrancyGuard, Pausable {
    using Strings for uint256;

    struct Move {
        string name;
        uint32 attackPower; // Damage dealt
        uint32 agility; // Used to determine attack order
    }

    struct Pokemon {
        string name;
        uint32 hp;
        Move[] moves;
        uint256 wins;
        uint256 losses;
        uint64 createdAt;
    }

    struct Battle {
        uint256 pokemon1Id;
        uint256 pokemon2Id;
        address winner;
        uint256 timestamp;
    }

    mapping(uint256 => Pokemon) public pokemons;
    mapping(address => uint256[]) public ownerToPokemon;
    Battle[] public battles;

    uint256 public creationFee = 0.01 ether;
    // Add these state variables near the top (after `creationFee`)
    uint256 public battleReward = 0.005 ether; // Example default value
    uint256 public battleCount; // Tracks total battles

    event PokemonCreated(
        uint256 indexed tokenId,
        string name,
        address indexed owner
    );
    event BattleCompleted(
        uint256 indexed battleId,
        address indexed winner,
        uint256 winnerPokemonId
    );

    constructor() ERC721("Pokemon Game", "POKEMON") {}

    modifier onlyExistingPokemon(uint256 tokenId) {
        require(_exists(tokenId), "Pokemon does not exist");
        _;
    }

    function createPokemon(
        string memory _name,
        Move[] memory _moves
    ) external payable nonReentrant whenNotPaused returns (uint256) {
        require(msg.value >= creationFee, "Insufficient creation fee");
        require(
            bytes(_name).length > 0 && bytes(_name).length <= 20,
            "Invalid name length"
        );
        require(_moves.length > 0, "Pokemon must have at least one move");

        uint256 newTokenId = totalSupply() + 1;
        _safeMint(msg.sender, newTokenId);

        // ✅ Fix: Initialize moves in memory first, then assign to storage
    Move[] memory moveList = new Move[](_moves.length);
    for (uint i = 0; i < _moves.length; i++) {
        moveList[i] = _moves[i];
    }
        pokemons[newTokenId] = Pokemon({
            name: _name,
            hp: 100,
            moves: moveList,
            wins: 0,
            losses: 0,
            createdAt: uint64(block.timestamp)
        });

        ownerToPokemon[msg.sender].push(newTokenId);

        emit PokemonCreated(newTokenId, _name, msg.sender);
        return newTokenId;
    }

    /**
     * @dev Battle between two Pokemon using chosen move indexes
     */
    function battle(
        uint256 pokemon1Id,
        uint256 pokemon2Id,
        uint8 move1Index,
        uint8 move2Index
    )
        external
        nonReentrant
        whenNotPaused
        onlyExistingPokemon(pokemon1Id)
        onlyExistingPokemon(pokemon2Id)
        returns (string memory)
    {
        require(ownerOf(pokemon1Id) == msg.sender, "You must own Pokemon1");
        require(pokemon1Id != pokemon2Id, "Cannot battle the same Pokemon");

        Pokemon storage p1 = pokemons[pokemon1Id];
        Pokemon storage p2 = pokemons[pokemon2Id];

        require(move1Index < p1.moves.length, "Invalid move for Pokemon1");
        require(move2Index < p2.moves.length, "Invalid move for Pokemon2");

        Move memory m1 = p1.moves[move1Index];
        Move memory m2 = p2.moves[move2Index];

        // Determine attack order based on agility
        bool p1AttacksFirst = (m1.agility >= m2.agility);

        string memory battleResult;
        if (p1AttacksFirst) {
            battleResult = _attackSequence(p1, p2, m1, m2, true);
        } else {
            battleResult = _attackSequence(p2, p1, m2, m1, false);
        }

        // Record battle result
        address winnerAddr;
        uint256 winnerId;
        if (keccak256(bytes(battleResult)) == keccak256("Pokemon1 wins")) {
            winnerAddr = ownerOf(pokemon1Id);
            winnerId = pokemon1Id;
        } else if (
            keccak256(bytes(battleResult)) == keccak256("Pokemon2 wins")
        ) {
            winnerAddr = ownerOf(pokemon2Id);
            winnerId = pokemon2Id;
        }

        battles.push(
            Battle({
                pokemon1Id: pokemon1Id,
                pokemon2Id: pokemon2Id,
                winner: winnerAddr,
                timestamp: block.timestamp
            })
        );

        emit BattleCompleted(battles.length - 1, winnerAddr, winnerId);

        return battleResult;
    }

    function _attackSequence(
        Pokemon storage first,
        Pokemon storage second,
        Move memory firstMove,
        Move memory secondMove,
        bool firstIsP1
    ) internal returns (string memory) {
        bool firstDefends = keccak256(bytes(firstMove.name)) ==
            keccak256("Defend");
        bool secondDefends = keccak256(bytes(secondMove.name)) ==
            keccak256("Defend");

        // First attack phase
        if (!secondDefends && !firstDefends) {
            if (second.hp <= firstMove.attackPower) {
                _recordWinLoss(first, second);
                return firstIsP1 ? "Pokemon1 wins" : "Pokemon2 wins";
            }
            second.hp -= firstMove.attackPower;
        }

        // Counter attack phase
        if (!firstDefends && !secondDefends) {
            if (first.hp <= secondMove.attackPower) {
                _recordWinLoss(second, first);
                return firstIsP1 ? "Pokemon2 wins" : "Pokemon1 wins";
            }
            first.hp -= secondMove.attackPower;
        }

        return "Battle continues"; // Both defended or survived → next round
    }

    function _recordWinLoss(
        Pokemon storage winner,
        Pokemon storage loser
    ) internal {
        winner.wins++;
        loser.losses++;
    }

    function pauseGame() external onlyOwner {
        _pause();
    }

    function unpauseGame() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Get Pokemon details
     * @param _tokenId Pokemon ID
     */
    // Return basic info (excluding moves to keep this cheap)
    function getPokemon(
        uint256 _tokenId
    ) external view returns (string memory name, uint32 hp, address owner) {
        require(_exists(_tokenId), "Pokemon doesn't exist");
        Pokemon storage p = pokemons[_tokenId];
        return (p.name, p.hp, ownerOf(_tokenId));
    }

    /**
     * @dev Get Pokemon with battle stats (excluding moves)
     */
    function getPokemonWithStats(
        uint256 _tokenId
    )
        external
        view
        returns (
            string memory name,
            uint32 hp,
            address owner,
            uint256 wins,
            uint256 losses,
            uint64 createdAt
        )
    {
        require(_exists(_tokenId), "Pokemon doesn't exist");
        Pokemon storage p = pokemons[_tokenId];
        return (p.name, p.hp, ownerOf(_tokenId), p.wins, p.losses, p.createdAt);
    }

    function getPokemonMoves(
        uint256 _tokenId
    ) external view returns (Move[] memory) {
        require(_exists(_tokenId), "Pokemon doesn't exist");
        Pokemon storage p = pokemons[_tokenId];
        uint256 len = p.moves.length;
        Move[] memory out = new Move[](len);
        for (uint256 i = 0; i < len; i++) {
            out[i] = p.moves[i];
        }
        return out;
    }

    /**
     * @dev Get all Pokemon owned by an address
     * @param _owner Owner address
     */
    function getPokemonsByOwner(
        address _owner
    ) external view returns (uint256[] memory) {
        return ownerToPokemon[_owner];
    }

    /**
     * @dev Get all existing Pokemon IDs
     */
    function getAllPokemon() external view returns (uint256[] memory) {
    uint256 total = totalSupply();
    uint256[] memory result = new uint256[](total);
    for (uint256 i = 0; i < total; i++) {
        result[i] = tokenByIndex(i); // ✅ Fixed
    }
    return result;
}
    /**
     * @dev Get battle history
     * @param _start Start index
     * @param _count Number of battles to return
     */
    function getBattleHistory(
        uint256 _start,
        uint256 _count
    ) external view returns (Battle[] memory) {
        uint256 total = battles.length;
        if (_start >= total) {
            // return empty array
            return new Battle[](0);
        }

        uint256 end = _start + _count;
        if (end > total) end = total;
        uint256 len = end - _start;
        Battle[] memory result = new Battle[](len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = battles[_start + i];
        }
        return result;
    }

    /**
     * @dev Get Pokemon leaderboard by wins
     * @param _count Number of top Pokemon to return
     */
function getLeaderboard(uint256 _count)
    external
    view
    returns (uint256[] memory pokemonIds, uint256[] memory wins)
{
    uint256 total = totalSupply(); // ✅ Fixed
    require(total > 0, "No pokemon exist");
    // ... rest of the function

        // Build arrays only for existing tokens
        uint256 existingCount = 0;
        for (uint256 i = 1; i <= total; i++) {
            if (_exists(i)) existingCount++;
        }

        require(existingCount > 0, "No pokemon exist");
        if (_count == 0 || _count > existingCount) _count = existingCount;

        // Populate arrays
        uint256[] memory ids = new uint256[](existingCount);
        uint256[] memory winCounts = new uint256[](existingCount);
        uint256 idx = 0;
        for (uint256 i = 1; i <= total; i++) {
            if (!_exists(i)) continue;
            ids[idx] = i;
            winCounts[idx] = pokemons[i].wins;
            idx++;
        }

        // Simple selection sort for top _count (better than full bubble sort for top-k)
        for (uint256 i = 0; i < _count; i++) {
            uint256 bestIdx = i;
            for (uint256 j = i + 1; j < existingCount; j++) {
                if (winCounts[j] > winCounts[bestIdx]) {
                    bestIdx = j;
                }
            }
            // Swap into position i
            (winCounts[i], winCounts[bestIdx]) = (
                winCounts[bestIdx],
                winCounts[i]
            );
            (ids[i], ids[bestIdx]) = (ids[bestIdx], ids[i]);
        }

        // Prepare output arrays
        pokemonIds = new uint256[](_count);
        wins = new uint256[](_count);
        for (uint256 i = 0; i < _count; i++) {
            pokemonIds[i] = ids[i];
            wins[i] = winCounts[i];
        }
        return (pokemonIds, wins);
    }

    /**
     * @dev Transfer ownership of Pokemon (override to update our mapping)
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);

        if (from != address(0) && to != address(0)) {
          

            // Remove from old owner's list
            uint256[] storage fromPokemon = ownerToPokemon[from];
            for (uint256 i = 0; i < fromPokemon.length; i++) {
                if (fromPokemon[i] == tokenId) {
                    fromPokemon[i] = fromPokemon[fromPokemon.length - 1];
                    fromPokemon.pop();
                    break;
                }
            }

            // Add to new owner's list
            ownerToPokemon[to].push(tokenId);
        }
    }

    /**
     * @dev Update creation fee (owner only)
     */
    function setCreationFee(uint256 _newFee) external onlyOwner {
        creationFee = _newFee;
    }

    /**
     * @dev Update battle reward (owner only)
     */
    function setBattleReward(uint256 _newReward) external onlyOwner {
        battleReward = _newReward;
    }

    /**
     * @dev Withdraw contract balance (owner only)
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        payable(owner()).transfer(balance);
    }

    /**
     * @dev Emergency withdraw for specific amount (owner only)
     */
    function withdrawAmount(uint256 _amount) external onlyOwner {
        require(
            _amount <= address(this).balance,
            "Insufficient contract balance"
        );
        payable(owner()).transfer(_amount);
    }

    /**
     * @dev Get contract statistics
     */
    function getContractStats()
        external
        view
        returns (
            uint256 totalPokemon,
            uint256 totalBattles,
            uint256 contractBalance,
            uint256 creationCost,
            uint256 winReward
        )
    {
        return (
            totalSupply(),
            battleCount,
            address(this).balance,
            creationFee,
            battleReward
        );
    }

    /**
     * @dev Get total supply of Pokemon
     */
    

    /**
     * @dev Receive function to accept ETH
     */
    receive() external payable {}

    /**
     * @dev Fallback function
     */
    fallback() external payable {}
}
