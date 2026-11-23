// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract OmniLitFinanceV2 {
    uint256 public constant ZKL_PRICE_USD = 85;
    uint256 public constant SWAP_FEE_BPS = 30;
    uint256 public constant APY_BPS = 1850;
    uint256 public constant MAX_LTV_BPS = 6500;
    uint256 public constant YEAR_SECONDS = 365 days;

    uint256 public totalPoolZkl;
    uint256 public totalLpShares;
    uint256 public totalBridgedZkLink;

    struct UserVault {
        uint256 aUsdBalance;
        uint256 lpShares;
        uint256 stakedZkl;
        uint256 lastAccrual;
        uint256 accruedYield;
        uint256 borrowedUsd;
    }

    struct Proposal {
        uint256 id;
        string title;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 deadline;
        address proposer;
    }

    mapping(address => UserVault) private vaults;
    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event Swapped(address indexed user, uint256 zklIn, uint256 aUsdOut);
    event LiquidityAdded(address indexed user, uint256 zklIn, uint256 lpMinted);
    event LiquidityRemoved(address indexed user, uint256 lpBurned, uint256 zklOut);
    event Staked(address indexed user, uint256 amount);
    event YieldClaimed(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event ProposalCreated(uint256 indexed id, string title, address indexed proposer, uint256 deadline);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ZkLinkRelayed(address indexed user, string sourceChain, uint256 amount, bytes32 indexed txRef);

    constructor() {
        proposals.push(Proposal({
            id: 0,
            title: "Raise Max LTV from 65% to 70% on zkLTC Vault",
            yesVotes: 0,
            noVotes: 0,
            deadline: block.timestamp + 30 days,
            proposer: msg.sender
        }));
    }

    function _syncYield(address user) internal {
        UserVault storage v = vaults[user];
        if (v.lastAccrual == 0) {
            v.lastAccrual = block.timestamp;
            return;
        }
        uint256 dt = block.timestamp - v.lastAccrual;
        if (dt > 0 && v.stakedZkl > 0) {
            uint256 collateralUsd = v.stakedZkl * ZKL_PRICE_USD;
            uint256 earned = (collateralUsd * APY_BPS * dt) / (10000 * YEAR_SECONDS);
            v.accruedYield += earned;
        }
        v.lastAccrual = block.timestamp;
    }

    function pendingYield(address user) public view returns (uint256) {
        UserVault storage v = vaults[user];
        uint256 base = v.accruedYield;
        if (v.lastAccrual > 0 && v.stakedZkl > 0 && block.timestamp > v.lastAccrual) {
            uint256 dt = block.timestamp - v.lastAccrual;
            uint256 collateralUsd = v.stakedZkl * ZKL_PRICE_USD;
            base += (collateralUsd * APY_BPS * dt) / (10000 * YEAR_SECONDS);
        }
        return base;
    }

    function maxBorrowOf(address user) public view returns (uint256) {
        UserVault storage v = vaults[user];
        return (v.stakedZkl * ZKL_PRICE_USD * MAX_LTV_BPS) / 10000;
    }

    function swapZklForUsd() external payable {
        require(msg.value > 0, "Zero zkLTC");
        _syncYield(msg.sender);
        uint256 grossUsd = msg.value * ZKL_PRICE_USD;
        uint256 netUsd = (grossUsd * (10000 - SWAP_FEE_BPS)) / 10000;
        vaults[msg.sender].aUsdBalance += netUsd;
        totalPoolZkl += msg.value;
        emit Swapped(msg.sender, msg.value, netUsd);
    }

    function addLiquidity() external payable {
        require(msg.value > 0, "Zero zkLTC");
        _syncYield(msg.sender);
        uint256 denom = totalPoolZkl == 0 ? 1 : totalPoolZkl;
        uint256 minted = totalLpShares == 0 ? msg.value : (msg.value * totalLpShares) / denom;
        if (minted == 0) {
            minted = msg.value;
        }
        vaults[msg.sender].lpShares += minted;
        totalLpShares += minted;
        totalPoolZkl += msg.value;
        emit LiquidityAdded(msg.sender, msg.value, minted);
    }

    function removeLiquidity(uint256 lpAmount) external {
        UserVault storage v = vaults[msg.sender];
        require(lpAmount > 0 && v.lpShares >= lpAmount, "Insufficient LP");
        _syncYield(msg.sender);
        uint256 zklOut = totalLpShares > 0 ? (lpAmount * totalPoolZkl) / totalLpShares : lpAmount;
        if (zklOut > address(this).balance) zklOut = address(this).balance;
        v.lpShares -= lpAmount;
        totalLpShares -= lpAmount;
        if (totalPoolZkl >= zklOut) totalPoolZkl -= zklOut;
        payable(msg.sender).transfer(zklOut);
        emit LiquidityRemoved(msg.sender, lpAmount, zklOut);
    }

    function stakeZkl() external payable {
        require(msg.value > 0, "Zero zkLTC");
        _syncYield(msg.sender);
        vaults[msg.sender].stakedZkl += msg.value;
        emit Staked(msg.sender, msg.value);
    }

    function claimYield() external {
        _syncYield(msg.sender);
        uint256 amount = vaults[msg.sender].accruedYield;
        require(amount > 0, "No yield");
        vaults[msg.sender].accruedYield = 0;
        vaults[msg.sender].aUsdBalance += amount;
        emit YieldClaimed(msg.sender, amount);
    }

    function borrowUsd(uint256 aUsdAmount) external {
        require(aUsdAmount > 0, "Zero borrow");
        _syncYield(msg.sender);
        UserVault storage v = vaults[msg.sender];
        uint256 cap = maxBorrowOf(msg.sender);
        require(v.borrowedUsd + aUsdAmount <= cap, "Exceeds 65% LTV");
        v.borrowedUsd += aUsdAmount;
        v.aUsdBalance += aUsdAmount;
        emit Borrowed(msg.sender, aUsdAmount);
    }

    function repayUsd(uint256 aUsdAmount) external {
        require(aUsdAmount > 0, "Zero repay");
        _syncYield(msg.sender);
        UserVault storage v = vaults[msg.sender];
        uint256 debt = v.borrowedUsd < aUsdAmount ? v.borrowedUsd : aUsdAmount;
        require(debt > 0 && v.aUsdBalance >= debt, "Insufficient oUSD");
        v.aUsdBalance -= debt;
        v.borrowedUsd -= debt;
        emit Repaid(msg.sender, debt);
    }

    function createProposal(string calldata title, uint256 durationSeconds) external returns (uint256) {
        require(bytes(title).length > 0, "Empty title");
        uint256 dur = durationSeconds == 0 ? 7 days : durationSeconds;
        uint256 id = proposals.length;
        proposals.push(Proposal({
            id: id,
            title: title,
            yesVotes: 0,
            noVotes: 0,
            deadline: block.timestamp + dur,
            proposer: msg.sender
        }));
        emit ProposalCreated(id, title, msg.sender, block.timestamp + dur);
        return id;
    }

    function vote(uint256 proposalId, bool support) external {
        require(proposalId < proposals.length, "Invalid proposal");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        Proposal storage p = proposals[proposalId];
        require(block.timestamp <= p.deadline, "Voting ended");

        uint256 weight = vaults[msg.sender].stakedZkl + vaults[msg.sender].lpShares;
        if (weight == 0) weight = 1 ether;

        hasVoted[proposalId][msg.sender] = true;
        if (support) {
            p.yesVotes += weight;
        } else {
            p.noVotes += weight;
        }
        emit Voted(proposalId, msg.sender, support, weight);
    }

    function proposalCount() external view returns (uint256) {
        return proposals.length;
    }

    function getProposal(uint256 proposalId) external view returns (
        uint256 id,
        string memory title,
        uint256 yesVotes,
        uint256 noVotes,
        uint256 deadline,
        address proposer
    ) {
        Proposal storage p = proposals[proposalId];
        return (p.id, p.title, p.yesVotes, p.noVotes, p.deadline, p.proposer);
    }

    function relayFromZkLink(string calldata sourceChain, bytes32 txRef) external payable {
        require(msg.value > 0, "Zero amount");
        require(bytes(sourceChain).length > 0, "Missing source chain");
        _syncYield(msg.sender);
        vaults[msg.sender].aUsdBalance += (msg.value * ZKL_PRICE_USD * 997) / 1000;
        totalBridgedZkLink += msg.value;
        emit ZkLinkRelayed(msg.sender, sourceChain, msg.value, txRef);
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
        UserVault storage v = vaults[user];
        return (
            v.aUsdBalance,
            v.lpShares,
            v.stakedZkl,
            pendingYield(user),
            v.borrowedUsd,
            maxBorrowOf(user),
            proposals.length
        );
    }
}