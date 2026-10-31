# Wallet identity and association model

The entity identity reference is `keccak256(bytes(canonicalAidString))`.
EOA Verifier initially verifies KERI/ACDC evidence and issuer relationships.
The oracle trusts its authenticated status and derives the entity reference from
the association issuer AID.
The current endorsement binds that identity to one wallet and association SAID
on the deployed chain. KERI key rotation leaves the AID reference stable.

For ordinary transfers, the wrapper supplies the originator and beneficiary
wallets. The policy manager resolves wallet-to-identity hints through the
Chainlink adapter. `VLEIEndorsementChecker` requires a nonzero wallet and identity
and checks their exact current endorsement. Missing or stale mapping, withdrawal,
or an identity mismatch cannot pass. A second wallet for the same entity needs
its own endorsement.

Zero-wallet customer parties created by `transferWithBeneficiary` cannot satisfy
this wallet association policy. AID-only assurance would require a separately
named policy and is outside this interface.

The Chainlink credential registry supplies optional generic enrichment fields;
it does not authorize wallet association transfers. The oracle registry owns
the current endorsement. It contains no LEI or copied credential evidence.
