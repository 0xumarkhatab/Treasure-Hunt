// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
 
 
                | 1  | 2  | 3  | 4  |  5 |  6 |  7 |  8 |  9 |  10 |
                | 11 | 💰 | 13 | 14 | 15 | 16 | 17 | 💰 | 19 |  20 |
                | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 |  30 |
                | 31 | 32 | 33 | 34 | 35 | 36 | 37 | 38 | 39 |  40 |
                | 41 | 42 | 43 | 44 | 💰 | 46 | 47 | 48 | 49 |  50 |
                | 51 | 52 | 53 | 54 | 55 | 56 | 57 | 58 | 59 |  60 |
                | 61 | 62 | 63 | 64 | 65 | 66 | 67 | 68 | 69 |  70 |
                | 71 | 72 | 73 | 74 | 75 | 76 | 77 | 💰 | 79 |  80 |
                | 81 | 💰 | 83 | 84 | 85 | 86 | 87 | 88 | 89 |  90 |
                | 91 | 92 | 93 | 94 | 95 | 96 | 97 | 98 | 99 | 100 |  
 
 Name     : On Chain Treasure Hunt Game
 Version  : 1.0
 Author   : 0xumarkhatab
 email    : umarkhatabfrl at gmail.com
 Liscense : MIT
 
*/

