# Production Readiness TODOs

This file tracks known work that must be addressed before `vlei-comply` can be called production ready. The current repository is a production-preparation prototype: useful for proving architecture and CLI flows, but not yet a production compliance system.

Severity definitions:

- High: production blocker with direct security, compliance, custody, or governance impact.
- Medium: important correctness, operability, integration, or audit-readiness work.
- Low: maintainer hygiene and polish that should still be completed before production release.

## High

- [ ] Replace `AllowAllPolicyEngine` with a robust production-grade Chainlink policy engine.
  The replacement must enforce registry-write authorization, policy mapping, policy configuration, denial behavior, and audit-friendly events. `AllowAllPolicyEngine` is dev-only and must never protect production identity or credential registries.

- [ ] Define and implement production governance for `AdminControls`.
  Move admin roles to multisig/timelock or equivalent controls, separate compliance admin and emergency duties, define key rotation, and document emergency pause/unpause runbooks.

- [ ] Implement the production vLEI oracle service.
  The service must verify KERI/vLEI evidence off-chain, including Legal Entity AID legitimacy, LE credential chain, QVI authority, LEI match, revocation state, expiry, proof durability, and canonical AID normalization before posting on-chain.

- [ ] Harden `VLEIOracleRegistry` evidence posting.
  Add production-grade authorization and proof semantics such as signed oracle reports, quorum or signer policy, replay protection, stale-evidence limits, versioned proof formats, and durable `proofHash` evidence bundles.

- [ ] Resolve direct `USDC` transfer bypass.
  Today direct ERC-20 transfers only respect global pause and bypass wrapper policy checks. Decide whether production requires wrapper-only transfers, token-hook enforcement, transfer restrictions, or another architecture, then implement and test it.

- [ ] Formalize Chainlink CCID and KERI AID identity binding.
  Specify canonical AID string rules, `aidCcid = keccak256(bytes(canonicalAidString))`, wallet-to-CCID proof requirements, key rotation behavior, duplicate/changed wallet handling, and registry-write governance.

- [ ] Rework pending transaction resolution before enabling `Pending` in production policies.
  Pending records currently store transfer details and execute on admin approval. Production behavior must define expiry, cancellation, revalidation on approval, allowance/balance race handling, event evidence, and whether manual approval is acceptable.

- [ ] Complete an external security review before mainnet or regulated deployment.
  Scope should include wrapper enforcement, registry governance, oracle posting, policy aggregation, ERC-20 behavior, proxy initialization, role control, and CLI/deployment procedures.

## Medium

- [ ] Implement OOR and authority-specific policy checks.
  Extend beyond Legal Entity checks to OOR person AIDs, required credential SAIDs, required position names, operation intent, delegated authority, and LE/OOR relationship validation.

- [ ] Define a typed `extraData` schema.
  Replace ad hoc bytes with versioned, documented ABI payloads for credential references, operation constraints, authority requirements, and future policy extensions.

- [ ] Upgrade policy lifecycle controls.
  Add production procedures for policy versioning, policy freeze/unfreeze, rollout, rollback, deprecation, and event indexing of policy-set changes.

- [ ] Improve failure diagnostics surfaced by wrapper events.
  `ComplianceCheckFailed` currently emits aggregate status as `reasonCode`. Production operators likely need policy-specific reason bytes, decoded failure codes, and stable event indexing for investigations.

- [ ] Replace unchecked ERC-20 calls with explicit safe handling.
  Use `SafeERC20` or equivalent handling where appropriate, especially around pending resolution and test assumptions flagged by Foundry lint.

- [ ] Define timestamp and expiry policy.
  Specify acceptable clock drift, stale oracle evidence windows, expiry grace behavior, revocation precedence, and how block timestamp manipulation risk is bounded.

- [ ] Harden deployment scripts.
  Separate local Anvil deployment from production deployment, remove dev-only components from production paths, define proxy ownership, verify initializer arguments, and produce machine-readable deployment artifacts.

- [ ] Expand tests beyond current unit and CLI coverage.
  Add fuzz, invariant, negative-path, fork, integration, oracle-report, governance, and upgrade/deployment tests. Include tests proving direct-token bypass is impossible or intentionally accepted.

- [ ] Build operational monitoring and indexing.
  Define required event consumers for identity registrations, oracle record updates, allowlist changes, revocation changes, policy changes, failures, and pending resolutions.

- [ ] Resolve dependency and submodule provenance.
  The current workspace reports an OpenZeppelin submodule revision mismatch. Pin, verify, and document dependency versions before production review.

## Low

- [ ] Publish generated Solidity docs as part of the release process.
  `forge doc --build` should run in CI and publish or archive ABI-facing documentation alongside maintainer docs.

- [ ] Convert remaining string reverts to custom errors where useful.
  This improves ABI clarity, gas usage, and operator diagnostics, but should be done intentionally because it changes ABI surface.

- [ ] Clean up generated provenance comments.
  Preserve useful GL1 Wizard provenance while removing any stale generated-language that conflicts with maintained production code.

- [ ] Add convenience CLI scripts for demos and smoke tests.
  Wrap the Anvil/cast workflow into repeatable scripts that demonstrate success and failure modes without relying on copied command fragments.

- [ ] Add release and audit checklists.
  Include pre-release checks for docs generation, tests, lint warnings, dependency verification, deployment dry runs, role assignment, and oracle operator setup.

- [ ] Document wallet and UI integration expectations.
  Capture how MetaMask or other wallets should interact with wrapper approvals, failed transfers, AID-only flows, and compliance failure messages.
