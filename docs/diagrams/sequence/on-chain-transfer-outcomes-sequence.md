# Transfer rejection and token outcomes

Current wrapper behavior has no queued transfers or administrative settlement.

![Transfer rejection and token outcomes](on-chain-transfer-outcomes-sequence.svg)

<details>
<summary>Editable Mermaid source</summary>

```mermaid
%%{init: {"theme":"base","themeVariables":{"actorBkg":"#003336","actorTextColor":"#FFFFFF","signalColor":"#003336","signalTextColor":"#003336","noteBkgColor":"#E5DCE6","noteTextColor":"#003336","loopTextColor":"#003336","labelTextColor":"#003336","labelBoxBkgColor":"#DFFBC0","labelBoxBorderColor":"#6A7B7F","actorLineColor":"#6A7B7F","lineColor":"#6A7B7F"},"sequence":{"mirrorActors":true,"wrap":true}}}%%
sequenceDiagram
    autonumber
    participant U as Owner
    participant W as wUSDC
    participant P as PolicyManager
    participant T as Underlying token
    U->>W: transfer / owner-only transferFrom
    alt Paused or caller violates owner-only route
        W-->>U: Revert
    else Preconditions hold
        W->>P: runPolicies(envelope)
        alt Aggregate is not Pass
            P-->>W: Policy results and aggregate failure
            W->>W: Emit policy rejection event
            W-->>U: Return false, no token call
        else Aggregate Pass
            P-->>W: Compliance attestation
            W->>T: transferFrom
            alt Token reverts
                T-->>U: Entire transaction reverts (including emitted logs)
            else Token returns
                T-->>W: Boolean result
                W-->>U: Return token result
            end
        end
    end
```

</details>

A successful transaction receipt can contain policy rejection and zero token movement. Check wrapper result/events and actual balances. Token allowance/balance failures can revert. Prior approvals are separate transactions. Source: [wrapper](../../../src/wrappers/wUSDC.sol).
