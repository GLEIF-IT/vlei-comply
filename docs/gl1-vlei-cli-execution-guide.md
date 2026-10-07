# Local endorsement contract commands

Use a fresh local Anvil deployment. The registry accepts results from its
configured oracle writer; these commands demonstrate the contract API and do
not perform credential verification.

Build and deploy from a clean checkout:

```sh
./setup.sh
forge build
forge test
anvil
# In another terminal, use a public Anvil test key:
export PRIVATE_KEY='<Anvil test key>'
forge script script/DeployAll.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

Set `ORACLE_REGISTRY` and `RPC_URL` from this deployment, and select the exact
wallet, the canonical issuer AID, and the verified association SAID. The issuer
AID's Keccak-256 hash is the entity reference consumed by policy.

```sh
export IDENTITY_REF="$(cast keccak "$ISSUER_AID")"
cast send "$ORACLE_REGISTRY" 'publishEndorsement(address,bytes32,string)' \
  "$WALLET" "$IDENTITY_REF" "$ASSOCIATION_SAID" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
cast call "$ORACLE_REGISTRY" 'getEndorsement(address)((bytes32,string))' \
  "$WALLET" --rpc-url "$RPC_URL"
cast call "$ORACLE_REGISTRY" 'isEndorsed(address,bytes32)(bool)' \
  "$WALLET" "$IDENTITY_REF" --rpc-url "$RPC_URL"
```

Withdraw only the association whose source evidence was invalidated:

```sh
cast send "$ORACLE_REGISTRY" 'withdrawEndorsement(address,string)' \
  "$WALLET" "$ASSOCIATION_SAID" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
```

Publishing a new SAID replaces the current binding. Withdrawing the old SAID
then leaves the new binding intact. Chain scope is the deployment; the oracle
must verify the association's chain before submission. There is no separate
AID allowlist, LEI comparison, proof hash, or credential expiry in this registry.

`VLEIWalletAssociationPolicy` requires matching current endorsements for both
customer wallets. Register each wallet's identity hint in `IdentityRegistry`,
mint local test tokens and approve
`wUSDC` before calling `transfer(address,uint256)`. An unendorsed second wallet,
a withdrawn result, or a zero-wallet customer fails. The legacy signature POST
and AID-record fixture are incompatible with this contract interface.
