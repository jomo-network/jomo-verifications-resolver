# VerificationsResolver

## Usage

1. Make schema like `bytes32 key,address mintTo`

2. Create attestation using schemaID create above

3. User scan QR code and call EAS `attest` function to update attestations information

4. OptimistAllowlist should upgrade to add VerificationsResolver as parameter. [OptimistAllowlist](./src/op-nft/OptimistAllowlist.sol)

5. User can mint Optimist through `mint` function

## Test

`forge clean && forge build && forge test --ffi -vvv`
