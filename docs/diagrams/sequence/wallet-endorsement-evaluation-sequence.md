# Exact-wallet endorsement evaluation

The policy checks both originator and beneficiary customer roles. Each needs a wallet and matching entity endorsement.

![Exact-wallet endorsement evaluation](wallet-endorsement-evaluation-sequence.svg)

<details>
<summary>Editable Mermaid source</summary>

```mermaid
%%{init: {"theme":"base","themeVariables":{"actorBkg":"#003336","actorTextColor":"#FFFFFF","signalColor":"#003336","signalTextColor":"#003336","noteBkgColor":"#E5DCE6","noteTextColor":"#003336","loopTextColor":"#003336","labelTextColor":"#003336","labelBoxBkgColor":"#DFFBC0","labelBoxBorderColor":"#6A7B7F","actorLineColor":"#6A7B7F","lineColor":"#6A7B7F"},"sequence":{"mirrorActors":true,"wrap":true}}}%%
sequenceDiagram
    autonumber
    participant M as PolicyManager
    participant I as Identity adapter
    participant P as Wallet association policy
    participant E as Endorsement checker
    participant R as Oracle registry
    M->>I: Resolve each wallet identity
    I-->>M: AID-derived identityRef (or missing)
    M->>P: evaluate(enriched transaction)
    loop Each originator / beneficiary customer party
        P->>E: verify(wallet, identityRef)
        E->>R: isEndorsed(exact wallet, identityRef)
        R-->>E: Current match
        E-->>P: Boolean result
    end
    P-->>M: Pass only with both roles present and all matching
    Note over P,R: Another wallet of the same entity does not qualify
```

</details>

This is a read-only check of stored endorsements, not credential verification. See [contract reference](../../contracts-reference.md) and [registry interface](../../oracle-registry.md).
