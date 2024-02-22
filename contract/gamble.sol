// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

contract Tombola is VRFConsumerBaseV2, AutomationCompatibleInterface {
    //Type
    enum TombolaStatus {
        OPEN,
        CLOSED
    }
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
    TombolaStatus private s_tombolaStatus;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    //Events
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event LatestPlayers();
    event winnerPicked(address indexed winner);

    //Errors
    error Tombola__NotEnoughETHEntered(string message);
    error Tombola__TransferFailed(string message);
    error Tombola__Status(string message);
    error Tombola__UpKeepNotRequired(string message);

    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gaslane = keyHash;
        i_subId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_tombolaStatus = TombolaStatus.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    function performUpkeep(bytes calldata /*perfomeData*/) external override {
        (bool upkeepNeeded, ) = checkUpkeep(bytes(""));
        if (!upkeepNeeded) {
            revert Tombola__UpKeepNotRequired("Upkeep conditions not met");
        }

        s_tombolaStatus = TombolaStatus.CLOSED;
        uint256 request_Id = i_vrfCoordinator.requestRandomWords(
            i_gaslane,
            i_subId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUMWORDS
        );

        emit RequestedRaffleWinner(request_Id);
    }

    function payLottery() public payable {
        if (msg.value < i_entranceFee) {
            revert Tombola__NotEnoughETHEntered(
                "Insufficient payment for entrance fee"
            );
        }
        if (s_tombolaStatus != TombolaStatus.OPEN) {
            revert Tombola__Status("Please wait for the next round");
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev This function is invoked by Chainlink Keeper nodes to determine if upkeep is needed, and it returns true when the following conditions are met:
     *1. The subscription must be true.
     *2. The specified time interval should have elapsed.
     *3. There must be at least one player.
     *4. There should be a non-zero amount of ETH.
     *5. The lottery should be in ""Open" state.
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /*performData*/)
    {
        bool isOpen = (s_tombolaStatus == TombolaStatus.OPEN);
        bool hasTimePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = (address(this).balance > 0);
        upkeepNeeded = (isOpen && hasTimePassed && hasPlayers && hasBalance);
    }

    function showLatestWInner() public view returns (address) {
        return s_latestWinner;
    }

    function showLatestPlayers() public {
        emit LatestPlayers();
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable latestWinner = s_players[indexOfWinner];
        s_latestWinner = latestWinner;
        s_tombolaStatus = TombolaStatus.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        bool sendSuccess = payable(latestWinner).send(address(this).balance);
        if (!sendSuccess) revert Tombola__TransferFailed("Transfer failed");
        emit winnerPicked(latestWinner);
    }
}
