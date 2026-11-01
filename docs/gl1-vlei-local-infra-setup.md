# Local infrastructure ownership

Comply owns Solidity construction, recorded submodules, contract tests and
structured deployment output. It starts no KERI or Python application services.

For contract-only work:

```sh
./setup.sh
forge build
forge test
```

Start a local Anvil separately and follow [deploy-local](../scripts/README.md).
The command checks actual deployed code, configured policy and roles before
publishing `deployments/RUN/contracts.json`. Existing outputs are refused.

For the witnessed Verifier/Oracle/USDC environment use the
[Oracle integration commands](https://github.com/GLEIF-IT/vlei-oracle/tree/main/scripts/integration).
Oracle owns exact source selection, isolated wheel installation, native witness
and schema hosting, service identities, peer introduction, chain, deployment,
writer setup and lifecycle. Its run manifest records endpoints and artifacts.

The [maintained scenario](vlei-oracle-e2e.md) distinguishes verifier acceptance,
authenticated storage ACK, Oracle selection and confirmed contract mapping. It
checks token balances and exact-SAID withdrawal. A successful HTTP response or
transaction receipt alone is insufficient. Stop preserves stores and chain;
clean is explicit and restricted to a stopped run owned by that environment.
