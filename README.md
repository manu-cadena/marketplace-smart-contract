# Marketplace Smart Contract

A secure, gas-optimized marketplace smart contract built with Solidity and Foundry for the BCU24D smart contracts course.

## Project Overview

This marketplace contract implements a complete escrow-based trading system where users can list items, purchase them securely, and resolve disputes through admin mediation. The contract prioritizes security, gas efficiency, and comprehensive functionality.

## Development Journey

This project initially began as a Hardhat-based development setup. However, during the deployment phase, I encountered verification issues with the Hardhat deployment workflow on the Sepolia testnet. The contract compiled and deployed successfully, but the verification process on Etherscan consistently failed due to configuration mismatches.

To ensure successful deployment and verification for the assignment requirements, I migrated the entire project to **Foundry**. This migration involved:

1. **Framework Migration**: Converting from Hardhat to Foundry for deployment and testing
2. **Test Rewrite**: Translating comprehensive TypeScript test suites to Solidity using Foundry's testing framework
3. **Deployment Success**: Successfully deployed and verified the contract on Sepolia using Foundry's streamlined deployment process

The migration proved beneficial, as Foundry provided:

- More reliable deployment and verification workflows
- Faster compilation and testing
- Better gas reporting and optimization tools
- Native Solidity testing environment

## Contract Features

### Core Functionality

- **Item Listing**: Users can list items with name, description, and price
- **Secure Purchasing**: Escrow-based payment system with multiple safety checks
- **Order Management**: Complete order lifecycle from purchase to delivery
- **Dispute Resolution**: Admin-mediated dispute resolution system
- **Admin Management**: Multi-admin system with proper access controls

### Security Features

- **Custom Error Handling**: Gas-efficient error reporting with custom errors
- **Access Control**: Role-based permissions with custom modifiers
- **Reentrancy Protection**: Following Checks-Effects-Interactions pattern
- **Input Validation**: Comprehensive validation for all user inputs
- **Safe ETH Transfers**: Using call() with proper error handling

### Gas Optimizations

- **Storage Packing**: Efficient struct packing to minimize storage slots
- **Custom Errors**: Gas-efficient error handling over string messages
- **Memory vs Storage**: Optimal data location choices
- **Function Visibility**: External functions for gas savings where appropriate

## Deployment Information

**Network**: Sepolia Testnet  
**Contract Address**: `0x034C4fb0E62396D57543BB4a4388Db9baB02DaB5`  
**Verified Contract**: https://sepolia.etherscan.io/address/0x034c4fb0e62396d57543bb4a4388db9bab02dab5  
**Deployment Transaction**: `0xe2b7abffa4d82bf7ed5d7733363f9afdb7b3f6ae548ca8f70082cf217f2d718c`

## Testing

The project includes comprehensive test coverage with **95.70% statement coverage** across 48 test cases covering:

- Deployment and initialization
- Admin management functionality
- Item listing and validation
- Purchase workflows and edge cases
- Order management (shipping, delivery, cancellation)
- Dispute raising and resolution
- Utility functions and error handling
- Fallback and receive function behavior
- Security edge cases

### Running Tests

```bash
# Run all tests
forge test

# Run tests with verbose output
forge test -vv

# Generate coverage report
forge coverage

# Run tests with gas reporting
forge test --gas-report
```

## Project Structure

```
├── src/
│   └── Marketplace.sol          # Main contract
├── test/
│   └── Marketplace.t.sol        # Comprehensive test suite
├── lib/                         # Foundry dependencies
├── GAS_OPTIMIZATIONS.md         # Detailed optimization documentation
└── foundry.toml                 # Foundry configuration
```

## Technical Requirements Fulfilled

### Grade Level G Requirements ✅

- **Struct/Enum**: Item and Order structs, ItemStatus and OrderStatus enums
- **Mapping/Array**: Multiple mappings for efficient data access
- **Constructor**: Initializes deployer as admin
- **Custom Modifier**: `onlyAdmin` access control modifier
- **Events**: Comprehensive event logging for all major actions
- **Test Coverage**: 95.70% statement coverage (exceeds 40% requirement)

### Grade Level VG Requirements ✅

- **Error Handling**: Custom errors, require, assert, and revert statements
- **Fallback/Receive**: Handles direct ETH transfers and unknown function calls
- **Deployed & Verified**: Successfully deployed and verified on Sepolia
- **Advanced Coverage**: 95.70% coverage (exceeds 90% requirement)
- **Gas Optimizations**: Multiple optimizations documented and implemented

## Gas Optimizations

The contract implements several gas optimization techniques detailed in `GAS_OPTIMIZATIONS.md`:

1. **Custom Errors**: Replacing string error messages with custom errors
2. **Storage Packing**: Efficient struct layout to minimize storage slots
3. **Function Visibility**: Using external over public where appropriate
4. **Memory Usage**: Optimal memory vs storage usage patterns
5. **Checks-Effects-Interactions**: Security pattern that also optimizes gas

## Security Considerations

- **Reentrancy Protection**: Safe external calls using CEI pattern
- **Access Control**: Proper admin role management
- **Input Validation**: Comprehensive validation on all parameters
- **Safe Transfers**: Using call() with proper success checks
- **State Management**: Careful order state transitions

## Build and Deploy

```bash
# Install dependencies
forge install

# Compile contracts
forge build

# Deploy to Sepolia (requires .env configuration)
forge create --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verify \
    src/Marketplace.sol:Marketplace \
    --broadcast
```

## Environment Setup

Create a `.env` file with:

```
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key_here
```

## License

MIT License
