// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title PokemonGame
 * @dev Web3 Pokemon game with NFT Pokemon and battle mechanics
 */
contract PokemonGame is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIds;
    
    // Pokemon struct to store attributes
    struct Pokemon {
        uint32 hp;
        string name;
        uint8 attack;
        uint8 defense;
        mapping (string=>uint32[]) moves;
        uint8 agility;
        address owner;
        uint256 wins;
        uint256 losses;
        uint256 createdAt;
        // May need to add nft token id
        // uint256 tokenId;
        
    }
    
    // Battle struct to record battle history
    struct Battle {
        address Player1;
        address Player2;
        uint256 Player2Id;
        uint256 pokemon2Id;
        address winner_owner;
        uint256 winner_mon;
        uint256 timestamp;
    }
    
    // Mappings
    mapping(uint256 => Pokemon) public pokemon; //PlayerId -> Pokemon
    mapping(address => uint256[]) public ownerToPokemon; //wallet address -> nft id
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
    
    constructor() ERC721("Pokemon Game", "POKEMON") {}
    
    /**
     * @dev Create a new Pokemon NFT
     * @param _name Pokemon name
     * @param _attack Attack stat (1-100)
     * @param _defense Defense stat (1-100)
     * @param _agility Agility stat (1-100)
     */
    function createPokemon(
        string memory _name,
        mapping (string=>uint32[]) _moves,
        uint8 _attack,
        uint8 _defense,
        uint8 _agility
    ) external payable nonReentrant returns (uint256) {
        require(msg.value >= creationFee, "Insufficient creation fee");
        require(bytes(_name).length > 0 && bytes(_name).length <= 20, "Invalid name length");
        // require(_attack >= 1 && _attack <= 100, "Attack must be between 1-100");
        // require(_defense >= 1 && _defense <= 100, "Defense must be between 1-100");
        // require(_agility >= 1 && _agility <= 100, "Agility must be between 1-100");
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        // Mint NFT to sender
        _safeMint(msg.sender, newTokenId);
        
        // Create Pokemon with stats
        pokemon[newTokenId] = Pokemon({
            name: _name,
            hp: 20,
            attack: _attack,
            defense: _defense,
            agility: _agility,
            owner: msg.sender,
            wins: 0,
            losses: 0,
            createdAt: block.timestamp,
            moves: _moves
            
        });
        
        // Update ownership mapping
        ownerToPokemon[msg.sender].push(newTokenId);
        pokemonExists[newTokenId] = true;
        
        emit PokemonCreated(newTokenId, _name, msg.sender);
        return newTokenId;
    }
    
    /**
     * @dev Battle between two Pokemon
     * @param _attackerId ID of attacking Pokemon
     * @param _defenderId ID of defending Pokemon
     */

    function battle(
    uint256 pokemon1Id,
    uint256 pokemon2Id,
    string memory player1Move,
    string memory player2Move
) 
    external
    nonReentrant
    returns (string memory)
{
    require(pokemonExists[pokemon1Id], "Pokemon1 doesn't exist");
    require(pokemonExists[pokemon2Id], "Pokemon2 doesn't exist");

    Pokemon storage p1 = pokemon[pokemon1Id];
    Pokemon storage p2 = pokemon[pokemon2Id];

    require(p1.moves[player1Move] || keccak256(abi.encodePacked(player1Move)) == keccak256("defend"), "Invalid move");
    require(p2.moves[player2Move] || keccak256(abi.encodePacked(player2Move)) == keccak256("defend"), "Invalid move");

    if (
        keccak256(abi.encodePacked(player1Move)) == keccak256("defend") &&
        keccak256(abi.encodePacked(player2Move)) == keccak256("defend")
    ) {
        return "both defended";
    }

    Pokemon storage attacker;
    Pokemon storage defender;

    if (keccak256(abi.encodePacked(player1Move)) == keccak256("defend")) {
        return "player1 defended";
    } else if(keccak256(abi.encodePacked(player2Move)) == keccak256("defend")) {
        return "player2 defended";
    }
    if(p1.moves[player1Move][1] >= p2.moves[player2Move][1]) {
        attacker = p1;
        defender = p2;
    } else{
        attacker = p2;
        defender = p1;
    }

    string memory result = calculateBattlePower(attacker, defender, player1Move);

    if((keccak256(abi.encodePacked(result)) == keccak256("continue"))){
        attacker = (attacker.owner == p1.owner) ? p2 : p1;
        defender = (defender.owner == p1.owner) ? p2 : p1;

    }
    string memory result = calculateBattlePower(attacker, defender, player1Move);

    if (keccak256(abi.encodePacked(result)) == keccak256("attacker won")) {
        attacker.wins++;
        defender.losses++;
        emit BattleCompleted(pokemon1Id, pokemon2Id, attacker.owner == p1.owner);
        return string.concat("winner is ", attacker.name);
    }

    return "continue";
}

