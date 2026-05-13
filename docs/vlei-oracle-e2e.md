# vLEI Oracle E2E

The full local oracle flow lives in the sibling `vlei-oracle` package:

```sh
cd ../vlei-oracle
./scripts/e2e/gl1-wallet-transfer-e2e.sh
```

The script deploys this repository to Anvil with `script/DeployAll.s.sol`,
parses the deployed contract addresses, posts oracle-verified Legal Entity
evidence into `IdentityRegistry`, `CredentialRegistry`, and
`VLEIOracleRegistry`, then executes a compliant `wvLEI.transfer`.

The expected service preconditions are:

- `kli witness demo` is reachable on demo witness ports `5642`, `5643`, `5644`.
- `vLEI-server` is reachable on `7723` and serves the built-in vLEI schemas plus
  the GL1 Ethereum Wallet Attestation schema.
- Foundry tools are available through `forge`, `cast`, and `anvil`.

The GL1 wallet attestation schema uses `NI2I` on both wallet credential edges to
the LE and OOR credentials. That is intentional: the wallet binding is
OOR-issued self-attested evidence, not ordinary issuer-to-issuer provenance.
