# vLEI Oracle Registry

`VLEIOracleRegistry` is an on-chain evidence registry. It is not a live GLEIF, Sally, or KERI verifier. A trusted off-chain oracle service validates the vLEI credential chain and posts compact status that Solidity can check deterministically.

## Legal Entity Record

Each record is keyed by `aidCcid`.

| Field                      | Meaning                                                                                          |
|----------------------------|--------------------------------------------------------------------------------------------------|
| `aid`                      | Canonical AID string used to compute `aidCcid`. Stored for inspection and event-driven indexing. |
| `entityLei`                | LEI expected for the Legal Entity represented by the AID.                                        |
| `entityLeiHash`            | `keccak256(bytes(entityLei))`.                                                                   |
| `credentialSubjectLeiHash` | Hash of the LEI asserted inside the LE ACDC credential subject.                                  |
| `acdcSaidHash`             | Hash/reference for the LE ACDC SAID validated off-chain.                                         |
| `proofHash`                | Optional commitment to the oracle's proof bundle or evidence report.                             |
| `issuedAt`                 | Oracle-posted credential/evidence issue time. Defaults to block time when zero.                  |
| `expiresAt`                | Expiration cutoff. Zero means no expiration in this prototype.                                   |
| `allowed`                  | AID-level allowlist gate controlled by compliance admin.                                         |
| `revoked`                  | Revocation flag for the LE ACDC status.                                                          |

## Entity LEI vs Credential Subject LEI

The registry stores both `entityLeiHash` and `credentialSubjectLeiHash` to make the invariant explicit:

```text
entityLeiHash == credentialSubjectLeiHash
```

The entity LEI is the LEI this on-chain record expects for the AID. The credential subject LEI is the LEI extracted from the LE ACDC by the off-chain oracle. A mismatch means the credential does not prove the entity claim being used for compliance.

## Validation Results

`validateLeCcid(aidCcid)` returns the first fail-closed validation result:

1. missing record,
2. AID not allowlisted,
3. missing entity LEI,
4. missing credential subject LEI,
5. LEI mismatch,
6. missing ACDC SAID,
7. expired credential,
8. revoked credential.

`isLegalEntityValid(aidCcid)` returns true only when the validation result is `Valid`.

## Production Notes

The local integration uses `vlei-oracle` as the off-chain verifier/poster for
KERI/vLEI material. Production deployments should harden that service's
governance, key management, observability, evidence retention, and deployment
operations while keeping the on-chain registry compact and fail-closed.
