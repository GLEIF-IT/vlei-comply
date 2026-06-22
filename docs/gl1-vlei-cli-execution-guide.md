# GL1 USDC CLI Execution Guide

This guide is the human-operated walkthrough for the local GL1 compliance
prototype. It assumes the local infrastructure is already started and focuses
on using that infrastructure to understand the originator-to-beneficiary flow.

Use this guide when you want to see how an Ethereum wallet becomes connected to
a KERI AID, how that AID is tied to vLEI evidence, how the oracle posts compact
evidence on chain, and why `wUSDC` blocks or allows a transfer.

For service startup, ports, cleanup, and troubleshooting, use
[Local Infrastructure Setup](gl1-vlei-local-infra-setup.md). For the fully
automated proof, use the sibling oracle script:

```sh
cd ../vlei-oracle
./scripts/e2e/gl1-wallet-transfer-e2e.sh
```

## What You Are Proving

The compliance path is:

```text
Ethereum wallet
  -> Chainlink CCID wallet mapping
  -> KERI Legal Entity AID CCID
  -> vLEI Oracle Registry evidence
  -> wUSDC policy pass
  -> compliant transfer
```

The credential path that feeds the oracle is:

```text
single-sig GEDA
  -> QVI
  -> Legal Entity
  -> Official Organizational Role
  -> GL1 Ethereum Wallet Attestation
  -> vLEI Oracle
  -> vlei-comply contracts
```

Two parties participate:

- originator Legal Entity, OOR, and Ethereum wallet
- beneficiary Legal Entity, OOR, and Ethereum wallet

The important mental model is that wallet allowlisting and vLEI evidence are
separate controls. `AdminControls.setAllowed(wallet, true)` lets a wallet use
the wrapper, but the vLEI policy still fails until the oracle has posted
AID-keyed evidence and the admin has allowlisted those AID CCIDs.

## Start The Local Stack

From `vlei-comply`, start the reusable infrastructure:

```sh
scripts/dev/start-local-gl1-stack.sh start
source runs/local-gl1-stack/stack.env
```

This starts or reuses `kli witness demo`, `vLEI-server`, and Anvil, deploys
`vlei-comply`, parses contract addresses, and writes `stack.env`. It does not
assume the GEDA, QVI, LE, OOR, or oracle AIDs already exist.

Confirm the local service ports:

```sh
scripts/dev/start-local-gl1-stack.sh status
```

Inspect the deployed contracts:

```sh
jq . "$CONTRACTS_JSON"
cast chain-id --rpc-url "$RPC_URL"
```

The key addresses are:

- `ADMIN_CONTROLS`: wallet-level wrapper allowlist
- `IDENTITY_REGISTRY`: wallet-to-CCID registry written by the oracle
- `CREDENTIAL_REGISTRY`: compact credential registry written by the oracle
- `ORACLE_REGISTRY`: AID CCID keyed Legal Entity evidence registry
- `USDC_TOKEN`: underlying ERC-20 token
- `WRAPPER`: compliant `wUSDC` transfer entrypoint

## Prepare Operator Shell

Use one terminal for the human operator commands. Keep service logs in other
terminals or inspect the files under `runs/local-gl1-stack/`.

```sh
cd /Users/kbull/code/keri/kentbull/gleif-it/gl1/vlei-comply
source runs/local-gl1-stack/stack.env
```

## Initialize The vLEI Fixture

The GL1 integration increment is easier to see if the repetitive KLI issuance
work is already done. Initialize the fixture:

```sh
scripts/dev/init-local-vlei-fixture.sh --through oracle-posted
source runs/latest-fixture.env
```

This creates the single-sig GEDA, QVI, originator LE/OOR, beneficiary LE/OOR,
and oracle AIDs; resolves OOBIs; creates registries; issues and admits the
source vLEI chain; starts `vlei-oracle`; Grants both GL1 wallet attestations to
the oracle; POSTs CESR-encoded Ethereum signatures; and waits until both oracle
operations are posted on chain.

