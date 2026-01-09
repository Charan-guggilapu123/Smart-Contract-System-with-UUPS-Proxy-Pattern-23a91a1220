# TokenVault UUPS Upgradeable System (V1 → V3)

Production-grade upgradeable smart contract system implementing a TokenVault protocol using the UUPS (Universal Upgradeable Proxy Standard) pattern. Includes V1 (deposit/withdraw with fee), V2 (yield accrual + pause controls), and V3 (withdrawal delay + emergency withdrawal), with strict storage layout management, secure initialization, and role-based access control.

## Installation

```bash
npm install
npx hardhat compile
```

## Running Tests

```bash
npx hardhat test
npx hardhat coverage
```

## Project Structure

- contracts/
	- TokenVaultV1.sol
	- TokenVaultV2.sol
	- TokenVaultV3.sol
	- mocks/MockERC20.sol
- test/
	- TokenVaultV1.test.js
	- upgrade-v1-to-v2.test.js
	- upgrade-v2-to-v3.test.js
	- security.test.js
- scripts/
	- deploy-v1.js
	- upgrade-to-v2.js
	- upgrade-to-v3.js
- hardhat.config.js
- package.json
- submission.yml

## Deployment & Upgrades

Deploy V1 (includes a mock token for local use):

```bash
npx hardhat run scripts/deploy-v1.js
```

Upgrade to V2:

```bash
set PROXY_ADDRESS=0xYourProxy
npx hardhat run scripts/upgrade-to-v2.js
```

Upgrade to V3:

```bash
set PROXY_ADDRESS=0xYourProxy
npx hardhat run scripts/upgrade-to-v3.js
```

## Access Control

- DEFAULT_ADMIN_ROLE: Admin can grant/revoke roles and manage parameters
- UPGRADER_ROLE: Authorized to perform UUPS upgrades
- PAUSER_ROLE (V2+): Authorized to pause/unpause deposits

Granting roles (example):

```js
const PAUSER_ROLE = await vault.PAUSER_ROLE();
await vault.grantRole(PAUSER_ROLE, admin);
```

## Storage Layout Strategy

- V1 defines core state and a 50-slot storage gap: `uint256[50] __gap;`
- V2 appends 3 new variables (yield rate, lastClaim mapping, pause flag) and reduces gap to 47.
- V3 appends 2 new variables (withdrawalDelay, withdrawalRequests mapping) and reduces gap to 45.
- No reordering or type changes across versions; only append.

## Initialization Security

- No constructors in implementation contracts (constructor only calls `_disableInitializers()`).
- `initialize()` protected by `initializer` modifier on proxy instances.
- Reinitializers can be added for future versions; current design uses default zero-initialization for new vars.

## Business Logic

- Deposit Fee (V1): Fee deducted in basis points; total deposits reflect net amount.
- Yield (V2): `yield = balance * rate * timeElapsed / (365 days * 10000)`; credited via `claimYield()`; timestamps tracked per user.
- Withdraw Delay (V3): Users `requestWithdrawal(amount)`; must wait `withdrawalDelay` before `executeWithdrawal()`; single pending request; `emergencyWithdraw()` bypasses delay by withdrawing full balance.

## Known Limitations

- Yield is credited from internal accounting; ensure contract token solvency in production.
- Consider timelock/multisig for admin and upgrader roles in production.
- Add more granular roles (e.g., YIELD_MANAGER) in complex deployments.

## Production Deployment Considerations

### Pre-Deployment Checklist

1. **Multi-Signature Setup**
   - Deploy Gnosis Safe or similar multi-sig wallet
   - Minimum 3-of-5 signers for DEFAULT_ADMIN_ROLE
   - Separate multi-sig (2-of-3) for UPGRADER_ROLE
   - Grant PAUSER_ROLE to incident response team

2. **Timelock Configuration**
   - Deploy OpenZeppelin TimelockController
   - Set minimum delay: 48 hours for upgrades
   - Route all admin actions through timelock
   - Document emergency bypass procedures

