// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TokenVault V1 (UUPS Upgradeable)
 * @notice Basic deposit/withdraw vault with fee, using UUPS proxy pattern.
 * @dev Uses AccessControl for admin and upgrader roles. Storage layout MUST be preserved across upgrades.
 */
contract TokenVaultV1 is Initializable, UUPSUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /// @dev Roles
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @dev Token managed by the vault
    IERC20 internal _token;

    /// @dev Deposit fee in basis points (e.g., 500 = 5%)
    uint256 internal _depositFeeBps;

    /// @dev Total deposits credited (after fee)
    uint256 internal _totalDeposits;

    /// @dev Per-user internal credited balances
    mapping(address => uint256) internal _balances;

    /// @dev Storage gap for future upgrades. Keep at end. 50 slots in V1.
    uint256[50] private __gap;

    /// @dev Disable initializers on implementation
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the proxy instance
     * @param _tokenAddr ERC20 token address
     * @param _admin Address to be granted DEFAULT_ADMIN_ROLE and UPGRADER_ROLE
     * @param _depositFee Deposit fee in basis points (0-10000)
     */
    function initialize(address _tokenAddr, address _admin, uint256 _depositFee) external initializer {
        require(_tokenAddr != address(0), "TokenVaultV1: token addr zero");
        require(_admin != address(0), "TokenVaultV1: admin addr zero");
        require(_depositFee <= 10000, "TokenVaultV1: invalid fee");

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _token = IERC20(_tokenAddr);
        _depositFeeBps = _depositFee;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
    }

    /**
     * @notice Deposit tokens into the vault. Must approve first.
     * @param amount Amount of tokens to deposit
     */
    function deposit(uint256 amount) external virtual nonReentrant {
        require(amount > 0, "TokenVaultV1: amount=0");
        uint256 fee = (amount * _depositFeeBps) / 10000;
        uint256 netAmount = amount - fee;

        // Transfer tokens from user to vault
        _token.safeTransferFrom(msg.sender, address(this), amount);

        // Credit net to user's internal balance
        _balances[msg.sender] += netAmount;
        _totalDeposits += netAmount;

        emit Deposited(msg.sender, amount, fee, netAmount);
    }

    /**
     * @notice Withdraw tokens from internal balance
     * @param amount Amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "TokenVaultV1: amount=0");
        uint256 bal = _balances[msg.sender];
        require(bal >= amount, "TokenVaultV1: insufficient balance");

        _balances[msg.sender] = bal - amount;
        _totalDeposits -= amount;

        _token.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Get internal balance of a user
     */
    function balanceOf(address user) external view returns (uint256) {
        return _balances[user];
    }

    /**
     * @notice Get total credited deposits (after fees)
     */
    function totalDeposits() external view returns (uint256) {
        return _totalDeposits;
    }

    /**
     * @notice Get deposit fee in basis points
     */
    function getDepositFee() external view returns (uint256) {
        return _depositFeeBps;
    }

    /**
     * @notice Implementation version tag
     */
    function getImplementationVersion() external pure virtual returns (string memory) {
        return "V1";
    }

    /// @dev UUPS authorization
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /// @dev Events
    event Deposited(address indexed user, uint256 grossAmount, uint256 feeAmount, uint256 netAmount);
    event Withdrawn(address indexed user, uint256 amount);
}
