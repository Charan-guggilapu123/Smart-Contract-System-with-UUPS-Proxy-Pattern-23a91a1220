// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenVaultV2} from "./TokenVaultV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TokenVault V3 (UUPS Upgradeable)
 * @notice Extends V2 with withdrawal delay and emergency withdrawal mechanisms.
 */
contract TokenVaultV3 is TokenVaultV2 {
    using SafeERC20 for IERC20;
    constructor() {
        _disableInitializers();
    }
    struct WithdrawalRequest {
        uint256 amount;
        uint256 requestTime;
    }

    /// @dev Global withdrawal delay in seconds
    uint256 internal _withdrawalDelay;

    /// @dev Pending withdrawal per user
    mapping(address => WithdrawalRequest) internal _withdrawReq;

    /// @dev Storage gap reduced by 2 for new variables
    uint256[45] private __gapV3;

    /**
     * @notice Reinitializer for V3 to satisfy upgrades safety and allow future state wiring.
     * @dev Calls parent initializers to satisfy OpenZeppelin upgrades plugin validation.
     */
    function initializeV3() public reinitializer(3) {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
    }

    /**
     * @notice Set the global withdrawal delay (seconds). Admin-only.
     */
    function setWithdrawalDelay(uint256 _delaySeconds) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_delaySeconds >= 1 hours, "TokenVaultV3: delay too small");
        require(_delaySeconds <= 30 days, "TokenVaultV3: delay too large");
        _withdrawalDelay = _delaySeconds;
        emit WithdrawalDelayUpdated(_delaySeconds);
    }

    /**
     * @notice Get the global withdrawal delay (seconds)
     */
    function getWithdrawalDelay() external view returns (uint256) {
        return _withdrawalDelay;
    }

    /**
     * @notice Request a delayed withdrawal. Overwrites any pending request.
     */
    function requestWithdrawal(uint256 amount) external {
        require(amount > 0, "TokenVaultV3: amount=0");
        require(_balances[msg.sender] >= amount, "TokenVaultV3: insufficient balance");
        _withdrawReq[msg.sender] = WithdrawalRequest({amount: amount, requestTime: block.timestamp});
        emit WithdrawalRequested(msg.sender, amount, block.timestamp);
    }

    /**
     * @notice Execute a pending withdrawal after delay has elapsed.
     * @return amount withdrawn
     */
    function executeWithdrawal() external nonReentrant returns (uint256) {
        WithdrawalRequest memory req = _withdrawReq[msg.sender];
        require(req.amount > 0, "TokenVaultV3: no request");
        require(block.timestamp >= req.requestTime + _withdrawalDelay, "TokenVaultV3: delay not elapsed");

        // Clear request first to prevent reentrancy replay
        delete _withdrawReq[msg.sender];

        // Perform withdrawal using V1 logic semantics
        uint256 bal = _balances[msg.sender];
        require(bal >= req.amount, "TokenVaultV3: insufficient balance");
        _balances[msg.sender] = bal - req.amount;
        _totalDeposits -= req.amount;

        _token.safeTransfer(msg.sender, req.amount);
        emit WithdrawalExecuted(msg.sender, req.amount);
        return req.amount;
    }

    /**
     * @notice Emergency withdraw entire balance bypassing delay.
     * @dev Design choice: withdraw full balance and clear pending requests.
     */
    function emergencyWithdraw() external nonReentrant returns (uint256) {
        uint256 bal = _balances[msg.sender];
        require(bal > 0, "TokenVaultV3: no balance");
        delete _withdrawReq[msg.sender];
        _balances[msg.sender] = 0;
        _totalDeposits -= bal;
        _token.safeTransfer(msg.sender, bal);
        emit EmergencyWithdrawn(msg.sender, bal);
        return bal;
    }

    /**
     * @notice Get current withdrawal request for a user
     */
    function getWithdrawalRequest(address user) external view returns (uint256 amount, uint256 requestTime) {
        WithdrawalRequest memory req = _withdrawReq[user];
        return (req.amount, req.requestTime);
    }

    /**
     * @notice Version tag
     */
    function getImplementationVersion() external pure override returns (string memory) {
        return "V3";
    }

    /// @dev Events
    event WithdrawalDelayUpdated(uint256 delaySeconds);
    event WithdrawalRequested(address indexed user, uint256 amount, uint256 requestTime);
    event WithdrawalExecuted(address indexed user, uint256 amount);
    event EmergencyWithdrawn(address indexed user, uint256 amount);
}
