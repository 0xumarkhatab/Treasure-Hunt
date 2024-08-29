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

                    ------------------------------------------------
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
                    -------------------------------------------------

# Introduction
Treasure Hunt is an on-chain lottery game where users can play, make the moves across the 10x10 board and Win ETH.

The User who makes the move on the position where treasury is located , wins 90% of contract's funds .

The Game board is a virtual 10x10 Grid where users jsut need to mention a position number from 0-99

Treasury Position is determined through provable fair randomness source .

## How to play ?
1. Users register themselves by paying `joinFee` in ETH by calling `JoinGame()` method to be elible for playing the game.
2. Once users are registered , they can call `move()` method with a minor `playFee` in ETH to make the move . This small fee is deliberate effort to prevent bot attacks.

When the move is made , new treasury position is re-calculated through provable fair randomness source which is `Chainlink VRF`.

If User's position is same as treasury , user wins and recieves 90% of total contract's Funds.

## Notable Things

1. `Create2` for deterministic deployment
2. `Keccak256` for storing the treasury position
3. `Chainlink Vrfs` for randomness source
4. `Foundry` for entire development and testing
5. `Sepolia` Testnet 
6. `Forge Std` cheats and VM members 




## Challenges and Design Choices

1. How do we store the treasure position ?

**Question** : What will be `Source of randomness` ?

**Solution** : block hash can be manipulated by miners , So , we have used `Chainlink VRFs`

**Question**  : Do we `Store Treasury position as a Plain number ?` But it can be read by anyone since the data is `public` on blockchain.

**Solution** : We have chosen to store `keccak256 of Treasury Position ` ✅


**Question** : Decision for `Valid moves` - allow wrap around moves  ? ✅

**Solution** : Keep things simple and allow only valid moves i.e you can not move left and up from top-left corner

**Question** : `Errors` as strings or Custom errors  ? 

**Solution** : Use `Custom errors for Gas optimization` ✅

**Question** : How much Assembly laguage for optimization ? Code readibility will be affected with so much Yul/

**Solution** : We `trade off code readability at the cost of some gas`

**Question** : `Variable packing` ?

**Solution** : Use hardened data types for variables and pack them up for gas optimization


## Gas Optimization 

### Before Gas Optimization

| TreasureHunt     |                 |        |        |        |         |
| ---------------- | --------------- | ------ | ------ | ------ | ------- |
| Deployment Cost  | Deployment Size |        |        |        |         |
| 1759243          | 8306            |        |        |        |         |
| Function Name    | min             | avg    | median | max    | # calls |
| GRID_SIZE        | 337             | 337    | 337    | 337    | 1       |
| getPossibleMoves | 2479            | 2479   | 2479   | 2479   | 3       |
| isRegistered     | 607             | 607    | 607    | 607    | 1       |
| joinFee          | 2394            | 2394   | 2394   | 2394   | 5       |
| joinGame         | 303357          | 304187 | 303357 | 320457 | 103     |
| move             | 28045           | 184176 | 184586 | 338802 | 6       |
| playFee          | 2374            | 2374   | 2374   | 2374   | 5       |
| players          | 645             | 645    | 645    | 645    | 3       |


### After Gas Optimization


| TreasureHunt     |                 |        |        |        |         |
| ---------------- | --------------- | ------ | ------ | ------ | ------- |
| Deployment Cost  | Deployment Size |        |        |        |         |
| 1679372          | 8242            |        |        |        |         |
| Function Name    | min             | avg    | median | max    | # calls |
| GRID_SIZE        | 337             | 337    | 337    | 337    | 1       |
| getPossibleMoves | 2479            | 2479   | 2479   | 2479   | 3       |
| isRegistered     | 607             | 607    | 607    | 607    | 1       |
| joinFee          | 2394            | 2394   | 2394   | 2394   | 5       |
| joinGame         | 303318          | 304148 | 303318 | 320418 | 103     |
| move             | 28045           | 184161 | 184571 | 338773 | 6       |
| playFee          | 2374            | 2374   | 2374   | 2374   | 5       |
| players          | 645             | 645    | 645    | 645    | 3       |



## Insights

We have improved `Deployment Cost` by `4.56%` which is good.
Further gas optimization can be done using `Yul` or `Huff` , however , i decided to 
`keep my code more readable at cost of some gas` 
              
_The Gas-Readibility tradeoff_




## Testing
I've written multiple tests to determine if the code is working as intended.

### 1. testJoinGame

