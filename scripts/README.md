# Local contract deployment

Comply owns contract construction and deployment output. It needs Foundry 1.5.1
and jq, with recorded submodules initialized by `./setup.sh`. Python and the
Verifier/Oracle applications are not required for this command or `forge test`.

Start a local Anvil separately, then deploy once to a new artifact path:

```sh
PRIVATE_KEY='<funded local Anvil key>' scripts/deploy-local.sh \
  --rpc-url http://127.0.0.1:8545 --output deployments/demo/contracts.json
```

The command accepts only loopback Anvil, invokes `script/DeployAll.s.sol`, and
publishes the JSON only after successful broadcast, deployed-code, installed-policy and deployer-role checks.
It refuses existing output. Simulation/partial output is not a deployment result.
The artifact contains version, chain ID, deployer and named contract addresses,
including the identity proxy and adapter. It contains no private key. Logs remain
normal Forge output. Use `cast call` to inspect roles and policy configuration.

Oracle owns combined KERI/application/network orchestration. Contract deployment
never starts those applications or modifies their stores. The local allow-all
engine serves development registry writes only; no production claim is made.
