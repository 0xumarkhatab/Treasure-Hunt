// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ConfirmedOwner} from "@chainlink/contracts@1.2.0/src/v0.8/shared/access/ConfirmedOwner.sol";
import {VRFV2WrapperConsumerBase} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import {LinkTokenInterface} from "@chainlink/contracts@1.2.0/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

/**

             _______   ___     ____      _ ____   __    __   ___     _____
            |___ ___| |  _ \  | ____|   /_____ | |  |  |  | |  _ \  | ____|
               | |    | |_) | |  _|    /______   |  |  |  | | |_) | |  _|  
               | |    |  _ <  | |___   \_____ \  |  |__|  | |  _ <  | |___ 
              |___|   |_| \_\ |_____|  |______/  |__ __ __| |_| \_\ |_____|
                         __     __   __    __   __       __   _________    
                        |__|   |__| |  |  |  | |__|\\   |__| |_________|
                         | |___| |  |  |  |  |  | | \\  | |      | |
                         | |___| |  |  |  |  |  | |  \\ | |      | |
                         | |   | |  |  |__|  |  | |   \\| |      | |
                         |_|   |_|  |__ __ __|  |_|     |_|     |___| 
 
 
                   | 0	| 1  | 2  |  3 |  4 | 5  | 6  | 7  | 8  | 9  |
                   | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
                   | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 |
                   | 30 | 31 | 32 | 33 | 34 | 35 | 36 | 37 | 38 | 39 |
                   | 40 | 41 | 42 | 43 | 💰 | 45 | 46 | 47 | 48 | 49 |
                   | 50 | 51 | 52 | 53 | 54 | 55 | 56 | 57 | 58 | 59 |
                   | 60 | 61 | 62 | 63 | 64 | 65 | 66 | 67 | 68 | 69 |
                   | 70 | 71 | 72 | 73 | 74 | 75 | 76 | 77 | 78 | 79 |
                   | 80 | 81 | 82 | 83 | 84 | 85 | 86 | 87 | 88 | 89 |
                   | 90 | 91 | 92 | 93 | 94 | 95 | 96 | 97 | 98 | 99 |

 Name     : On Chain Treasure Hunt Game
 Version  : 1.0
 Author   : 0xumarkhatab
 email    : umarkhatabfrl at gmail.com
 Liscense : MIT
 
*/