contract TreasureHunt {
    //  ////////////////////////
    //      State Variables
    // //////////////////////////

    // Size of the game grid (10x10)
    uint8 public constant GRID_SIZE = 10;

    // percentage of the total ETH balance that the winner receives (90%)
    uint256 public constant TREASURE_REWARD_PERCENT = 90;

    // current position hash of the treasure on the grid - to avoid reading the secret position directly
    bytes32 treasurePosition;
    uint256 public totalEth; // total amount of ETH deposited by all players
    /**
        Fees :
        1. Joing Fee : Every user needs to pay a joining/registration Fee to be able to take part in the game
        2. Each time a user wants to play , they have to make a small payment too to prevent volumetric attacks by Bots
     */
    uint256 public joinFee = 0.1 ether;
    uint256 public playFee = 0.01 ether;

    //  ////////////////////////
    //      Struct Definitions
    // //////////////////////////

    struct Player {
        address address_; // player's Ethereum address
        uint8 position; // player's current position on the grid
    }

    //  ////////////////////////
    //      Mappings Definitions
    // //////////////////////////

    mapping(address => Player) public players;
    mapping(address => uint) public lastPlayedBlockNumber;
    mapping(address => bool) public isRegistered;

    //  ////////////////////////
    //      Events
    // //////////////////////////

    event Joined_Game(address player, uint timestamp);
    event Won_Game(address player, uint timestamp, uint amount);
    event Treasury_Updated(address player, uint timestamp);

    //  ////////////////////////
    //      Custom Erros
    // //////////////////////////

    error InsufficientPlayFee();
    error InsufficientJoinFee();
    error PlayerNotRegistered();
    error OnlyOneMovePerBlock();
    error InvalidPosition();
    error InvalidMove();

    //  ////////////////////////
    //      External Methods
    // //////////////////////////

    constructor() {
        // Set the initial position of the treasure to a random number based on the block number
        uint rand = uint256(keccak256(abi.encodePacked(block.number)));
        assign_treasure_position(uint8(rand));
    }

    // Follows CEI
    function joinGame() external payable {
        // This function allows a player to join the game
        // It requires the player to send ETH to join
        if (msg.value < joinFee) {
            revert InsufficientJoinFee();
        }

        totalEth += msg.value;
        // Register the player
        isRegistered[msg.sender] = true;
        //  Assign a random position to user
        uint8 rand = uint8(
            (uint256(keccak256(abi.encodePacked(block.number))) %
                (GRID_SIZE * GRID_SIZE)) + 1
        );
        players[msg.sender].position = rand;
        emit Joined_Game(msg.sender, block.timestamp);
    }

    function move(uint8 newPosition) external payable returns (bool) {
        bool isWon = false;
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
        if (!(newPosition > 0 && newPosition <= GRID_SIZE * GRID_SIZE)) {
            revert InvalidPosition();
        }

        // Check if the move is valid (adjacent to the current position)
        if (!isValidMove(players[msg.sender].position, newPosition)) {
            revert InvalidMove();
        }

        // Update the player's position
        players[msg.sender].position = newPosition;
        lastPlayedBlockNumber[msg.sender] = block.number;
        // Move the treasure based on the rules
        moveTreasure(newPosition);

        // Check if the player has won

        if ( keccak256( abi.encodePacked(players[msg.sender].position)) == treasurePosition ) {
            // Calculate the reward and transfer it to the winner
            uint256 reward = (totalEth * TREASURE_REWARD_PERCENT) / 100;
            payable(msg.sender).transfer(reward);
            totalEth -= reward;
            isWon = true;
            // moveTreasure(newPosition);
        }
        return isWon;
    }



    //  ////////////////////////
    //      Public Methods
    // //////////////////////////

    // This function checks if a move is valid (adjacent to the current position)
    // It checks if the new position is within the grid and if the difference between the current and new positions is 1 or -1 (up, down, left, or right)
    /**

                | 1  | 2  | 3  | 4  |  5 |  6 |  7 |  8 |  9 |  10 |
                | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |  20 |
                | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 |  30 |
                | 31 | 32 | 33 | 34 | 35 | 36 | 37 | 38 | 39 |  40 |
                | 41 | 42 | 43 | 44 | 45 | 46 | 47 | 48 | 49 |  50 |
                | 51 | 52 | 53 | 54 | 55 | 56 | 57 | 58 | 59 |  60 |
                | 61 | 62 | 63 | 64 | 65 | 66 | 67 | 68 | 69 |  70 |
                | 71 | 72 | 73 | 74 | 75 | 76 | 77 | 78 | 79 |  80 |
                | 81 | 82 | 83 | 84 | 85 | 86 | 87 | 88 | 89 |  90 |
                | 91 | 92 | 93 | 94 | 95 | 96 | 97 | 98 | 99 | 100 |  
        
Possible Moves :

        For 3 ->
        3+10 = 1
        3-10 = -7 x
        3+1 = 4
        3-1 = 2

        For 10 ->
        10+10 = 20
        10-10 = 0 x
        10+1 = 11 ,10%10=0 x
        10-1 = 9 

        For 60 ->
        60+10
        60-10
        60-1 = 59
        60+1 = 61 , 60%10 = 0 x

        For 100 ->
        100 + 10 = 110 x
        100-10 = 90
        100+1 =101 , 100%10 =0 x
        100-1 = 99

        For 95 ->
        95+10=105
        95-10=85
        95+1 = 96
        95-1=94

        For 91 -> 

        91+10 =101 x
        91-10 =81 
        91+1 = 92
        91-1 =91 %10 = 1 x


         left ( difference is -1 )
         right ( difference is +1 )
         up ( minus GridSize )
         Down ( + GridSize )
         They are valid moves in General,
         check `getPossibleMoves method
 
         */

    function isValidMove(
        uint8 currentPosition,
        uint8 newPosition
    ) public returns (bool) {
        uint8[4] memory possible_moves = getPossibleMoves(currentPosition);
        for (uint8 i = 0; i < possible_moves.length; i++) {
            if ((newPosition) == possible_moves[i]) {
                return true;
            }
        }
        return false;
    }

    function getPossibleMoves(
        uint8 position
    ) public view returns (uint8[4] memory) {
        uint8[4] memory possibleMoves = [0, 0, 0, 0];
        uint8 idx = 0;
        if (
            position + GRID_SIZE > 0 &&
            position + GRID_SIZE <= GRID_SIZE * GRID_SIZE
        ) possibleMoves[idx++] = (position + GRID_SIZE);
        if (position >= GRID_SIZE && position - GRID_SIZE > 0)
            possibleMoves[idx++] = (position - GRID_SIZE);
        if (position + 1 > 0 && position % 10 != 0)
            possibleMoves[idx++] = (position + 1);
        if (position - 1 > 0 && position % 10 != 1)
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
            rand = getRandomAdjacentPosition(newMove);
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
        uint8 position
    ) internal returns (uint8) {
        // This function gets a random adjacent position to the current position
        // It generates a random direction (0, 1, 2, 3 for up, right, down, left) and calculates the new position based on the direction
        uint8 direction = uint8(
            uint256(keccak256(abi.encodePacked(position, block.timestamp))) % 4
        );

        if (direction == 0) {
            return position - GRID_SIZE; // Move up
        } else if (direction == 1) {
            return position + 1; // Move right
        } else if (direction == 2) {
            return position + GRID_SIZE; // Move down
        } else {
            return position - 1; // Move left
        }
    }

    function getRandomPosition() internal view returns (uint8) {
        // This function gets a random position on the grid
        // It generates a random number using the block hash and timestamp and maps it to a grid position

        // Needs to be replaced by chainlink VRF call

        uint source_rnd = uint256(
            keccak256(abi.encodePacked(block.number, msg.sender))
        );

        uint8 randomNumber = (uint8(
            uint256(keccak256(abi.encodePacked(source_rnd)))
        ) % (GRID_SIZE * GRID_SIZE)) + 1;

        return randomNumber;
    }
}