The output files are:

```text
runs/latest-fixture.env
$RUN_DIR/actors.env
$RUN_DIR/actors.json
$RUN_DIR/originator/oracle-status.json
$RUN_DIR/beneficiary/oracle-status.json
```

`actors.env` exports the values used in the rest of this guide:

```sh
env | grep -E '^(FIXTURE_STAGE|ORIGINATOR_|BENEFICIARY_|GEDA_AID|ORACLE_AID|USDC_TOKEN|WRAPPER|ORACLE_REGISTRY|ADMIN_CONTROLS)='
```

If you want to practice the wallet-attestation and oracle-posting step manually,
stop earlier:

```sh
scripts/dev/init-local-vlei-fixture.sh --through source-chain
source runs/latest-fixture.env
```

The default `oracle-posted` path is the right path when the goal is to focus on
GL1, smart contract admin controls, CCID registry state, and compliant token
movement.

On chain, the admin allows wallets in `AdminControls` and Legal Entity AID
CCIDs in `VLEIOracleRegistry`. The OOR holder is still critical: it issued the
wallet attestation that lets the oracle bind the Ethereum wallet to the Legal
Entity. It is not a separate on-chain allowlist key in this prototype.

## Fund Wallets, Mint, And Approve

Fund participant gas wallets when using non-Anvil-default keys, then mint seed
funds and approve the wrapper. This proves later failures are compliance
related, not missing gas, token balance, or allowance.

```sh
cast send "$ORIGINATOR_WALLET" --value "$GAS_FUND_AMOUNT" \
  --rpc-url "$RPC_URL" --private-key "$ADMIN_PK"

cast send "$BENEFICIARY_WALLET" --value "$GAS_FUND_AMOUNT" \
  --rpc-url "$RPC_URL" --private-key "$ADMIN_PK"

cast send "$USDC_TOKEN" "mint(address,uint256)" "$ORIGINATOR_WALLET" "$SEED_AMOUNT" \
  --rpc-url "$RPC_URL" --private-key "$ADMIN_PK"

cast send "$USDC_TOKEN" "approve(address,uint256)" "$WRAPPER" "$SEED_AMOUNT" \
  --rpc-url "$RPC_URL" --private-key "$ORIGINATOR_PK"
```

## Verify The First Expected Failure

Before wallet allowlisting, a static wrapper transfer should revert at the
`AdminControls` boundary:

```sh
cast call --rpc-url "$RPC_URL" --from "$ORIGINATOR_WALLET" "$WRAPPER" \
  "transfer(address,uint256)(bool)" "$BENEFICIARY_WALLET" "$TRANSFER_AMOUNT"
```

The oracle has already posted evidence in the default fixture, but the wallets
are still not allowed to use the wrapper.

## Allow Wallets But Not AIDs

Allow both wallets at `AdminControls`:

```sh
cast send "$ADMIN_CONTROLS" "setAllowed(address,bool)" "$ORIGINATOR_WALLET" true \
  --rpc-url "$RPC_URL" --private-key "$ADMIN_PK"

cast send "$ADMIN_CONTROLS" "setAllowed(address,bool)" "$BENEFICIARY_WALLET" true \
  --rpc-url "$RPC_URL" --private-key "$ADMIN_PK"
```

Now repeat the static transfer check:

```sh
cast call --rpc-url "$RPC_URL" --from "$ORIGINATOR_WALLET" "$WRAPPER" \
  "transfer(address,uint256)(bool)" "$BENEFICIARY_WALLET" "$TRANSFER_AMOUNT"
```

The call should return false. Wallet allowlisting alone is insufficient because
the AID CCIDs have oracle-posted evidence but are not yet explicitly allowed in
`VLEIOracleRegistry`.

## Inspect Registry State

The oracle posts three categories of evidence:

