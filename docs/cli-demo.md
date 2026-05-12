# CLI Demo - DRAFT - not yet functional

This walkthrough demonstrates failure and success modes from the command line with Anvil, Forge, and Cast.

## Deploy

```sh
anvil
```

In another terminal:

```sh
export RPC_URL=http://127.0.0.1:8545
export PRIVATE_KEY=0x...first_anvil_private_key...

forge script script/DeployAll.s.sol:DeployAll \
  --rpc-url $RPC_URL \
  --broadcast
```

Capture the deployment output:

```sh
export ADMIN=0x...
export IDENTITY_REGISTRY=0x...
export ORACLE_REGISTRY=0x...
export ASSET=0x...
export WRAPPER=0x...
```

## Prepare Identities

```sh
export ALICE=0x...
export ALICE_PK=0x...
export BOB=0x...
export ALICE_AID='E...alice-aid'
export BOB_AID='E...bob-aid'
export ALICE_CCID=$(cast keccak "$ALICE_AID")
export BOB_CCID=$(cast keccak "$BOB_AID")
```

Register wallet identities in Chainlink `IdentityRegistry`:

```sh
cast send $IDENTITY_REGISTRY "registerIdentity(bytes32,address,bytes)" \
  $ALICE_CCID $ALICE 0x --rpc-url $RPC_URL --private-key $PRIVATE_KEY

cast send $IDENTITY_REGISTRY "registerIdentity(bytes32,address,bytes)" \
  $BOB_CCID $BOB 0x --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## Prepare Token Flow

```sh
cast send $ASSET "mint(address,uint256)" $ALICE 1000000000000000000000 \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

cast send $ASSET "approve(address,uint256)" $WRAPPER 1000000000000000000000 \
  --rpc-url $RPC_URL --private-key $ALICE_PK

cast send $ADMIN "setAllowed(address,bool)" $ALICE true \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

cast send $ADMIN "setAllowed(address,bool)" $BOB true \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## Expected Failures

Before oracle records exist:

```sh
cast send $WRAPPER "transfer(address,uint256)" $BOB 1000000000000000000 \
  --rpc-url $RPC_URL --private-key $ALICE_PK
```

The transaction succeeds at the EVM level but the wrapper returns false and emits policy failure. No token balance moves.

## Post Legal Entity Evidence

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

Bob is posted but not allowlisted, so transfer still fails. Allow Bob:

```sh
cast send $ORACLE_REGISTRY "setAidAllowed(bytes32,bool)" $BOB_CCID true \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

Retry:

```sh
cast send $WRAPPER "transfer(address,uint256)" $BOB 1000000000000000000 \
  --rpc-url $RPC_URL --private-key $ALICE_PK
```

## Revocation Failure

```sh
cast send $ORACLE_REGISTRY "setCredentialRevoked(bytes32,bool)" $ALICE_CCID true \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

Subsequent transfers fail closed until the record is unrevoked or reposted.
