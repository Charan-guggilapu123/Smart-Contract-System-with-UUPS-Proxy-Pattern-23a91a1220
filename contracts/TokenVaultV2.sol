// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenVaultV1} from "./TokenVaultV1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TokenVault V2 (UUPS Upgradeable)
 * @notice Extends V1 with yield accrual and deposit pause controls.
 */
contract TokenVaultV2 is TokenVaultV1 {
    using SafeERC20 for IERC20;
    constructor() {
        _disableInitializers();
    }
    /// @dev Basis points annual yield rate (e.g., 500 = 5%)
    uint256 internal _yieldRateBps;

    /// @dev Last claim timestamp per user
    mapping(address => uint256) internal _lastClaim;

    /// @dev Pause flag for deposits
    bool internal _depositsPaused;

    /// @dev Storage gap reduced by 3 for new variables
    uint256[47] private __gapV2;

    /**
     * @notice Reinitializer for V2 to satisfy upgrades safety and allow future state wiring.
     * @dev Calls parent initializers to satisfy OpenZeppelin upgrades plugin validation.
     */
    function initializeV2() public reinitializer(2) {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
    }

    /**
     * @notice Set yield rate (bps). Admin-only.
     */
    function setYieldRate(uint256 _yieldRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_yieldRate <= 10000, "TokenVaultV2: invalid rate");
        _yieldRateBps = _yieldRate;
        emit YieldRateUpdated(_yieldRate);
    }

    /**
     * @notice Get current yield rate (bps)
     */
    function getYieldRate() external view returns (uint256) {
        return _yieldRateBps;
    }

    /**
     * @notice Compute user's pending yield based on time since last claim
     */
    function getUserYield(address user) public view returns (uint256) {
        uint256 balance = _balances[user];
        if (balance == 0) return 0;
        uint256 since = _lastClaim[user];
        uint256 start = since == 0 ? block.timestamp : since;
        // If never claimed, assume no elapsed time; yield accrues only after first deposit/claim tick.
        if (since == 0) return 0;
        uint256 dt = block.timestamp - start;
        // yield = balance * rate * dt / (365 days * 10000)
        return (balance * _yieldRateBps * dt) / (365 days * 10000);
    }

    /**
     * @notice Claim accrued yield. Credits to internal balance (non-compounding externally) and updates timestamps.
     * @dev Returns claimed amount.
     */
    function claimYield() external nonReentrant returns (uint256) {
        uint256 since = _lastClaim[msg.sender];
        if (since == 0) {
            // First interaction: initialize claim timestamp, no immediate yield
            _lastClaim[msg.sender] = block.timestamp;
            emit YieldClaimed(msg.sender, 0);
            return 0;
        }
        uint256 amount = getUserYield(msg.sender);
        _lastClaim[msg.sender] = block.timestamp;
        if (amount > 0) {
            // Ensure vault has sufficient reserves to pay yield
            require(_token.balanceOf(address(this)) >= _totalDeposits + amount, 
                    "TokenVaultV2: insufficient reserves for yield");
            _balances[msg.sender] += amount;
            _totalDeposits += amount;
        }
        emit YieldClaimed(msg.sender, amount);
        return amount;
    }

    /**
     * @notice Pause deposits. PAUSER_ROLE only.
     */
    function pauseDeposits() external onlyRole(PAUSER_ROLE) {
        _depositsPaused = true;
        emit DepositsPaused(msg.sender);
    }

    /**
     * @notice Unpause deposits. PAUSER_ROLE only.
     */
    function unpauseDeposits() external onlyRole(PAUSER_ROLE) {
        _depositsPaused = false;
        emit DepositsUnpaused(msg.sender);
    }

    /**
     * @notice Are deposits paused?
     */
    function isDepositsPaused() external view returns (bool) {
        return _depositsPaused;
    }

    /**
     * @notice Override deposit to enforce pause control and initialize claim timestamp.
     */
    function deposit(uint256 amount) external override nonReentrant {
        require(!_depositsPaused, "TokenVaultV2: deposits paused");
        require(amount > 0, "TokenVaultV1: amount=0");
        uint256 fee = (amount * _depositFeeBps) / 10000;
        uint256 netAmount = amount - fee;
        _token.safeTransferFrom(msg.sender, address(this), amount);
        _balances[msg.sender] += netAmount;
        _totalDeposits += netAmount;
        if (_lastClaim[msg.sender] == 0) {
            _lastClaim[msg.sender] = block.timestamp;
        }
        emit Deposited(msg.sender, amount, fee, netAmount);
    }

    /**
     * @notice Version tag
     */
    function getImplementationVersion() external pure virtual override returns (string memory) {
        return "V2";
    }

    /// @dev Additional role for pausing
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @dev Events
    event YieldRateUpdated(uint256 yieldRateBps);
    event YieldClaimed(address indexed user, uint256 amount);
    event DepositsPaused(address indexed by);
    event DepositsUnpaused(address indexed by);
}
