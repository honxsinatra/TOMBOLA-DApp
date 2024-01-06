// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

error Tombola__NotEnoughETHEntered();
error Tombola__TransferFailed();

contract Tombola is VRFConsumerBaseV2 {
    //State variable
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gaslane;
    uint64 private immutable i_subId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUMWORDS = 1;
    address payable public s_latestWinner;

    //Events
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event LatestPlayers();
    event winnerPicked(address indexed winner);

    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gaslane = keyHash;
        i_subId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function payLottery() public payable {
        if (msg.value < i_entranceFee) {
            revert Tombola__NotEnoughETHEntered();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable latestWinner = s_players[indexOfWinner];
        s_latestWinner = latestWinner;
        bool sendSuccess = payable(latestWinner).send(address(this).balance);
        if (!sendSuccess) revert Tombola__TransferFailed();
        emit winnerPicked(latestWinner);
    }

    function requestRandomWinner() external {
        uint256 request_Id = i_vrfCoordinator.requestRandomWords(
            i_gaslane,
            i_subId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUMWORDS
        );

        emit RequestedRaffleWinner(request_Id);
    }

    function showLatestWInner() public view returns (address) {
        return s_latestWinner;
    }

    function showLatestPlayers() public {
        emit LatestPlayers();
    }
}