contract TreasureHunt is VRFV2WrapperConsumerBase, ConfirmedOwner {
    //  ////////////////////////
    //      State Variables
    // //////////////////////////

    //Platform Owner
    address admin;

    // Size of the game grid (10x10)
    uint8 public constant GRID_SIZE = 10;
    // chainlink -vrf-param
    uint16 requestConfirmations = 3;
    // chainlink -vrf-param
    uint32 callbackGasLimit = 100000;
    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFV2Wrapper.getConfig().maxNumWords.
    uint32 numWords = 1;
    // percentage of the total ETH balance that the winner receives (90%)
    uint8 public constant TREASURE_REWARD_PERCENT = 90;

    //  160+8+16+32+32 =248 bits

    // current position hash of the treasure on the grid - to avoid reading the secret position directly
    bytes32 treasurePosition;
    // total amount of ETH deposited by all players
    uint256 public totalEth;

    /*
        Fees :
        1. Joing Fee : Every user needs to pay a joining/registration Fee to be able to take part in the game
        2. Each time a user wants to play , they have to make a small payment too to prevent volumetric attacks by Bots
    */
    uint256 public randomWordsNum;
    uint256 public lastRequestId;

    uint256 public joinFee = 0.1 ether;
    uint256 public playFee = 0.01 ether;

    // Sepolia Link Token and Wrapper address for chainlink vrf
    address immutable linkToken = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address immutable wrapperAddress =
        0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;

    //  ////////////////////////
    //      Struct Definitions
    // //////////////////////////

    struct Player {
        address address_; // player's Ethereum address
        uint8 position; // player's current position on the grid
    }
    struct RequestStatus {
        uint256 paid; // amount paid in link
        bool fulfilled; // whether the request has been successfully fulfilled
        uint256[] randomWords;
    }

    //  ////////////////////////
    //      Mappings Definitions
    // //////////////////////////

    mapping(address => Player) public players;
    mapping(address => uint) public lastPlayedBlockNumber;
    mapping(address => bool) public isRegistered;

    //  Chainlink VRF mappings
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */
    uint256[] public requestIds;

    //  ////////////////////////
    //      Modifiers
    // //////////////////////////
    modifier onlyAdmin() {
        if (admin != msg.sender) {
            revert AdminRestrictedMethod();
        }
        _;
    }

    //  ////////////////////////
    //      Events
    // //////////////////////////

    event Joined_Game(address player, uint timestamp);
    event Won_Game(address player, uint timestamp, uint amount);
    event Treasury_Updated(address player, uint timestamp);

    // chainlink VRF related events
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(
        uint256 requestId,
        uint256[] randomWords,
        uint256 payment
    );

    //  ////////////////////////
    //      Custom Erros
    // //////////////////////////
    error GameNotStarted();
    error InsufficientPlayFee();
    error InsufficientJoinFee();
    error PlayerNotRegistered();
    error OnlyOneMovePerBlock();
    error InvalidPosition();
    error InvalidMove();
    error AdminRestrictedMethod();

    //  ////////////////////////
    //      External Methods
    // //////////////////////////

    //  ************** Intiial approach ******************

    /**
     * 
    We could intialize the treasure position inside constructor , however , we need to send tokens to the contract
    before consuming the Chainlink VRF service
    As before constructor , we do not know the address of the contract to send Link funds to , we made an initalize function that is adminOnly
    The deployment and initalization will happen in the same transaction in our script supposition.

    Pre-calculation of address can be done using Create2 , however , i wanted to keep things simple, that's why i've used deploy-initialize pattern
    
     */

    /**
     *
        ************* Cuurrent Approach **********************

        Create2 determinisitic deployment

        //1. Caclulate create2 address
        uint salt = 1234;
        bytes memory bytecode = getBytecode();
        address calculated_treasure_hunt_address = computeAddress(
            bytecode,
            salt,
            owner
        );

        // 2. Pre-transfering Link tokens because the contract is a VRF consumer
        // that will fetch the random number from chainlink by paying link as fee
        linkToken.transfer(calculated_treasure_hunt_address, 10e18 ether);

        // 3. Actually deploy the contract at the same address . Thanks to Create2
        address deployed_address = deployTreasureHunt(bytecode, salt);
        treasureHunt = TreasureHunt(deployed_address);
        require(
            deployed_address == calculated_treasure_hunt_address,
            "different deployment addresses"
        );

     */
    // Marked payable for gas optimization
    constructor()
        payable 
        ConfirmedOwner(msg.sender)
        VRFV2WrapperConsumerBase(linkToken, wrapperAddress)
    {
        admin = msg.sender;
        uint8 rand = getRandomPosition();
        assign_treasure_position(rand);
    }

    // Follows CEI
    function joinGame() external payable {
        // This function allows a player to join the game
        // It requires the player to send ETH to join
        if (msg.value < joinFee) {
            revert InsufficientJoinFee();
        }
        // Register the player
        isRegistered[msg.sender] = true;
        // Get a random position to assign to user
        uint8 rand = getRandomPosition();

        // Unchecked for gas optimization

        unchecked {
            totalEth += msg.value;
            //  Assign a random position to user
            players[msg.sender].position = rand;
        }

        emit Joined_Game(msg.sender, block.timestamp);
    }

    function move(uint8 newPosition) external payable returns (bool) {
        bool isWon = false;
        if (treasurePosition == bytes32(0)) {
            revert GameNotStarted();
        }
        if (msg.value < playFee) {
            revert InsufficientPlayFee();
        }
        // This function allows players to move on the grid
        // It checks if it's the current player's registered and they are making valid move ?
        if (!isRegistered[msg.sender]) {
            revert PlayerNotRegistered();
        }

        if (lastPlayedBlockNumber[msg.sender] >= block.number) {
            revert OnlyOneMovePerBlock();
        }
        if (newPosition >= GRID_SIZE * GRID_SIZE) {
            revert InvalidPosition();
        }

        // Check if the move is valid (adjacent to the current position)
        if (!isValidMove(players[msg.sender].position, newPosition)) {
            revert InvalidMove();
        }

        // Update the player's position
        uint8 old_position = players[msg.sender].position;
        players[msg.sender].position = newPosition;
        lastPlayedBlockNumber[msg.sender] = block.number;
        // Move the treasure based on the rules
        bytes32 old_treasury_position = treasurePosition;
        moveTreasure(newPosition);

        // Check if the player has won

        if (
            keccak256(abi.encodePacked(old_position)) ==
            old_treasury_position ||
            keccak256(abi.encodePacked(newPosition)) == treasurePosition
        ) {
            // Calculate the reward and transfer it to the winner
            uint256 reward = (totalEth * TREASURE_REWARD_PERCENT) / 100;
            payable(msg.sender).transfer(reward);
              // Unchecked for gas optimization
        unchecked {
            totalEth -= reward;
        }
            isWon = true;
            // moveTreasure(newPosition);
        }
        return isWon;
    }

    //  ////////////////////////
    //      Public Methods
    // //////////////////////////

    /**

This function checks if a move is valid (adjacent to the current position) using getPossibleMoves uder the hood.

It checks if the new position is within the grid and if the difference between the current and new positions 
(up, down, left, or right)
    
Virtial Board Format :

                   | 0	| 1  | 2  |  3 |  4 | 5  | 6  | 7  | 8  | 9  |
                   | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
                   | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 |
                   | 30 | 31 | 32 | 33 | 34 | 35 | 36 | 37 | 38 | 39 |
                   | 40 | 41 | 42 | 43 | 44 | 45 | 46 | 47 | 48 | 49 |
                   | 50 | 51 | 52 | 53 | 54 | 55 | 56 | 57 | 58 | 59 |
                   | 60 | 61 | 62 | 63 | 64 | 65 | 66 | 67 | 68 | 69 |
                   | 70 | 71 | 72 | 73 | 74 | 75 | 76 | 77 | 78 | 79 |
                   | 80 | 81 | 82 | 83 | 84 | 85 | 86 | 87 | 88 | 89 |
                   | 90 | 91 | 92 | 93 | 94 | 95 | 96 | 97 | 98 | 99 |
        
Possible Moves :

Note :-

We don't allow wrap-around moves like 
right from 10 would lead to 1 , up from 1 would lead to 91 
we don't do that here to keep things simple

Current Position | Possible Moves (Valid/Invalid)
----------------|-----------------------------
|  3            | 3 - 10 = -7 ❌, 3 + 10 = 13 ✅ , 3 - 1 = 2 ✅, 3 + 1 = 4 ✅
|  10           | 10 - 10 = 0 ✅ , 10 + 10 = 20 ✅, 10 - 1 = 9,10%10==0 ❌, 10 + 1 = 11 ✅
|  95           | 95 - 10 = 85 ✅, 95 + 10 = 105 ❌, 95 - 1 = 94 ✅, 95 + 1 = 96 ✅
|  91           | 91 - 10 = 81 ✅, 91 + 10 = 101 ❌, 91 - 1 = 90 ✅, 91 + 1 = 92

Summary :

Generally , allowed moves will be like 

                ✅ left ( difference is -1 )
                ✅ right ( difference is +1 )
                ✅ up ( minus GridSize )
                ✅ Down ( + GridSize )
                ✅ They are valid moves in General,
                ✅ check `getPossibleMoves method
 

*/

    function isValidMove(
        uint8 currentPosition,
        uint8 newPosition
    ) public pure returns (bool) {
        uint8[4] memory possible_moves = getPossibleMoves(currentPosition);
        for (uint8 i = 0; i < possible_moves.length; ) {
            if ((newPosition) == possible_moves[i]) {
                return true;
            }
            unchecked{
                i=i+1;
            }
        }
        return false;
    }

    function getPossibleMoves(
        uint8 position
    ) public pure returns (uint8[4] memory) {
        uint8[4] memory possibleMoves;

        // If the first index has value type(uint8).max, it means there were none of the possible moves
        //  Maybe in upcoming versions , we roll over conditions i.e if one cell can not be picked again etc.
        possibleMoves[0] = type(uint8).max;

        uint8 idx = 0;
        // Move down by GRID_SIZE , requirement : Not last row position + GRID_SIZE < GRID_SIZE * GRID_SIZE
        if (position + GRID_SIZE < GRID_SIZE * GRID_SIZE)
            possibleMoves[idx++] = (position + GRID_SIZE);
        // Move up , requirement : not first row entries s.t position - GRID_SIZE > 0)
        int pos_diff = int(uint(position)) - int(uint(GRID_SIZE));

        if (position >= GRID_SIZE && pos_diff >= 0)
            possibleMoves[idx++] = (position - GRID_SIZE);
        // Move right , requirement: Not right most column entries  (position+1) % 10 != 0
        if (position + 1 > 0 && (position + 1) % 10 != 0)
            possibleMoves[idx++] = (position + 1);
        // Move left : requirement : Not left most column position % 10 !=0
        pos_diff = int(uint(position)) - 1;

        if (pos_diff >= 0 && position - 1 > 0 && position % 10 != 0)
            possibleMoves[idx++] = (position - 1);
        return possibleMoves;
    }

    //  ////////////////////////
    //      Internal Methods
    // //////////////////////////
    function assign_treasure_position(uint8 rand) internal {
        treasurePosition = keccak256(abi.encodePacked(rand));
        emit Treasury_Updated(msg.sender, block.timestamp);
    }

    function moveTreasure(uint8 newMove) internal {
        // This function moves the treasure based on the rules:
        // - If the current position is a multiple of 5, move to a random adjacent position.
        // - If the current position is prime, move to a random position on the grid.

        uint8 rand;
        if (isMultipleOf5(newMove)) {
            rand = (getRandomAdjacentPosition(newMove));
            assign_treasure_position(rand);
        } else if (isPrime(newMove)) {
            rand = getRandomPosition();
            assign_treasure_position(rand);
        }
    }

    //     //////////////////////////
    //      Utlity+Math intensive Methods
    //   ////////////////////////////

    function isMultipleOf5(uint8 number) internal pure returns (bool) {
        return number % 5 == 0;
    }

    function isPrime(uint8 number) internal pure returns (bool) {
        // This function checks if a number is prime
        // It uses a simple algorithm to check if the number is divisible by any number other than 1 and itself
        if (number <= 1) {
            return false;
        }
        if (number <= 3) {
            return true;
        }
        if (number % 2 == 0 || number % 3 == 0) {
            return false;
        }

        for (uint8 i = 5; i * i <= number; i += 6) {
            if (number % i == 0 || number % (i + 2) == 0) {
                return false;
            }
        }

        return true;
    }

    function getRandomAdjacentPosition(
        uint8 position_
    ) internal returns (uint8) {
        int position = int(uint(position_));

        // This function gets a random adjacent position to the current position
        // It generates a random direction (0, 1, 2, 3 for up, right, down, left) and calculates the new position based on the direction

        uint8 direction = uint8(getRandomPosition() % 4);
        int val;
        int _grid_size = int(uint(GRID_SIZE));
        if (direction == 0) {
            val = int(position) - _grid_size; // Move up
        } else if (direction == 1) {
            val = int(position) + 1; // Move right
        } else if (direction == 2) {
            val = int(position) + _grid_size; // Move down
        } else {
            val = int(position) - 1; // Move left
        }
        return uint8(int8(val % (_grid_size * _grid_size)));
    }

    function getRandomPosition() public returns (uint8) {
        // This function gets a random position on the grid
        // It generates a random number using the block hash and timestamp and maps it to a grid position

        // Needs to be replaced by chainlink VRF call

        requestRandomWords();

        uint8 source_rnd = uint8(randomWordsNum) % (GRID_SIZE * GRID_SIZE);

        return source_rnd;
    }

    /**
     *  Chainlink interface
     */

    function requestRandomWords() internal returns (uint256 requestId) {
        requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            paid: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            randomWords: new uint256[](0),
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].paid > 0, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(
            _requestId,
            _randomWords,
            s_requests[_requestId].paid
        );
        randomWordsNum = _randomWords[0];
    }

    function getRequestStatus(
        uint256 _requestId
    )
        external
        view
        returns (uint256 paid, bool fulfilled, uint256[] memory randomWords)
    {
        require(s_requests[_requestId].paid > 0, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.paid, request.fulfilled, request.randomWords);
    }

}
