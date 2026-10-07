# Wallet association endorsements

`VLEIOracleRegistry` records the authorized oracle's result for one wallet on the
deployed chain. The oracle verifies the KERI/vLEI chain, current credential status,
embedded EOA proof, and account type off-chain. Solidity consumes an endorsement;
it does not verify vLEI evidence.

The wallet keys a current record containing only `identityRef` (the Keccak-256
hash of the canonical entity AID) and the exact `associationSaid` string. Presence
represents acceptance. No LEI, proof hash, expiry, timestamp, or per-record writer
is stored.

A `COMPLIANCE_ADMIN_ROLE` holder can call:

- `publishEndorsement(address,bytes32,string)` to publish or replace a binding;
- `withdrawEndorsement(address,string)` to remove that exact association;
- `getEndorsement(address)` to read the current identity and SAID;
- `isEndorsed(address,bytes32)` to check the current wallet/entity binding.

A late withdrawal of an older SAID cannot remove its replacement. Removing a
writer's role prevents future updates; it does not erase prior results. An
unrevoked binding does not expire as time advances. During oracle outages, stale
endorsements may remain usable without a separate governance freshness rule.

The legacy AID-record API is removed. Use fresh contracts. The policy consumer
currently rejects parties without an association-bound input; a wallet-to-AID
mapping alone supplies no authority.

## ABI and encoding

The registry ABI and publication vector are in `abi/`. Reproduce the ABI with:

```sh
forge build
forge inspect VLEIOracleRegistry abi --json > abi/VLEIOracleRegistry.json
```

The vector uses the protocol's public test association. `associationSaid` is
encoded directly as a Solidity string; `identityRef` is bytes32, and the wallet
is an address. Hashing the identity is representation, not evidence verification.
