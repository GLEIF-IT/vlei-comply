# vLEI Oracle E2E

The canonical machine-run proof lives in the sibling `vlei-oracle` package:

```sh
cd ../vlei-oracle
./scripts/e2e/gl1-wallet-transfer-e2e.sh
```

That script proves:

```text
GEDA -> QVI -> LE -> OOR -> GL1 Ethereum Wallet Attestation
  -> vlei-oracle -> vlei-comply registries -> compliant wUSDC transfer
```

For a human-operated walkthrough, use
[GL1 USDC CLI Execution Guide](gl1-vlei-cli-execution-guide.md). For local
service startup and troubleshooting, use
[GL1 USDC Local Infrastructure Setup](gl1-vlei-local-infra-setup.md).

The human guide uses `scripts/dev/init-local-vlei-fixture.sh`, which calls the
same e2e machinery with explicit stop-points. `--through source-chain` stops
after GEDA/QVI/LE/OOR issuance. `--through oracle-posted` stops after wallet
attestations are verified and posted on chain, leaving admin allowlists,
minting, approvals, and transfers for the operator.

Important protocol boundaries:

- wallet attestation edges to the LE and OOR credentials use `NI2I`
- the oracle receives a standard KERIpy IPEX Grant and does not run
  `kli ipex admit`
- the Ethereum wallet signature is external to the ACDC and is POSTed to the
  oracle as CESR-encoded signature evidence
- admin wallet allowlisting and AID CCID allowlisting remain explicit policy
  steps after oracle verification
