// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "lib/chainlink/contracts/src/v0.8/vrf/dev/VRFCoordinatorV2_5.sol";
import "lib/chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";


contract TileGame is VRFConsumerBaseV2Plus, ReentrancyGuard {
    
    error TileGame__OutOfBounds();
    error TileGame__OutOfBalance();
    error TileGame__NoTilePurchased();
    error TileGame__TileAlreadyOpened();
    error TileGame__GameNotInitialized();
    error TileGame__RewardsNotCalculated();
    error TileGame__RandomnessNotFulfilled();
    error TileGame__OnlyOwner();
    error TileGame__WithdrawFailed();
    error TileGame__InsufficientContractBalance();

    uint256 public constant TILE_PRICE = 0.01 ether;
    uint256 public constant MINIMUM_REWARD = 0.005 ether;
    uint256 public constant MAXIMUM_REWARD = 0.02 ether;
    uint256 public constant GRID_SIZE = 7;
    uint256 public constant TOTAL_TILES = GRID_SIZE * GRID_SIZE;

    VRFCoordinatorV2_5 COORDINATOR;
    bytes32 constant SEPOLIA_KEY_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    address constant SEPOLIA_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    
    uint256 public subscriptionId;
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint32 constant CALLBACK_GAS_LIMIT = 100000;
    uint32 constant NUM_WORDS = 1;

    address public immutable i_owner;
    
    bool public gameInitialized;
    bool public randomnessFulfilled;
    bool public rewardsCalculated;
    uint256 public randomSeed;
    uint256 public requestId;

    Tile[TOTAL_TILES] public tiles;
    mapping(address => Player) public players;

    struct Tile {
        bool opened;
        uint256 rewardAmount;
        address openedBy;
    }

    struct Player {
        uint256 tilesPurchased;
        uint256 tilesOpened;
        uint256 totalReward;
        bool rewardWithdrawn;
    }

    event GameInitialized(uint256 requestId);
    event RandomnessFulfilled(uint256 seed);
    event RewardsCalculated();
    event TilesPurchased(address indexed player, uint256 amount);
    event TileOpened(address indexed player, uint256 tileIndex, uint256 reward);
    event RewardWithdrawn(address indexed player, uint256 amount);
    event GameReset();

    modifier gameActive() {
        if (!gameInitialized) {
            revert TileGame__GameNotInitialized();
        }
        if (!rewardsCalculated) {
            revert TileGame__RewardsNotCalculated();
        }
        _;
    }

    constructor(uint256 _subscriptionId) VRFConsumerBaseV2Plus(SEPOLIA_COORDINATOR) {
        i_owner = msg.sender;
        subscriptionId = _subscriptionId;
        COORDINATOR = VRFCoordinatorV2_5(SEPOLIA_COORDINATOR);
    }

    function initializeGame() external onlyOwner {
        if (gameInitialized) {
            revert TileGame__GameNotInitialized();
        }

        gameInitialized = true;
        randomnessFulfilled = false;
        rewardsCalculated = false;

        for (uint256 i = 0; i < TOTAL_TILES; i++) {
            tiles[i] = Tile({
                opened: false,
                rewardAmount: 0,
                openedBy: address(0)
            });
        }

        VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient.RandomWordsRequest({
            keyHash: SEPOLIA_KEY_HASH,
            subId: subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });

        requestId = COORDINATOR.requestRandomWords(req);
        
        emit GameInitialized(requestId);
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] calldata randomWords) internal override {
        if (_requestId != requestId) {
            return;
        }

        randomSeed = randomWords[0];
        randomnessFulfilled = true;

        emit RandomnessFulfilled(randomSeed);
    }

    function calculateRewards() external {
        if (!gameInitialized) {
            revert TileGame__GameNotInitialized();
        }
        if (!randomnessFulfilled) {
            revert TileGame__RandomnessNotFulfilled();
        }
        if (rewardsCalculated) {
            return; 
        }

        uint256 baseReward = MINIMUM_REWARD + (randomSeed % (MAXIMUM_REWARD - MINIMUM_REWARD));

        for (uint256 i = 0; i < TOTAL_TILES; i++) {
            uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(randomSeed, i))) % 7 + 1;
            uint256 offset = pseudoRandom * 1e15;
            
            uint256 reward = baseReward + offset;
            if (reward > MAXIMUM_REWARD) {
                reward = MAXIMUM_REWARD;
            }
            
            tiles[i].rewardAmount = reward;
        }

        rewardsCalculated = true;
        emit RewardsCalculated();
    }

    function buyTiles(uint256 n) external payable gameActive {
        if (n == 0 || n > TOTAL_TILES) {
            revert TileGame__OutOfBounds();
        }

        uint256 totalCost = n * TILE_PRICE;
        if (msg.value != totalCost) {
            revert TileGame__OutOfBalance();
        }

        players[msg.sender].tilesPurchased += n;
        
        emit TilesPurchased(msg.sender, n);
    }

    function openTiles(uint256 tileIndex) external gameActive nonReentrant {
        if (tileIndex >= TOTAL_TILES) {
            revert TileGame__OutOfBounds();
        }

        Player storage player = players[msg.sender];
        
        if (player.tilesPurchased == 0) {
            revert TileGame__NoTilePurchased();
        }
        
        if (player.tilesOpened >= player.tilesPurchased) {
            revert TileGame__NoTilePurchased();
        }

        Tile storage tile = tiles[tileIndex];
        
        if (tile.opened) {
            revert TileGame__TileAlreadyOpened();
        }

        tile.opened = true;
        tile.openedBy = msg.sender;
        player.tilesOpened += 1;
        player.totalReward += tile.rewardAmount;

        emit TileOpened(msg.sender, tileIndex, tile.rewardAmount);

        if (player.tilesOpened == player.tilesPurchased && !player.rewardWithdrawn) {
            _withdrawReward(player);
        }
    }

    function _withdrawReward(Player storage player) internal {
        uint256 totalAmount = player.totalReward;
        
        if (totalAmount == 0) {
            return;
        }

        if (address(this).balance < totalAmount) {
            revert TileGame__InsufficientContractBalance();
        }

        player.rewardWithdrawn = true;

        (bool sent, ) = payable(msg.sender).call{value: totalAmount}("");
        if (!sent) {
            revert TileGame__WithdrawFailed();
        }

        emit RewardWithdrawn(msg.sender, totalAmount);
    }

    function resetGame() external onlyOwner {
        gameInitialized = false;
        randomnessFulfilled = false;
        rewardsCalculated = false;
        randomSeed = 0;
        requestId = 0;

        // Clear all tiles
        for (uint256 i = 0; i < TOTAL_TILES; i++) {
            tiles[i] = Tile({
                opened: false,
                rewardAmount: 0,
                openedBy: address(0)
            });
        }

        emit GameReset();
    }

    function withdrawReward() external nonReentrant {
        Player storage player = players[msg.sender];
        
        if (player.rewardWithdrawn) {
            revert TileGame__InsufficientContractBalance();
        }

        _withdrawReward(player);
    }

    function fundContract() external payable onlyOwner {}

    function emergencyWithdraw() external onlyOwner {
        (bool sent, ) = payable(i_owner).call{value: address(this).balance}("");
        if (!sent) {
            revert TileGame__WithdrawFailed();
        }
    }

    function updateSubscriptionId(uint256 _newSubscriptionId) external onlyOwner {
        subscriptionId = _newSubscriptionId;
    }

    function getGameState() external view returns (
        bool initialized,
        bool randomnessFulfilled_,
        bool rewardsCalculated_,
        uint256 seed
    ) {
        return (gameInitialized, randomnessFulfilled, rewardsCalculated, randomSeed);
    }

    function getPlayerInfo(address player) external view returns (
        uint256 tilesPurchased,
        uint256 tilesOpened,
        uint256 totalReward,
        bool rewardWithdrawn
    ) {
        Player storage p = players[player];
        return (p.tilesPurchased, p.tilesOpened, p.totalReward, p.rewardWithdrawn);
    }

    function getTileInfo(uint256 tileIndex) external view returns (
        bool opened,
        uint256 rewardAmount,
        address openedBy
    ) {
        if (tileIndex >= TOTAL_TILES) {
            revert TileGame__OutOfBounds();
        }
        
        Tile storage tile = tiles[tileIndex];
        return (tile.opened, tile.rewardAmount, tile.openedBy);
    }

    function getAllTilesStatus() external view returns (
        bool[] memory opened,
        uint256[] memory rewards
    ) {
        opened = new bool[](TOTAL_TILES);
        rewards = new uint256[](TOTAL_TILES);
        
        for (uint256 i = 0; i < TOTAL_TILES; i++) {
            opened[i] = tiles[i].opened;
            rewards[i] = tiles[i].rewardAmount;
        }
        
        return (opened, rewards);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function isReadyForStart() external view returns (bool) {
        return gameInitialized && randomnessFulfilled && !rewardsCalculated;
    }

    function isGameActive() external view returns (bool) {
        return gameInitialized && randomnessFulfilled && rewardsCalculated;
    }
}