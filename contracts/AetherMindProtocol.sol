// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract AetherMindProtocol {
    uint256 public constant RATE_NUM = 85; // 1 zkLTC = 85 aUSD
    uint256 public constant LTV_BPS = 6500; // 65% Max LTV
    uint256 public constant APY_BPS = 1920; // 19.20% APY
    uint256 public constant YEAR_SECONDS = 365 days;

    struct UserVault {
        uint256 aUsdBalance;
        uint256 lpShares;
        uint256 stakedZkl;
        uint256 accruedYield;
        uint256 borrowedUsd;
        uint256 lastUpdate;
        uint256 aiSignalsLogged;
    }

    struct AiSignal {
        address user;
        bytes32 strategyHash;
        uint256 riskScore;
        uint256 timestamp;
    }

    mapping(address => UserVault) public vaults;
    AiSignal[] public aiSignals;

    uint256 public totalPoolZkl;
    uint256 public totalStakedZkl;

    event Swapped(address indexed user, uint256 zklIn, uint256 aUsdOut);
    event LiquidityAdded(address indexed user, uint256 zklIn, uint256 lpMinted);
    event LiquidityRemoved(address indexed user, uint256 lpBurned, uint256 zklOut);
    event Staked(address indexed user, uint256 amount);
    event YieldClaimed(address indexed user, uint256 aUsdReward);
    event Borrowed(address indexed user, uint256 aUsdAmount);
    event Repaid(address indexed user, uint256 aUsdAmount);
    event AiStrategyCommitted(uint256 indexed signalId, address indexed user, bytes32 strategyHash, uint256 riskScore);

    modifier syncYield(address user) {
        UserVault storage v = vaults[user];
        if (v.lastUpdate > 0 && v.stakedZkl > 0) {
            uint256 elapsed = block.timestamp - v.lastUpdate;
            uint256 yearlyUsd = (v.stakedZkl * RATE_NUM * APY_BPS) / 10000;
            v.accruedYield += (yearlyUsd * elapsed) / YEAR_SECONDS;
        }
        v.lastUpdate = block.timestamp;
        _;
    }

    function swapZklForUsd() external payable syncYield(msg.sender) {
        require(msg.value > 0, "Zero zkLTC");
        uint256 netZkl = (msg.value * 997) / 1000;
        uint256 usdOut = netZkl * RATE_NUM;
        vaults[msg.sender].aUsdBalance += usdOut;
        emit Swapped(msg.sender, msg.value, usdOut);
    }

    function addLiquidity() external payable syncYield(msg.sender) {
        require(msg.value > 0, "Zero liquidity");
        vaults[msg.sender].lpShares += msg.value;
        totalPoolZkl += msg.value;
        emit LiquidityAdded(msg.sender, msg.value, msg.value);
    }

    function removeLiquidity(uint256 lpAmount) external syncYield(msg.sender) {
        UserVault storage v = vaults[msg.sender];
        require(lpAmount > 0 && v.lpShares >= lpAmount, "Insufficient LP");
        v.lpShares -= lpAmount;
        totalPoolZkl -= lpAmount;
        uint256 sendAmt = address(this).balance >= lpAmount ? lpAmount : address(this).balance;
        if (sendAmt > 0) {
            (bool ok, ) = payable(msg.sender).call{value: sendAmt}("");
            require(ok, "Transfer failed");
        }
        emit LiquidityRemoved(msg.sender, lpAmount, sendAmt);
    }

    function stakeZkl() external payable syncYield(msg.sender) {
        require(msg.value > 0, "Zero stake");
        vaults[msg.sender].stakedZkl += msg.value;
        totalStakedZkl += msg.value;
        emit Staked(msg.sender, msg.value);
    }

    function claimYield() external syncYield(msg.sender) {
        UserVault storage v = vaults[msg.sender];
        uint256 reward = v.accruedYield;
        require(reward > 0, "No yield yet");
        v.accruedYield = 0;
        v.aUsdBalance += reward;
        emit YieldClaimed(msg.sender, reward);
    }

    function borrowUsd(uint256 aUsdAmount) external syncYield(msg.sender) {
        require(aUsdAmount > 0, "Zero borrow");
        UserVault storage v = vaults[msg.sender];
        uint256 maxBorrow = (v.stakedZkl * RATE_NUM * LTV_BPS) / 10000;
        require(v.borrowedUsd + aUsdAmount <= maxBorrow, "Exceeds 65% LTV");
        v.borrowedUsd += aUsdAmount;
        v.aUsdBalance += aUsdAmount;
        emit Borrowed(msg.sender, aUsdAmount);
    }

    function repayUsd(uint256 aUsdAmount) external syncYield(msg.sender) {
        UserVault storage v = vaults[msg.sender];
        require(aUsdAmount > 0 && v.borrowedUsd >= aUsdAmount, "Invalid repay");
        require(v.aUsdBalance >= aUsdAmount, "Insufficient aUSD");
        v.aUsdBalance -= aUsdAmount;
        v.borrowedUsd -= aUsdAmount;
        emit Repaid(msg.sender, aUsdAmount);
    }

    function commitAiStrategy(bytes32 strategyHash, uint256 riskScore) external syncYield(msg.sender) returns (uint256 id) {
        require(strategyHash != bytes32(0), "Empty hash");
        require(riskScore <= 100, "Risk 0-100");
        id = aiSignals.length;
        aiSignals.push(AiSignal({
            user: msg.sender,
            strategyHash: strategyHash,
            riskScore: riskScore,
            timestamp: block.timestamp
        }));
        vaults[msg.sender].aiSignalsLogged += 1;
        emit AiStrategyCommitted(id, msg.sender, strategyHash, riskScore);
    }

    function getVaultState(address user) external view returns (
        uint256 aUsdBalance,
        uint256 lpShares,
        uint256 stakedZkl,
        uint256 liveYield,
        uint256 borrowedUsd,
        uint256 maxBorrowUsd,
        uint256 aiSignalsLogged
    ) {
        UserVault memory v = vaults[user];
        uint256 pending = v.accruedYield;
        if (v.lastUpdate > 0 && v.stakedZkl > 0) {
            uint256 elapsed = block.timestamp - v.lastUpdate;
            uint256 yearlyUsd = (v.stakedZkl * RATE_NUM * APY_BPS) / 10000;
            pending += (yearlyUsd * elapsed) / YEAR_SECONDS;
        }
        uint256 maxB = (v.stakedZkl * RATE_NUM * LTV_BPS) / 10000;
        return (v.aUsdBalance, v.lpShares, v.stakedZkl, pending, v.borrowedUsd, maxB, v.aiSignalsLogged);
    }

    function totalAiSignals() external view returns (uint256) {
        return aiSignals.length;
    }

    receive() external payable {
        vaults[msg.sender].stakedZkl += msg.value;
        totalStakedZkl += msg.value;
    }
}
