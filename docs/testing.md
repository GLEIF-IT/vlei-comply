# Find and run contract tests

Contracts and interfaces live with their owner: admin, identity, associations,
policy and wrappers. Concrete local-only USDC and AllowAllPolicyEngine live in
demo; DeployAll is the composition root. Production components cannot depend on
demo. Public ABI/publication vectors remain in abi/ for external consumers.

| Contract/scenario | Command |
|---|---|
| VLEIOracleRegistry | forge test --match-path test/associations/VLEIOracleRegistry.t.sol |
| PolicyManager | forge test --match-path test/policy/PolicyManager.t.sol |
| One function/behavior | forge test --match-test testNonPassingPolicyDominatesInBothOrders |
| Wallet compliance integration | forge test --match-path test/integration/WalletAssociationCompliance.t.sol |

Policy doubles live in test/support/doubles/PolicyDoubles.sol. The integration
fixture and real topology remain together. Tests never import .t.sol files. The
same 28 cases cover admin, identity, policy, registry and wrapper interactions.
Behavior, selectors/events and stored fields are unchanged by this refactor.

Run forge test and python3 scripts/dev/test_startup.py with Foundry 1.5.1.
ABI comparisons are exact;
storage comparisons resolve type structure while ignoring compiler AST IDs and
moved source paths. Compiler metadata may change.

For witnessed applications/token/recovery qualification, select the qualified
oracle checkout/environment and run scripts/dev/init-local-vlei-fixture.sh. It
invokes the sole tests/qualification/test_two_services.py after changing into the
oracle root, without PYTHONPATH injection or duplicated workflow code.