3. **Testnet Validation**
   - Deploy to Sepolia/Goerli testnet
   - Execute full upgrade cycle V1→V2→V3
   - Perform load testing with realistic scenarios
   - Verify state preservation across upgrades
   - Test emergency withdrawal under stress

4. **Security Measures**
   - Professional audit by Consensys/Trail of Bits/OpenZeppelin
   - Bug bounty program ($50K+ rewards)
   - Formal verification of critical invariants
   - Rate limiting on deposits/withdrawals

### Monitoring & Alerting

**Critical Metrics:**
- Vault token balance vs. total deposits + accrued yield
- Pending withdrawal request count and total value
- Unauthorized upgrade attempts
- Abnormal deposit/withdrawal patterns
- Role changes (especially UPGRADER_ROLE grants)

**Alert Triggers:**
- Vault reserve ratio < 110% of total deposits
- >10 failed withdrawal executions in 1 hour
- Any unauthorized access control changes
- Yield rate modifications
- Withdrawal delay parameter changes

**Monitoring Tools:**
- Tenderly for real-time transaction monitoring
- OpenZeppelin Defender for automated security checks
- Grafana dashboards for metrics visualization
- PagerDuty integration for critical alerts

### Upgrade Governance Process

1. **Proposal Phase** (7 days)
   - Publish upgrade proposal with diff
   - Technical documentation of changes
   - Community discussion period
   - Security audit of new implementation

2. **Approval Phase** (48 hours)
   - Multi-sig voting on timelock transaction
   - Required: 3-of-5 admin approvals
   - Publish on-chain vote results

3. **Execution Phase**
   - Timelock delay expires (minimum 48 hours)
   - Execute upgrade transaction
   - Monitor for 24 hours post-upgrade
   - Prepare rollback if issues detected

4. **Post-Upgrade Validation**
   - Verify all state preserved correctly
   - Test new functionality in production
   - Monitor gas costs and performance
   - Update documentation and user guides

### Emergency Procedures

**Incident Response Team:**
- On-call rotation: 24/7 coverage
- Response time SLA: < 15 minutes
- Escalation path documented
- Regular drill exercises

**Emergency Actions:**
1. **Deposit Pause** (PAUSER_ROLE): Immediate effect
2. **Circuit Breaker**: Halt all operations if reserves < 100%
3. **Upgrade Rollback**: Revert to previous version via proxy admin
4. **Emergency Withdrawal**: Allow users to exit without delay

**Rollback Procedure:**
```javascript
// 1. Identify issue and get multi-sig approval
// 2. Retrieve previous implementation address
const previousImpl = await upgrades.erc1967.getImplementationAddress(proxyAddress);

// 3. Execute rollback via UPGRADER_ROLE
await proxy.upgradeTo(previousImplementationAddress);

// 4. Verify state integrity
await verifyAllBalances();
await verifyAccessControl();
```

### Operational Best Practices

1. **Key Management**
   - Hardware wallets for all multi-sig signers
   - Geographically distributed signers
   - Regular key rotation schedule
   - Backup key recovery procedures

2. **Access Control Hygiene**
   - Principle of least privilege
   - Regular access review (quarterly)
   - Revoke unused roles immediately
   - Log all role changes on-chain and off-chain

3. **Documentation**
   - Maintain upgrade history log
   - Document all parameter changes
   - Keep runbooks for common operations
   - Update architecture diagrams after upgrades

4. **Testing Strategy**
   - Shadow mode: Run new version alongside old
   - Canary deployments: Small user subset first
   - Gradual rollout with monitoring
   - Automated regression testing post-upgrade

## Submission

Automated evaluation uses `submission.yml` with `npm install`, `hardhat compile`, `hardhat test`, and `hardhat coverage`.
# Smart-Contract-System-with-UUPS-Proxy-Pattern-23a91a1220