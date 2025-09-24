# 🤝 Freelance Arbitration Contract

> 💼 **Secure escrow payments for freelancers and clients with decentralized dispute resolution**

A Clarity smart contract that provides secure escrow services for freelance work, featuring both single arbitrator and DAO-based dispute resolution mechanisms.

## 🌟 Features

- 🔒 **Secure Escrow**: Payments are held safely in the smart contract until work completion
- ⚖️ **Dual Arbitration Modes**: Choose between single arbitrator or DAO-based community resolution
- 🚀 **Instant Payments**: Immediate fund release upon client approval
- 🛡️ **Dispute Protection**: Built-in dispute resolution with time-bound voting
- 📊 **Transparent Process**: All contract states and disputes are publicly verifiable
- 💰 **Fair Fee Structure**: Configurable arbitration fees to incentivize fair resolution

## 🔧 Contract Functions

### 📝 Core Contract Operations

#### `create-contract`
Creates a new freelance contract with escrowed funds.
```clarity
(create-contract (freelancer principal) (amount uint) (arbitrator (optional principal)) (description (string-ascii 256)))
```
- **Parameters**: Freelancer address, STX amount, optional arbitrator, work description
- **Returns**: Contract ID
- **Effect**: Transfers STX to escrow, creates active contract

#### `complete-contract`
Completes a contract and releases funds to freelancer (client only).
```clarity
(complete-contract (contract-id uint))
```

#### `cancel-contract`
Cancels an active contract and refunds client (client only).
```clarity
(cancel-contract (contract-id uint))
```

### ⚔️ Dispute Resolution

#### `initiate-dispute`
Starts a dispute process for a contract (client or freelancer).
```clarity
(initiate-dispute (contract-id uint))
```

#### `resolve-dispute-single`
Resolves dispute via single arbitrator (arbitrator only, when DAO mode disabled).
```clarity
(resolve-dispute-single (contract-id uint) (favor-freelancer bool))
```

#### `vote-on-dispute`
Cast vote in DAO dispute resolution (registered arbitrators only, when DAO mode enabled).
```clarity
(vote-on-dispute (contract-id uint) (favor-freelancer bool))
```

#### `finalize-dao-dispute`
Finalizes DAO dispute after voting period ends.
```clarity
(finalize-dao-dispute (contract-id uint))
```

### 👥 Arbitrator Management

#### `add-arbitrator`
Registers a new arbitrator (contract owner only).
```clarity
(add-arbitrator (arbitrator principal))
```

#### `remove-arbitrator`
Removes an arbitrator (contract owner only).
```clarity
(remove-arbitrator (arbitrator principal))
```

#### `toggle-dao-mode`
Switches between single arbitrator and DAO dispute resolution (contract owner only).
```clarity
(toggle-dao-mode)
```

### 📊 Read-Only Functions

- `get-contract`: Retrieve contract details
- `get-arbitrator-info`: Check arbitrator status and reputation
- `get-dispute-tally`: View current dispute vote counts
- `get-contract-balance`: Check total contract STX balance
- `get-dao-status`: Check if DAO mode is enabled
- `get-arbitration-fee`: View current arbitration fee rate

## 🚀 Usage Guide

### For Clients 👔

1. **Create Contract**: Call `create-contract` with freelancer address, payment amount, and work description
2. **Monitor Progress**: Track contract status using `get-contract`
3. **Complete Work**: Call `complete-contract` when satisfied with deliverables
4. **Handle Disputes**: Use `initiate-dispute` if issues arise

### For Freelancers 💻

1. **Accept Work**: Receive contract ID from client
2. **Track Contract**: Monitor status with `get-contract`
3. **Deliver Work**: Complete project knowing payment is secured
4. **Dispute If Needed**: Call `initiate-dispute` for unfair treatment

### For Arbitrators ⚖️

1. **Get Registered**: Contract owner adds you via `add-arbitrator`
2. **Single Mode**: Resolve disputes directly with `resolve-dispute-single`
3. **DAO Mode**: Vote on disputes with `vote-on-dispute`
4. **Finalize**: Help finalize DAO disputes after voting period

## 🔄 Contract States

| State | Code | Description |
|-------|------|-------------|
| 🟢 Active | 0 | Contract created, work in progress |
| ✅ Completed | 1 | Work approved, funds released |
| 🔴 Disputed | 2 | Dispute initiated, awaiting resolution |
| ⚖️ Resolved | 3 | Dispute resolved, funds distributed |
| ❌ Cancelled | 4 | Contract cancelled, funds refunded |

## 🏗️ Development Setup

### Prerequisites
- [Clarinet](https://docs.hiro.so/stacks/clarinet-js-sdk) installed
- Node.js for testing

### Testing
```bash
# Check contract syntax
clarinet check

# Run tests
npm install
npm test
```

### Deployment
```bash
# Deploy to devnet
clarinet integrate

# Deploy to testnet
clarinet deploy --testnet
```

## 📋 Constants & Configuration

- **Dispute Duration**: 144 blocks (~24 hours)
- **Minimum Arbitrators**: 3 for DAO voting
- **Default Arbitration Fee**: 10% of contract amount
- **Contract Owner**: Deployer address

## 🛡️ Security Features

- ✅ **Access Control**: Function-level authorization checks
- ✅ **State Validation**: Strict state transition rules  
- ✅ **Time Bounds**: Dispute resolution deadlines
- ✅ **Vote Protection**: Single vote per arbitrator per dispute
- ✅ **Escrow Safety**: Funds locked until resolution

## 🤝 Contributing

Contributions welcome! Please ensure:
- Code follows Clarity best practices
- All tests pass with `clarinet check`
- Documentation is updated for new features

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

**Built with ❤️ for the freelance community using Stacks & Clarity**

# Freelance Arbitration Contract