### Command
```bash
forge test -vvvv --fork-url https://sepolia.infura.io/v3/YOUR_INFURA_API_KEY --mt testJoinGame
```

### Output
```bash
Ran 1 test for test/TreasureHunt.t.sol:TreasureHuntTest
[PASS] testJoinGame() (gas: 358604)
Traces:
  [358604] TreasureHuntTest::testJoinGame()
    ├─ [0] VM::startPrank(player1: [0x7026B763CBE7d4E72049EA67E89326432a50ef84])
    │   └─ ← [Return] 
    ├─ [2394] TreasureHunt::joinFee() [staticcall]
    │   └─ ← [Return] 100000000000000000 [1e17]
    ├─ [337289] TreasureHunt::joinGame{value: 100000000000000000}()
    │   ├─ [25548] 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46::calculateRequestPrice(100000 [1e5]) [staticcall]       
    │   │   ├─ [15902] 0x42585eD362B3f1BCa95c640FdFf35Ef899212734::latestRoundData() [staticcall]
    │   │   │   ├─ [7471] 0xd843B8B6313e87926783f5543241979D2cc9B12F::latestRoundData() [staticcall]
    │   │   │   │   └─ ← [Return] 0x00000000000000000000000000000000000000000000000000000000000015f3000000000000000000000000000000000000000000000000000feb3f2500d5a90000000000000000000000000000000000000000000000000000000066cf51240000000000000000000000000000000000000000000000000000000066cf513c00000000000000000000000000000000000000000000000000000000000015f3
    │   │   │   └─ ← [Return] 0x00000000000000000000000000000000000000000000000200000000000015f3000000000000000000000000000000000000000000000000000feb3f2500d5a90000000000000000000000000000000000000000000000000000000066cf51240000000000000000000000000000000000000000000000000000000066cf513c00000000000000000000000000000000000000000000000200000000000015f3  
    │   │   └─ ← [Return] 862926546877221342 [8.629e17]
    │   ├─ [164136] 0x779877A7B0D9E8603169DdbD7836e478b4624789::transferAndCall(0xab18414CD93297B0d12ac29E63Ca20f515b3DB46, 862926546877221342 [8.629e17], 0x00000000000000000000000000000000000000000000000000000000000186a000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000001)    
    │   │   ├─ emit Transfer(from: TreasureHunt: [0xa217C4fd524c3f2BABf88F6ebA577E64D5DE3752], to: 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46, value: 862926546877221342 [8.629e17])
    │   │   ├─ emit Transfer(param0: TreasureHunt: [0xa217C4fd524c3f2BABf88F6ebA577E64D5DE3752], param1: 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46, param2: 862926546877221342 [8.629e17], param3: 0x00000000000000000000000000000000000000000000000000000000000186a000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000001)
    │   │   ├─ [146386] 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46::onTokenTransfer(TreasureHunt: [0xa217C4fd524c3f2BABf88F6ebA577E64D5DE3752], 862926546877221342 [8.629e17], 0x00000000000000000000000000000000000000000000000000000000000186a000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000001)
    │   │   │   ├─ [3402] 0x42585eD362B3f1BCa95c640FdFf35Ef899212734::latestRoundData() [staticcall]
    │   │   │   │   ├─ [1471] 0xd843B8B6313e87926783f5543241979D2cc9B12F::latestRoundData() [staticcall]
    │   │   │   │   │   └─ ← [Return] 0x00000000000000000000000000000000000000000000000000000000000015f3000000000000000000000000000000000000000000000000000feb3f2500d5a90000000000000000000000000000000000000000000000000000000066cf51240000000000000000000000000000000000000000000000000000000066cf513c00000000000000000000000000000000000000000000000000000000000015f3
    │   │   │   │   └─ ← [Return] 0x00000000000000000000000000000000000000000000000200000000000015f3000000000000000000000000000000000000000000000000000feb3f2500d5a90000000000000000000000000000000000000000000000000000000066cf51240000000000000000000000000000000000000000000000000000000066cf513c00000000000000000000000000000000000000000000000200000000000015f3
    │   │   │   ├─ [37210] 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625::requestRandomWords(0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, 3, 3, 141588 [1.415e5], 1)
    │   │   │   │   ├─  emit topic 0: 0x63373d1c4696214b898952999c9aaec57dac1ee2723cec59bea6888f489a9772
    │   │   │   │   │        topic 1: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c
    │   │   │   │   │        topic 2: 0x0000000000000000000000000000000000000000000000000000000000000003
    │   │   │   │   │        topic 3: 0x000000000000000000000000ab18414cd93297b0d12ac29e63ca20f515b3db46
    │   │   │   │   │           data: 0x9ebfcd0681c0d56f7305298e54add9ef74e52a4b641350b38c9a990035c340da5ed95523653fab2b50195c8c7b02404cda7e54b099df2e1083010d0794b7d046000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000229140000000000000000000000000000000000000000000000000000000000000001
    │   │   │   │   └─ ← [Return] 0x9ebfcd0681c0d56f7305298e54add9ef74e52a4b641350b38c9a990035c340da
    │   │   │   └─ ← [Stop] 
    │   │   └─ ← [Return] true
    │   ├─ [383] 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46::lastRequestId() [staticcall]
    │   │   └─ ← [Return] 71804312898954145659793191040538048447013488750797019114235503382878830674138 [7.18e76]     
    │   ├─ [6548] 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46::calculateRequestPrice(100000 [1e5]) [staticcall]        
    │   │   ├─ [3402] 0x42585eD362B3f1BCa95c640FdFf35Ef899212734::latestRoundData() [staticcall]
    │   │   │   ├─ [1471] 0xd843B8B6313e87926783f5543241979D2cc9B12F::latestRoundData() [staticcall]
    │   │   │   │   └─ ← [Return] 0x00000000000000000000000000000000000000000000000000000000000015f3000000000000000000000000000000000000000000000000000feb3f2500d5a90000000000000000000000000000000000000000000000000000000066cf51240000000000000000000000000000000000000000000000000000000066cf513c00000000000000000000000000000000000000000000000000000000000015f3
    │   │   │   └─ ← [Return] 0x00000000000000000000000000000000000000000000000200000000000015f3000000000000000000000000000000000000000000000000000feb3f2500d5a90000000000000000000000000000000000000000000000000000000066cf51240000000000000000000000000000000000000000000000000000000066cf513c00000000000000000000000000000000000000000000000200000000000015f3  
    │   │   └─ ← [Return] 862926546877221342 [8.629e17]
    │   ├─ emit RequestSent(requestId: 71804312898954145659793191040538048447013488750797019114235503382878830674138 [7.18e76], numWords: 1)
    │   ├─ emit Joined_Game(player: player1: [0x7026B763CBE7d4E72049EA67E89326432a50ef84], timestamp: 1724865372 [1.724e9])
    │   └─ ← [Stop] 
    ├─ [607] TreasureHunt::isRegistered(player1: [0x7026B763CBE7d4E72049EA67E89326432a50ef84]) [staticcall]
    │   └─ ← [Return] true
    ├─ [0] VM::stopPrank()
    │   └─ ← [Return] 
    └─ ← [Stop]
```

