// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {TreasureHunt} from "../src/TreasureHunt.sol";
import {StdCheatsSafe} from "forge-std/StdCheats.sol";
import {Vm} from "forge-std/Vm.sol";

contract TreasureHuntTest is Test {
    TreasureHunt treasureHunt;
    address player1 = makeAddr("player1");
    address player2 = makeAddr("player2");
    address player3 = makeAddr("player3");
    address player4 = makeAddr("player4");

    function setUp() public {
        treasureHunt = new TreasureHunt();
        vm.deal(player1, 100 ether);
        vm.deal(player2, 100 ether);
        vm.deal(player3, 100 ether);
        vm.deal(player4, 100 ether);
    }

    function testJoinGame() public {
        vm.startPrank(player1);

        treasureHunt.joinGame{value: treasureHunt.joinFee()}();
        // Check if the player is registered
        assert(treasureHunt.isRegistered(player1) == true);
        vm.stopPrank();
    }

    function test_MoveWithoutJoin() public {

        vm.startPrank(player1);
        // Join the game
        // treasureHunt.joinGame{value: treasureHunt.playFee()}();
        uint playFee = treasureHunt.playFee();

        vm.expectRevert(TreasureHunt.PlayerNotRegistered.selector);
        treasureHunt.move{value: playFee}(1); 
        vm.stopPrank();
    }

    function test_Move() public {
        vm.startPrank(player1);
        // Join the game
        treasureHunt.joinGame{value: treasureHunt.joinFee()}();
        (, uint position) = treasureHunt.players(player1);

        uint8[4] memory possible_moves = treasureHunt.getPossibleMoves(
            uint8(position)
        );
        uint playFee = treasureHunt.playFee();

        treasureHunt.move{value: playFee}(possible_moves[0]);

        vm.stopPrank();
    }

    function test_DoubleMove() public {
        vm.startPrank(player1);
        // Join the game
        treasureHunt.joinGame{value: treasureHunt.joinFee()}();
        (, uint position) = treasureHunt.players(player1);

        uint8[4] memory possible_moves = treasureHunt.getPossibleMoves(
            uint8(position)
        );
        uint playFee = treasureHunt.playFee();

        treasureHunt.move{value: playFee}(possible_moves[0]);

        vm.expectRevert(TreasureHunt.OnlyOneMovePerBlock.selector);
        treasureHunt.move{value: playFee}(10);
        vm.stopPrank();
    }

    function test_InvalidMoves() public {
        // Join the game
        treasureHunt.joinGame{value: treasureHunt.joinFee()}();

        uint8 grid_size = treasureHunt.GRID_SIZE();
        uint playFee = treasureHunt.playFee();

        vm.expectRevert(TreasureHunt.InvalidPosition.selector);
        treasureHunt.move{value: playFee}(grid_size * grid_size + 1); // Out of bounds
    }

    function testWinGame() public {
        // Join the game and move the treasure to the player's position
        address[4] memory players = [player1, player2, player3, player4];
        bool isWon = false;
        address winner = address(0);
        uint8 grid_size = treasureHunt.GRID_SIZE();
        uint playFee = treasureHunt.playFee();
        uint joinFee = treasureHunt.joinFee();
        // Starting at arbitrary block number
        vm.roll(216780000);

        uint8[4] memory possible_moves;
        while (!isWon) {
            for (uint i = 0; i < players.length; i++) {
                address currentPlayer = players[i];
                vm.startPrank(currentPlayer);
                vm.roll(block.number + 1);
                if (!treasureHunt.isRegistered(msg.sender)) {
                    treasureHunt.joinGame{value: joinFee}();
                }
                (, uint position) = treasureHunt.players(currentPlayer);
                possible_moves = treasureHunt.getPossibleMoves(uint8(position));

                // uint8 old_treasurePosition = treasureHunt.treasurePosition();

                isWon = treasureHunt.move{value: playFee}(possible_moves[0]);
                if (isWon) {
                    winner = currentPlayer;
                    // uint8 new_treasurePosition = treasureHunt
                    //     .treasurePosition();
                    // console.log(
                    //     "treasure positions : ",
                    //     old_treasurePosition,
                    //     new_treasurePosition
                    // );

                }

                vm.stopPrank();
            }
        }
    }

    // function testTreasureMovement() public {
    //     // Join the game
    //     treasureHunt.joinGame{value: treasureHunt.playFee()}();

    //     // Test treasure movement based on different conditions
    //     treasureHunt.move{value:playFee}(5); // Move to a multiple of 5
    //     treasureHunt.move{value:playFee}(7); // Move to a prime number

    //     // Ensure the treasure position has changed
    //     assertTrue(treasureHunt.treasurePosition() != 5);
    //     assertTrue(treasureHunt.treasurePosition() != 7);
    // }

    // Add more tests for other functions as needed
}
