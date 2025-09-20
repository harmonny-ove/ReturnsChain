# ReturnsChain

A decentralized platform for profit-sharing decisions and investor payout approvals built on the Stacks blockchain using Clarity smart contracts.

## Overview

ReturnsChain is a smart contract system that enables transparent and democratic profit distribution among investors. The platform allows registered investors to propose profit distributions, vote on proposals, and execute approved payouts based on consensus decisions.

## Features

- **Investor Registration**: Secure registration system with investment amount tracking and share percentage calculation
- **Proposal System**: Create proposals for profit distribution with automatic payout calculations
- **Democratic Voting**: Weighted voting system based on investment amounts with configurable approval thresholds
- **Automated Execution**: Proposals that meet approval requirements can be executed automatically
- **Transparent Tracking**: Complete audit trail of all investors, proposals, votes, and payouts
- **Access Control**: Owner-only administrative functions for investor management
- **Time-Based Proposals**: Proposals have expiration dates to ensure timely decision-making

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity v2
- **Epoch**: 2.5
- **Voting Threshold**: 60% approval required for proposal execution
- **Proposal Duration**: 144 blocks (~24 hours assuming 10-minute blocks)
- **Share Calculation**: Basis points precision (10,000 = 100%)

## Installation

### Prerequisites

- [Clarinet CLI](https://github.com/hirosystems/clarinet) installed
- Node.js v16 or higher
- Git

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd ReturnsChain
```

2. Navigate to the contract directory:
```bash
cd ReturnsChain_contract
```

3. Install dependencies:
```bash
npm install
```

4. Verify installation:
```bash
clarinet check
```

## Usage Examples

### Deploying the Contract

1. Configure your deployment settings in `settings/Devnet.toml`, `settings/Testnet.toml`, or `settings/Mainnet.toml`

2. Deploy to devnet:
```bash
clarinet integrate
```

3. Deploy to testnet/mainnet:
```bash
clarinet deploy --network testnet
```

### Interacting with the Contract

#### Register as an Investor

```clarity
(contract-call? .ReturnsChain register-investor u1000000) ;; 1 STX investment
```

#### Create a Profit Distribution Proposal

```clarity
(contract-call? .ReturnsChain create-proposal u500000) ;; 0.5 STX profit to distribute
```

#### Vote on a Proposal

```clarity
(contract-call? .ReturnsChain vote-on-proposal u1 true) ;; Vote 'yes' on proposal #1
```

#### Execute an Approved Proposal

```clarity
(contract-call? .ReturnsChain execute-proposal u1) ;; Execute proposal #1
```

## Contract Functions

### Public Functions

#### `register-investor (investment-amount uint)`
Registers a new investor with the specified investment amount.
- **Parameters**: `investment-amount` - Amount invested (in micro-STX)
- **Returns**: Investor ID on success
- **Requirements**: Amount must be greater than 0, address must not be already registered

#### `create-proposal (total-profit uint)`
Creates a new profit distribution proposal.
- **Parameters**: `total-profit` - Total profit amount to distribute
- **Returns**: Proposal ID on success
- **Requirements**: Must be a registered investor, profit amount must be greater than 0

#### `vote-on-proposal (proposal-id uint) (vote bool)`
Cast a vote on an active proposal.
- **Parameters**:
  - `proposal-id` - ID of the proposal to vote on
  - `vote` - true for approval, false for rejection
- **Returns**: Success confirmation
- **Requirements**: Must be registered investor, proposal must be active and not expired, cannot vote twice

#### `execute-proposal (proposal-id uint)`
Execute a proposal that has reached the approval threshold.
- **Parameters**: `proposal-id` - ID of the proposal to execute
- **Returns**: Success confirmation
- **Requirements**: Proposal must have ≥60% approval, must not be already executed

#### `deactivate-investor (investor-id uint)`
Deactivate an investor account (owner only).
- **Parameters**: `investor-id` - ID of investor to deactivate
- **Returns**: Success confirmation
- **Requirements**: Must be contract owner

### Read-Only Functions

#### `get-investor (investor-id uint)`
Retrieve investor information by ID.

#### `get-investor-by-address (address principal)`
Retrieve investor information by wallet address.

#### `get-proposal (proposal-id uint)`
Retrieve proposal details by ID.

#### `get-vote (proposal-id uint) (voter principal)`
Get a specific investor's vote on a proposal.

#### `get-payout (proposal-id uint) (investor-id uint)`
Get the calculated payout amount for an investor in a specific proposal.

#### `get-contract-stats ()`
Retrieve overall contract statistics including total investors and investments.

#### `is-proposal-approved (proposal-id uint)`
Check if a proposal has reached the approval threshold.

## Testing

Run the test suite:

```bash
npm test
```

Run tests with coverage and cost analysis:

```bash
npm run test:report
```

Watch mode for continuous testing:

```bash
npm run test:watch
```

## Deployment Guide

### Devnet Deployment

1. Start Clarinet console:
```bash
clarinet console
```

2. Deploy and interact with the contract in the REPL environment.

### Testnet Deployment

1. Configure testnet settings in `settings/Testnet.toml`
2. Fund your deployer account with testnet STX
3. Deploy:
```bash
clarinet deploy --network testnet
```

### Mainnet Deployment

1. Configure mainnet settings in `settings/Mainnet.toml`
2. Ensure deployer account has sufficient STX for deployment
3. Deploy:
```bash
clarinet deploy --network mainnet
```

## Security Considerations

### Access Controls
- Only registered investors can create proposals and vote
- Only the contract owner can deactivate investors
- Investors cannot vote multiple times on the same proposal

### Validation Checks
- Investment amounts must be positive
- Proposal amounts must be positive
- Proposals have expiration times to prevent stale votes
- Share percentages are automatically recalculated on new investor registration

### Known Limitations
- The current implementation includes placeholder functions for share recalculation and payout distribution
- Actual STX transfers are not implemented in the execute-proposal function
- Large numbers of investors may cause gas limit issues during share recalculation

### Recommended Practices
- Thoroughly test all functions on devnet before mainnet deployment
- Consider implementing batch processing for large investor bases
- Implement comprehensive error handling for edge cases
- Regular security audits are recommended before production use

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | `err-owner-only` | Function restricted to contract owner |
| 101 | `err-not-found` | Requested resource not found |
| 102 | `err-already-exists` | Resource already exists |
| 103 | `err-insufficient-balance` | Insufficient balance for operation |
| 104 | `err-unauthorized` | Unauthorized access attempt |
| 105 | `err-invalid-amount` | Invalid amount provided |
| 106 | `err-proposal-not-active` | Proposal is not in active state |
| 107 | `err-already-voted` | User has already voted on this proposal |
| 108 | `err-proposal-expired` | Proposal has expired |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the ISC License.

## Version

Current version: 1.0.0