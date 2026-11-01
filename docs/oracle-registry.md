# Wallet association endorsements

`VLEIOracleRegistry` records the authorized oracle's result for one wallet on the
deployed chain. [EOA Verifier](https://github.com/GLEIF-IT/eoa-verifier/tree/master/protocol) owns
credential/proof verification and association acceptance. [Oracle API v1](https://github.com/GLEIF-IT/vlei-oracle/blob/main/protocol/oracle-api-v1/README.md)
owns trusted receipt, selection and publication. Solidity consumes their authorized
result; it does not receive credentials or association nonces.

The wallet keys a current record containing only `identityRef` (the Keccak-256
hash of the canonical entity AID) and the exact `associationSaid` string. Presence
represents a published endorsement. No LEI, proof hash, expiry, timestamp, or
per-record writer is stored.

Public reads are unrestricted. A `COMPLIANCE_ADMIN_ROLE` holder may write:

- `publishEndorsement(address,bytes32,string)` to publish or replace an endorsement;
- `withdrawEndorsement(address,string)` to remove that exact association;

Anyone may call:

- `getEndorsement(address)` to read the current identity and SAID;
- `isEndorsed(address,bytes32)` to check the current wallet/entity endorsement.

A late withdrawal of an older SAID cannot remove its replacement. Removing a
writer's role prevents future updates; it does not erase prior results. An
unrevoked association does not expire as time advances. Delivery or oracle outages
can leave an endorsement usable until revocation reaches the contract. There is
no periodic source/account recheck in this build.

The policy consumer requires the exact wallet and entity to match the current
endorsement. A wallet-to-AID mapping alone supplies no authority.

## ABI and encoding

The registry ABI and publication vector are in `abi/`. Reproduce the ABI with:

```sh
forge build
forge inspect VLEIOracleRegistry abi --json > abi/VLEIOracleRegistry.json
```

The vector uses the protocol's public test association. `associationSaid` is
encoded directly as a Solidity string; `identityRef` is bytes32, and the wallet
is an address. Hashing the identity is representation, not evidence verification.

## Events and trust

`EndorsementPublished(address indexed wallet, bytes32 indexed identityRef, string
associationSaid)` records publish/replacement. Successful exact-SAID withdrawal
emits `EndorsementWithdrawn` with the same arguments. A mismatched withdrawal
returns false without removing state. Publishing rejects zero wallet, zero
identityRef and empty association SAID. Both write methods check the compliance
admin role; reads do not. Revoking a writer role does not clear existing mappings.

For canonical entity AID `issuerAid`, encode `identityRef` as
`keccak256(UTF-8(issuerAid))`. Do not hash an LEI or LE credential SAID instead.
`associationSaid` is the exact credential SAID as a Solidity string, not a bytes32
conversion. Chain scope comes from deployment. The authorized writer is trusted;
contracts cannot establish credential validity or notice undelivered revocation.


## Forward delivery contract

The supported operating model has one Oracle writer per deployment and preserved
Oracle storage. Association authority flows from EOA Verifier to Oracle to these
registries. The Oracle records its own confirmed effects and completes each
posting operation. It does not periodically read these mappings, discover changes
made by other writers, or repair them automatically. Public contract reads remain
available to policy consumers and observers.

First publication registers identity before endorsement. A change of entity
withdraws the previous endorsement, removes the old identity, registers the new
identity, then publishes the new endorsement. Each is a separate transaction;
intermediate states need not pass compliance. A same-entity replacement needs only
publication of the new SAID. Revocation withdraws the exact SAID and can leave the
identity hint intact. Repeated or delayed withdrawal cannot clear a successor.

Oracle's GET `/v1/endorsements/{associationSaid}` reports local delivery progress
and its last confirmed effect, not freshly queried chain truth. A failed or
uncertain RPC does not erase a prior contract record or invalidate a credential.
Bounded retries end in an off-chain dead letter for manual intervention. A signed
transaction may still land after its caller times out; no second transaction may
bypass an unresolved writer nonce. There is no compensating on-chain workflow,
back-propagation, or automatic expiry. Deployment starts from known empty
association state; preserving the Oracle store is part of this operating model.
