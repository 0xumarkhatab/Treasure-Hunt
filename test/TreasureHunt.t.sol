// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {TreasureHunt} from "../src/TreasureHunt.sol";
import {StdCheatsSafe} from "forge-std/StdCheats.sol";
import {Vm} from "forge-std/Vm.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";

contract TreasureHuntTest is Test {
    TreasureHunt treasureHunt;
    // Making two addresses
    address owner = makeAddr("owner");
    address player1 = makeAddr("player1");

    // Sepolia addresses
    MockERC20 linkToken = MockERC20(0x779877A7B0D9E8603169DdbD7836e478b4624789);
    address wrapperAddress = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;

    function setUp() public {
        // Owner gets 100 Link tokens
        deal(address(linkToken), owner, 10e18 ether);
        vm.deal(player1, 100 ether);
        deal(address(linkToken), player1, 100 ether);

        vm.startPrank(owner);
        // Deploy treasure Hunt Using Create2

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

        vm.stopPrank();
    }

    /**
     *  Create2 Methods
     */
    function getBytecode() public pure returns (bytes memory) {
        return type(TreasureHunt).creationCode;
    }

    //compute the deployment address
    function computeAddress(
        bytes memory _byteCode,
        uint256 _salt,
        address _owner
    ) public pure returns (address) {
        bytes32 hash_ = keccak256(
            abi.encodePacked(bytes1(0xff), _owner, _salt, keccak256(_byteCode))
        );
        return address(uint160(uint256(hash_)));
    }

    //deploy the contract and check the event for the deployed address
    function deployTreasureHunt(
        bytes memory _byteCode,
        uint256 _salt
    ) public payable returns (address depAddr) {
        assembly {
            depAddr := create2(
                callvalue(),
                add(_byteCode, 0x20),
                mload(_byteCode),
                _salt
            )

            if iszero(extcodesize(depAddr)) {
                revert(0, 0)
            }
        }
    }

    /**
     *
     */

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
        (, uint8 position) = treasureHunt.players(player1);
        uint playFee = treasureHunt.playFee();

        uint8[4] memory possible_moves = treasureHunt.getPossibleMoves(
            position
        );
        treasureHunt.move{value: playFee}(possible_moves[0]);

        vm.stopPrank();
    }

    function test_DoubleMove() public {
        vm.startPrank(player1);
        // Join the game
        treasureHunt.joinGame{value: treasureHunt.joinFee()}();
        (, uint8 position) = treasureHunt.players(player1);

        uint playFee = treasureHunt.playFee();

        uint8[4] memory possible_moves = treasureHunt.getPossibleMoves(
            position
        );
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
        address[99] memory players;

        uint playFee = treasureHunt.playFee();
        uint joinFee = treasureHunt.joinFee();
        // Starting at arbitrary block number
        vm.roll(2980);
        for (uint160 i = 0; i < 99; i++) {
            players[i] = makeAddr(vm.toString(i + 1));
            vm.deal(players[i], 100 ether);
            vm.startPrank(players[i]);
            treasureHunt.joinGame{value: joinFee}();
            vm.stopPrank();
        }

        bool isWon = false;
        address winner = address(0);
        uint8[4] memory possible_moves;
        // int k=0;
        // while(!isWon && k<4){
        for (uint i = 0; i < players.length && isWon == false; i++) {
            address currentPlayer = players[i];
            vm.startPrank(currentPlayer);
            vm.roll(block.number + 1);
            (, uint8 position) = treasureHunt.players(currentPlayer);
            possible_moves = treasureHunt.getPossibleMoves(position);
            //  If no possible moves are found
            if (possible_moves[0] == type(uint8).max) continue;

            isWon = treasureHunt.move{value: playFee}(possible_moves[0]);
            if (isWon) {
                winner = currentPlayer;
            }

            vm.stopPrank();
        }
        // k+=1;
        // }

        console.log("Winner is ", winner);
    }
}
