# Signaling

How two already-paired peers find each other.

## Scope

Signaling is **control-plane metadata used to establish a connection**. It is
never the data plane, and it is not the relay either.

Three separate things, never merged:

- **control plane** (this document) — authenticates, signals, issues
  short-lived TURN credentials
- **data plane** — the Node, holding private content
- **relay** — a separate service forwarding encrypted packets when direct
  connectivity fails; see `docs/node/turn-and-relay.md`

Captures, processed scenes and any other private content travel on the
established transport. Nothing of the kind passes through signaling, and the
backend never sees plaintext application payloads. That distinction is what
lets signaling be centralised without making the data plane centralised.

## Why a central component is acceptable here

Two peers behind NAT cannot discover each other unaided; something both can
reach has to introduce them. That is a genuine constraint of IP networking, not
a design preference.

What matters is what the introducer can observe and how long it holds it:

- It sees **that** a device wants to reach a Node, not **what** they exchange.
- Sessions are short-lived (max 2 minutes) and not retained afterwards.
- SDP and ICE candidates are never written to production logs.

Calling this "fully decentralised" would be dishonest. It is a hybrid: a small,
short-lived, observable-but-contentless control plane, and a private data
plane. See `docs/research/node-accessibility-alignment.md`.

## Message types

| Type | Payload | Purpose |
| ---- | ------- | ------- |
| `offer` | SDP | Session description from the initiator |
| `answer` | SDP | Reply |
| `candidate` | ICE candidate | One transport candidate |
| `connectionAttempt` | — | Wakes a Node that is only polling |
| `close` | — | Either side abandoning |

## Envelope and binding

Every message carries `sessionId`, `nodeId`, `deviceId`, `nonce`, `issuedAt`
and `expiresAt`.

Binding is the point. **Transport success is not Node trust**: a peer that
completes ICE has proved only that packets flow. It must still be the Node this
device paired with. `nodeId` is the Node's stable cryptographic identity —
never an IP, DNS name, or WebRTC peer id, none of which prove anything.

Validation refuses:

- a `nodeId` that is not the paired Node — identity substitution
- a `deviceId` that is not this device
- an expired session
- a self-granted lifetime beyond the protocol maximum
- a replayed nonce
- an `offer`/`answer`/`candidate` with no payload

## Retention and logging

An SDP that is still valid tomorrow is an SDP worth stealing, and a session
outliving the attempt it describes is retained personal data for no purpose.
Hence the 2-minute ceiling, enforced on receipt rather than trusted from the
sender.

`toLogSafeJson()` represents payloads **by length only**. SDP and ICE
candidates contain host addresses and session credentials; dumping them into
logs would leak network topology and undo the point of short sessions.

## Node presence

A Node may publish a minimal record so a paired device knows it is around:

```json
{
  "nodeId": "...",
  "transports": ["localDirect", "webRtcDirect"],
  "acceptsConnections": true,
  "updatedAt": "..."
}
```

That is the whole record. Presence answers "is this Node around, and what can
it speak?" — nothing else.

**Private LAN addresses are deliberately absent.** They belong in ICE candidate
exchange between two already-authenticated peers, not in a record the control
plane holds. Publishing them would hand any observer a map of the operator's
home network.

`NodePresence.forbiddenKeys` is *enforced*, not documented, because presence is
exactly the record that accumulates "just one useful field" over time. Adding
an endpoint, a credential, a token, or capture counts fails a test.

## Degradation

Signaling is not required for the system to work:

- **LAN** works with the backend entirely offline.
- **Operator-configured HTTPS** works with the backend entirely offline.
- The Node's own local GUI and API keep working.

Only rungs that need introduction (WebRTC direct and relayed) depend on
signaling. This is a hard requirement of local-first operation, not an
aspiration.

## Files

- `lib/services/node/node_signaling.dart`
