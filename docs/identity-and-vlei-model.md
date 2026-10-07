# Identity And vLEI Model

The identity model uses Chainlink CCID as the on-chain identity key and interprets that key as the hash of a canonical KERI AID string.

```text
aidCcid = keccak256(bytes(canonicalAidString))
```

The canonical AID string is prepared off-chain. Solidity stores and compares only the bytes32 key and, in `VLEIOracleRegistry`, the raw string for inspection and event-driven indexing.

## Wallet-To-Identity Flow

For ordinary wallet transfers:

1. The maintainer/oracle registers `wallet -> aidCcid` in Chainlink `IdentityRegistry`.
2. `wUSDC.transfer` creates parties with wallet addresses and empty `identityRef`.
3. `PolicyManager` resolves `identityRef` using `ChainlinkCCIDIdentityAdapter.getBeneficiaryId(wallet)`.
4. The policy verifies the resulting `identityRef`.

## AID-Only Flow

For mediated transfers:

1. `wUSDC.transferWithBeneficiary` can create customer parties with `wallet == address(0)` and `identityRef != 0`.
2. `PolicyManager` treats the existing `identityRef` as authoritative and uses ID-based enrichment.
3. The verifier checks the same `identityRef` in `VLEIOracleRegistry`.

This is required for VASP or QVI scenarios where the on-chain wallet may represent an intermediary rather than the actual Legal Entity.

## Rotation Assumption

The model assumes the canonical KERI AID string used for `aidCcid` remains stable across key rotation.

## Chainlink Credential Registry

`CredentialRegistry` is deployed and available, but it is not authoritative for Legal Entity pass/fail.
The current verifier reads `VLEIOracleRegistry`.
