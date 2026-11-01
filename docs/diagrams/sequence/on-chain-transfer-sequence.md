# Direct-wallet compliance transfer

The owner approves wUSDC on the underlying token and invokes transfer or the owner-only transferFrom route.

![Direct-wallet compliance transfer](on-chain-transfer-sequence.svg)

<details>
<summary>Editable Mermaid source</summary>

```mermaid
%%{init: {"theme":"base","themeVariables":{"actorBkg":"#003336","actorTextColor":"#FFFFFF","signalColor":"#003336","signalTextColor":"#003336","noteBkgColor":"#E5DCE6","noteTextColor":"#003336","loopTextColor":"#003336","labelTextColor":"#003336","labelBoxBkgColor":"#DFFBC0","labelBoxBorderColor":"#6A7B7F","actorLineColor":"#6A7B7F","lineColor":"#6A7B7F"},"sequence":{"mirrorActors":true,"wrap":true}}}%%
sequenceDiagram
    autonumber
    participant U as Token owner
    participant W as wUSDC
    participant P as PolicyManager
    participant R as Identity / endorsement registries
    participant T as Underlying USDC
    U->>T: approve(wUSDC, amount)
    U->>W: transfer(to, amount) or transferFrom(owner, to, amount)
    W->>W: Check system pause, explicit-source caller must be owner
    W->>P: runPolicies(two exact wallet parties)
    P->>R: Resolve identities and evaluate configured policies
    R-->>P: Current exact-wallet endorsements
    P->>P: Emit compliance evaluation / envelope hash
    P-->>W: Aggregate Pass and per-policy results
    W->>T: transferFrom(owner, recipient, amount)
    T-->>W: Token result (or revert)
    W-->>U: Return result
```

</details>

See [registry interface](../../oracle-registry.md) and [policy evaluation](wallet-endorsement-evaluation-sequence.md). No wrapped balances are minted. Direct underlying transfers are permitted outside this audit route. An unconfigured manager returns Fail with no per-policy results and records its evaluation hash. The wrapper records rejection with a zero policy ID and makes no token call. The diagram above shows the successful configured-policy path.