function calculateBattlePower(
    Pokemon storage attacker,
    Pokemon storage defender,
    string memory move
) internal returns (string memory) {
    defender.hp -= attacker.moves[move][0];
    if (defender.hp <= 0) {
        return "attacker won";
    }
    return "continue";
}

    
    /**
     * @dev Get Pokemon details
     * @param _tokenId Pokemon ID
     */
    function getPokemon(uint256 _tokenId) 
        external 
        view 
        returns (
            string memory name,
            uint8 attack,
            uint8 defense,
            uint8 agility,
            address owner
        ) 
    {
        require(pokemonExists[_tokenId], "Pokemon doesn't exist");
        Pokemon memory p = pokemon[_tokenId];
        return (p.name, p.attack, p.defense, p.agility, p.owner);
    }
    
    /**
     * @dev Get Pokemon with battle stats
     * @param _tokenId Pokemon ID
     */
    function getPokemonWithStats(uint256 _tokenId) 
        external 
        view 
        returns (
            string memory name,
            uint8 attack,
            uint8 defense,
            uint8 agility,
            address owner,
            uint256 wins,
            uint256 losses,
            uint256 createdAt
        ) 
    {
        require(pokemonExists[_tokenId], "Pokemon doesn't exist");
        Pokemon memory p = pokemon[_tokenId];
        return (p.name, p.attack, p.defense, p.agility, p.owner, p.wins, p.losses, p.createdAt);
    }
    
    /**
     * @dev Get all Pokemon owned by an address
     * @param _owner Owner address
     */
    function getPokemonsByOwner(address _owner) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return ownerToPokemon[_owner];
    }
    
    /**
     * @dev Get all existing Pokemon IDs
     */
    function getAllPokemon() external view returns (uint256[] memory) {
        uint256 totalSupply = _tokenIds.current();
        uint256[] memory result = new uint256[](totalSupply);
        
        for (uint256 i = 1; i <= totalSupply; i++) {
            result[i-1] = i;
        }
        
        return result;
    }
    
    /**
     * @dev Get battle history
     * @param _start Start index
     * @param _count Number of battles to return
     */
    function getBattleHistory(uint256 _start, uint256 _count) 
        external 
        view 
        returns (Battle[] memory) 
    {
        require(_start < battles.length, "Start index out of bounds");
        
        uint256 end = _start + _count;
        if (end > battles.length) {
            end = battles.length;
        }
        
        Battle[] memory result = new Battle[](end - _start);
        for (uint256 i = _start; i < end; i++) {
            result[i - _start] = battles[i];
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
        uint256 totalSupply = _tokenIds.current();
        require(_count <= totalSupply, "Count exceeds total supply");
        
        // Simple bubble sort for top Pokemon (inefficient but works for small datasets)
        uint256[] memory ids = new uint256[](totalSupply);
        uint256[] memory winCounts = new uint256[](totalSupply);
        
        // Populate arrays
        for (uint256 i = 1; i <= totalSupply; i++) {
            ids[i-1] = i;
            winCounts[i-1] = pokemon[i].wins;
        }
        
        // Sort by wins (descending)
        for (uint256 i = 0; i < totalSupply - 1; i++) {
            for (uint256 j = 0; j < totalSupply - i - 1; j++) {
                if (winCounts[j] < winCounts[j + 1]) {
                    // Swap wins
                    uint256 tempWins = winCounts[j];
                    winCounts[j] = winCounts[j + 1];
                    winCounts[j + 1] = tempWins;
                    
                    // Swap IDs
                    uint256 tempId = ids[j];
                    ids[j] = ids[j + 1];
                    ids[j + 1] = tempId;
                }
            }
        }
        
        // Return top _count
        uint256[] memory topIds = new uint256[](_count);
        uint256[] memory topWins = new uint256[](_count);
        
        for (uint256 i = 0; i < _count; i++) {
            topIds[i] = ids[i];
            topWins[i] = winCounts[i];
        }
        
        return (topIds, topWins);
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
            // Update Pokemon owner
            pokemon[tokenId].owner = to;
            
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
        require(_amount <= address(this).balance, "Insufficient contract balance");
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
            _tokenIds.current(),
            battleCount,
            address(this).balance,
            creationFee,
            battleReward
        );
    }
    
    /**
     * @dev Get total supply of Pokemon
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIds.current();
    }
    
    /**
     * @dev Receive function to accept ETH
     */
    receive() external payable {}
    
    /**
     * @dev Fallback function
     */
    fallback() external payable {}
}