## 2. test_MoveWithoutJoin

### Command 

```bash
forge test -vvvv --fork-url https://sepolia.infura.io/v3/YOUR_INFURA_API_KEY --mt test_MoveWithoutJoin
```

### Output

```bash
[PASS] test_MoveWithoutJoin() (gas: 24215)
Traces:
  [24215] TreasureHuntTest::test_MoveWithoutJoin()
    ├─ [0] VM::startPrank(player1: [0x7026B763CBE7d4E72049EA67E89326432a50ef84])
    │   └─ ← [Return] 
    ├─ [2374] TreasureHunt::playFee() [staticcall]
    │   └─ ← [Return] 10000000000000000 [1e16]
    ├─ [0] VM::expectRevert(PlayerNotRegistered())
    │   └─ ← [Return] 
    ├─ [2702] TreasureHunt::move{value: 10000000000000000}(1)
    │   └─ ← [Revert] PlayerNotRegistered()
    ├─ [0] VM::stopPrank()
    │   └─ ← [Return] 
    └─ ← [Stop] 
```
## 3. test_Move

### Command 
```bash
forge test -vvvv --fork-url https://sepolia.infura.io/v3/YOUR_INFURA_API_KEY --mt test_Move
```

### Output

```bash
[PASS] test_MoveWithoutJoin() (gas: 24215)
Traces:
  [24215] TreasureHuntTest::test_MoveWithoutJoin()
    ├─ [0] VM::startPrank(player1: [0x7026B763CBE7d4E72049EA67E89326432a50ef84])
    │   └─ ← [Return] 
    ├─ [2374] TreasureHunt::playFee() [staticcall]
    │   └─ ← [Return] 10000000000000000 [1e16]
    ├─ [0] VM::expectRevert(PlayerNotRegistered())
    │   └─ ← [Return] 
    ├─ [2702] TreasureHunt::move{value: 10000000000000000}(1)
    │   └─ ← [Revert] PlayerNotRegistered()
    ├─ [0] VM::stopPrank()
    │   └─ ← [Return] 
    └─ ← [Stop] 
```


