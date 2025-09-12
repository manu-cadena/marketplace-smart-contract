# Gas Optimizations and Security Measures

## Gas Optimizations Implemented:

1. **Custom Errors (50% gas savings on errors)**

   - Replaced string-based require statements with custom errors
   - Reduces deployment and execution costs

2. **External Function Visibility**

   - Used `external` instead of `public` where appropriate
   - Avoids unnecessary memory copying for external calls

3. **Calldata Parameter Storage**
   - Used `calldata` instead of `memory` for string parameters
   - Reads directly from transaction data, saving memory allocation costs

## Security Measures Implemented:

1. **Checks-Effects-Interactions Pattern**

   - Applied CEI pattern in all fund transfer functions
   - Prevents reentrancy attacks by updating state before external calls

2. **Secure ETH Transfers**

   - Used `call` instead of `transfer()` for ETH transfers
   - Better gas handling and error reporting

3. **Comprehensive Access Control**
   - Implemented role-based access with custom modifiers
   - Protected admin functions and user-specific operations