- wallet to `aidCcid` mapping in `IdentityRegistry`
- wallet credential record in `CredentialRegistry`
- Legal Entity evidence in `VLEIOracleRegistry`

Compute the AID CCIDs from the Legal Entity AIDs:

```sh
export ORIGINATOR_CCID="$(cast keccak "$ORIGINATOR_LE_AID")"
export BENEFICIARY_CCID="$(cast keccak "$BENEFICIARY_LE_AID")"
```

Read the oracle registry evidence before the AID allowlist:

```sh
cast call "$ORACLE_REGISTRY" "isLegalEntityValid(bytes32)(bool)" "$ORIGINATOR_CCID" --rpc-url "$RPC_URL"
cast call "$ORACLE_REGISTRY" "isLegalEntityValid(bytes32)(bool)" "$BENEFICIARY_CCID" --rpc-url "$RPC_URL"
```

Both should return false at this point because the records exist but their AID
allowlist flags are still false.

## Verify The Second Expected Failure

After oracle posting but before AID allowlisting, the transfer should still
return false:

```sh
cast call --rpc-url "$RPC_URL" --from "$ORIGINATOR_WALLET" "$WRAPPER" \
  "transfer(address,uint256)(bool)" "$BENEFICIARY_WALLET" "$TRANSFER_AMOUNT"
```

This is the policy boundary that proves the oracle posts evidence but does not
make the admin allowlist decision.

## Allow AID CCIDs And Transfer

Allow both Legal Entity AID CCIDs:

```sh
cast send "$ORACLE_REGISTRY" "setAidAllowed(bytes32,bool)" "$ORIGINATOR_CCID" true \
  --rpc-url "$RPC_URL" --private-key "$ADMIN_PK"

cast send "$ORACLE_REGISTRY" "setAidAllowed(bytes32,bool)" "$BENEFICIARY_CCID" true \
  --rpc-url "$RPC_URL" --private-key "$ADMIN_PK"
```

The static transfer check should now return true:

```sh
cast call --rpc-url "$RPC_URL" --from "$ORIGINATOR_WALLET" "$WRAPPER" \
  "transfer(address,uint256)(bool)" "$BENEFICIARY_WALLET" "$TRANSFER_AMOUNT"
```

Submit the real transfer:

```sh
cast call "$USDC_TOKEN" "balanceOf(address)(uint256)" "$ORIGINATOR_WALLET" --rpc-url "$RPC_URL"
cast call "$USDC_TOKEN" "balanceOf(address)(uint256)" "$BENEFICIARY_WALLET" --rpc-url "$RPC_URL"

cast send "$WRAPPER" "transfer(address,uint256)" "$BENEFICIARY_WALLET" "$TRANSFER_AMOUNT" \
  --rpc-url "$RPC_URL" --private-key "$ORIGINATOR_PK"

cast call "$USDC_TOKEN" "balanceOf(address)(uint256)" "$ORIGINATOR_WALLET" --rpc-url "$RPC_URL"
cast call "$USDC_TOKEN" "balanceOf(address)(uint256)" "$BENEFICIARY_WALLET" --rpc-url "$RPC_URL"
```

The originator balance should decrease by `TRANSFER_AMOUNT`; the beneficiary
balance should increase by the same amount.

## Explain The Final State

At the end of the successful path:

- the originator and beneficiary wallets are allowed by `AdminControls`
- both wallets are mapped to AID CCIDs in `IdentityRegistry`
- both GL1 wallet credentials are registered in `CredentialRegistry`
- both Legal Entity AID CCIDs have valid oracle-posted vLEI evidence
- both AID CCIDs are explicitly allowed in `VLEIOracleRegistry`
- the wrapper transfer passes because both wallet-level and AID-level controls
  are satisfied

The failure checkpoints are as important as the success checkpoint. They show
that the architecture separates wallet access, cryptographic vLEI verification,
oracle posting, and admin policy approval.