## 4. test_DoubleMove

### Command 
```bash
forge test -vvvv --fork-url https://sepolia.infura.io/v3/YOUR_INFURA_API_KEY --mt test_DoubleMove
```

### Output

```shell
Traces:
  [613991] TreasureHuntTest::test_DoubleMove()
    ├─ [0] VM::startPrank(player1: [0x7026B763CBE7d4E72049EA67E89326432a50ef84])
    │   └─ ← [Return] 
    ├─ [2394] TreasureHunt::joinFee() [staticcall]
    │   └─ ← [Return] 100000000000000000 [1e17]
    ├─ [337289] TreasureHunt::joinGame{value: 100000000000000000}()
    # .....
    # .....
    # .....
    │   ├─ [6548] 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46::calculateRequestPrice(100000 [1e5]) [staticcall]        
    │   │   ├─ [3402] 0x42585eD362B3f1BCa95c640FdFf35Ef899212734::latestRoundData() [staticcall]
    │   │   │   ├─ [1471] 0xd843B8B6313e87926783f5543241979D2cc9B12F::latestRoundData() [staticcall]
    │   │   │   │   └─ ← [Return] 0x00000000000000000000000000000000000000000000000000000000000015f3000000000000000000000000000000000000000000000000000feb3f2500d5a90000000000000000000000000000000000000000000000000000000066cf51240000000000000000000000000000000000000000000000000000000066cf513c00000000000000000000000000000000000000000000000000000000000015f3
    │   │   │   └─ ← [Return] 0x00000000000000000000000000000000000000000000000200000000000015f3000000000000000000000000000000000000000000000000000feb3f2500d5a90000000000000000000000000000000000000000000000000000000066cf51240000000000000000000000000000000000000000000000000000000066cf513c00000000000000000000000000000000000000000000000200000000000015f3  
    │   │   └─ ← [Return] 904693236547808926 [9.046e17]
    │   ├─ emit RequestSent(requestId: 42676730018520229168644749431369625758034306310404332066897359734905694593821 [4.267e76], numWords: 1)
    │   ├─ emit Treasury_Updated(player: player1: [0x7026B763CBE7d4E72049EA67E89326432a50ef84], timestamp: 1724865768 
[1.724e9])
    │   └─ ← [Return] false
    ├─ [0] VM::expectRevert(OnlyOneMovePerBlock())
    │   └─ ← [Return] 
    ├─ [892] TreasureHunt::move{value: 10000000000000000}(10)
    │   └─ ← [Revert] OnlyOneMovePerBlock()
    ├─ [0] VM::stopPrank()
    │   └─ ← [Return] 
    └─ ← [Stop] 
```

## 5. test_InvalidMoves

### Command 
```bash
forge test -vvvv --fork-url https://sepolia.infura.io/v3/YOUR_INFURA_API_KEY --mt test_InvalidMoves
```

### Output

```bash
# ...
# ...
    │   │   └─ ← [Return] 959509729954724877 [9.595e17]
    │   ├─ emit RequestSent(requestId: 71804312898954145659793191040538048447013488750797019114235503382878830674138 [7.18e76], numWords: 1)
    │   ├─ emit Joined_Game(player: TreasureHuntTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], timestamp: 1724866056 [1.724e9])
    │   └─ ← [Stop] 
    ├─ [315] TreasureHunt::GRID_SIZE() [staticcall]
    │   └─ ← [Return] 10
    ├─ [2374] TreasureHunt::playFee() [staticcall]
    │   └─ ← [Return] 10000000000000000 [1e16]
    ├─ [0] VM::expectRevert(InvalidPosition())
    │   └─ ← [Return] 
    ├─ [3027] TreasureHunt::move{value: 10000000000000000}(101)
    │   └─ ← [Revert] InvalidPosition()
    └─ ← [Stop] 
```


## 6. testWinGame

### Command 
```bash
forge test -vvvv --fork-url https://sepolia.infura.io/v3/YOUR_INFURA_API_KEY --mt testWinGame
```

### Output

```java
[PASS] testWinGame() (gas: 24070849)
Logs:
  Winner is  0x7d577a597B2742b498Cb5Cf0C26cDCD726d39E6e
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 191.74s (179.20s CPU time)
```

## Conclusion
It was a fun challenge to refresh many aspects of the smart contract development World.

