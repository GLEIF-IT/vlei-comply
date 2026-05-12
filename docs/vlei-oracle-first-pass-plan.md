# vLEI Oracle First-Pass Plan

## Summary

This first pass makes the generated vLEI compliance wrapper testable from the CLI with a real sender and beneficiary Legal Entity check.

The design keeps `wvLEI` as the enforcement shell, keeps Chainlink CCID identity lookup as the wallet-to-identity path, and adds a small on-chain `vLEIOracleRegistry` for oracle/admin-posted vLEI Legal Entity status.

The demo identity key is:

```text
aidCcid = keccak256(bytes(canonicalAidString))
```

The same `aidCcid` is registered as the Chainlink CCID and used as the `IPolicy.PartyPacket.identityRef`. This keeps the identifier stable across KERI key rotation as long as the canonical AID string remains stable.

## Contracts

- `AllowAllPolicyEngine`: dev-only Chainlink policy engine that allows local writes to proxy-initialized Chainlink registries.
- `vLEIOracleRegistry`: stores Legal Entity AID, entity LEI hash, LE credential subject LEI hash, LE ACDC SAID hash, proof hash, expiry, allowlist, and revocation state.
- `vLEIAttestationVerifier`: checks `party.identityRef` against `vLEIOracleRegistry`.
- `PolicyManager`: enriches parties by wallet and by existing `identityRef`, so AID-only `transferWithBeneficiary` parties can be evaluated.
- `vLEI_kyc_and_sanctions`: requires valid `OriginatorCustomer` and `BeneficiaryCustomer` Legal Entity records.

## CLI Demo Flow

Start Anvil:

```sh
anvil
```

Deploy:

```sh
export RPC_URL=http://127.0.0.1:8545
export PRIVATE_KEY=0x...first_anvil_private_key...

forge script script/DeployAll.s.sol:DeployAll \
  --rpc-url $RPC_URL \
  --broadcast
```

Capture the logged addresses:

```sh
export ADMIN=0x...
export IDENTITY_REGISTRY=0x...
export ORACLE_REGISTRY=0x...
export ASSET=0x...
export WRAPPER=0x...
```

Prepare accounts:

```sh
export ALICE=0x...
export ALICE_PK=0x...
export BOB=0x...
export ALICE_AID='E...alice-aid'
export BOB_AID='E...bob-aid'
export ALICE_CCID=$(cast keccak "$ALICE_AID")
export BOB_CCID=$(cast keccak "$BOB_AID")
```

Register Chainlink identities:

```sh
cast send $IDENTITY_REGISTRY "registerIdentity(bytes32,address,bytes)" \
  $ALICE_CCID $ALICE 0x --rpc-url $RPC_URL --private-key $PRIVATE_KEY

cast send $IDENTITY_REGISTRY "registerIdentity(bytes32,address,bytes)" \
  $BOB_CCID $BOB 0x --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

Mint and approve:

```sh
cast send $ASSET "mint(address,uint256)" $ALICE 1000000000000000000000 \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

cast send $ASSET "approve(address,uint256)" $WRAPPER 1000000000000000000000 \
  --rpc-url $RPC_URL --private-key $ALICE_PK
```

Allow wallet-level wrapper access:

```sh
cast send $ADMIN "setAllowed(address,bool)" $ALICE true \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

cast send $ADMIN "setAllowed(address,bool)" $BOB true \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

Expected failure before oracle records:

```sh
cast send $WRAPPER "transfer(address,uint256)" $BOB 1000000000000000000 \
  --rpc-url $RPC_URL --private-key $ALICE_PK
```

Post Alice and Bob LE records:

```sh
cast send $ORACLE_REGISTRY \
  "postLegalEntityRecord(string,string,string,bytes32,bytes32,uint40,uint40,bool,bool)" \
  "$ALICE_AID" "5493001KJTIIGC8Y1R12" "5493001KJTIIGC8Y1R12" \
  $(cast keccak "alice-acdc-said") $(cast keccak "alice-proof") 0 0 true false \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

cast send $ORACLE_REGISTRY \
  "postLegalEntityRecord(string,string,string,bytes32,bytes32,uint40,uint40,bool,bool)" \
  "$BOB_AID" "54930084UKLVMY22DS16" "54930084UKLVMY22DS16" \
  $(cast keccak "bob-acdc-said") $(cast keccak "bob-proof") 0 0 false false \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

Transfer still fails while Bob's AID is not allowlisted. Then allow Bob and retry:

```sh
cast send $ORACLE_REGISTRY "setAidAllowed(bytes32,bool)" $BOB_CCID true \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

cast send $WRAPPER "transfer(address,uint256)" $BOB 1000000000000000000 \
  --rpc-url $RPC_URL --private-key $ALICE_PK
```

Demonstrate revocation failure:

```sh
cast send $ORACLE_REGISTRY "setCredentialRevoked(bytes32,bool)" $ALICE_CCID true \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## Failure Modes

Transfers fail closed when:

- a wallet has no Chainlink CCID identity,
- an AID-only party has no `identityRef`,
- the oracle registry has no Legal Entity record for the AID/CCID,
- the AID is not allowlisted,
- the entity LEI is missing,
- the LE credential subject LEI hash does not match the entity LEI hash,
- the LE ACDC SAID hash is missing,
- the LE credential is expired,
- the LE credential is revoked.

## Future OOR Extension

This pass only validates Legal Entity AID and LE ACDC status. OOR support should keep the same pattern and add operation-specific constraints in `TransactionEnvelope.extraData`, including required LEI, required credential type, required position/scope, credential SAIDs, and oracle proof references.
