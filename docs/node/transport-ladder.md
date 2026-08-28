# Node transport ladder

How the app reaches a paired kubus Node.

## The problem

The app used to think in terms of *the Node URL*. That works while the phone
and the Node are on the same Wi-Fi and stops working the moment they are not —
which is most of the time a phone is actually useful. Making a Node reachable
from outside the home has historically meant asking its operator to understand
port forwarding, dynamic DNS, reverse proxies and certificates. That is a
sysadmin task, and requiring it of an artist who wants to process a capture is
the opposite of what a kubus Node is for.

The ladder replaces the single URL with a different idea:

> **One Node identity, many transports.**

A Node is identified cryptographically, not by an address. LAN, WebRTC and an
operator's own HTTPS ingress are *routes to the same Node*, not different
Nodes, and never separate identities.

## The rungs

| # | Rung | When | Carries | Needs internet | Relay |
| --- | ---- | ---- | ------- | -------------- | ----- |
| 1 | `localDirect` | Same network | HTTP to a private address | No | No |
| 2 | `webRtcDirect` | Away, hole-punching works | DataChannel | Yes | No |
| 3 | `remoteHttps` | Operator configured ingress | HTTPS | Yes | No |
| 4 | `webRtcRelay` | Away, NAT defeats direct | DataChannel via TURN | Yes | Yes |

The relay rung is always last, and always optional. See
`docs/node/turn-and-relay.md` — the relay is a **separate service**, not part
of the backend, and the system works entirely without it whenever LAN, direct
WebRTC, or an operator's own HTTPS ingress is available.

## Selection

`KubusNodeTransportResolver` is itself a `KubusNodeTransport` (composite), so
`KubusNodeService` and everything above it are unaware that a choice is being
made at all. The service asks for `/local/v1/...`; the resolver decides how it
gets there.

**The order is not hard-coded.** `NodeTransportPolicy` is an interface, because
the right order has not been benchmarked on real networks and is unlikely to be
one answer for every client:

- **`NativeTransportPolicy`** — LAN first. A native client can reach a private
  address directly.
- **`BrowserTransportPolicy`** — WebRTC first. Direct private-network HTTP from
  a public origin is frequently blocked by browser security policy, so a
  browser should not spend its first attempt there.

Both put the relay last. The current orders are starting positions to be
measured, not claims of optimality.

Scoring is deterministic and therefore testable:

```text
score = policy order index × 1000
      + health penalty
      + latency penalty (capped)
      + policy penalty
```

Health and measured latency reorder *within* the policy's order but can never
promote a relay above a working direct route — a fast relay is still a relay.

The policy penalty is where cost enters: a bulk transfer (≥ 8 MB) or a metered
network pushes the relay far down, because a spatial capture is exactly the
payload that turns occasional fallback into a standing bandwidth bill. The
relay is penalised, never removed — if it is the only surviving route, a slow
upload beats no upload.

### Two rules that shape everything

**1. A Node error is not a transport failure.**

If the Node answers `503 worker_unavailable`, the route worked perfectly; the
Node is unhappy. Only connection-level faults (`SocketException`,
`TimeoutException`, TLS handshake failures) demote a route. Conflating the two
would let one unhealthy Node poison the health of every rung, and would send a
doomed request around the whole ladder collecting the same answer four times.

**2. Failover must never duplicate work.**

Another route is tried only when `KubusNodeRequest.isSafeToRetry` allows it:
reads always, mutations only when they carry an idempotency key the Node can
deduplicate against. A non-idempotent write that fails mid-flight throws rather
than being replayed elsewhere. A duplicate capture or a duplicate processing
job is worse than a failed one.

## Health

Per route: state, last success, last failure, consecutive failures, and a
smoothed (EWMA) latency so one stall cannot redefine an otherwise good route.

Failures earn a geometric, capped cooldown. A dead route is skipped for the
current burst rather than probed on every request — on a phone that is radio
and battery cost, not merely wasted work.

`onNetworkChanged()` clears every cached verdict. Walking back through your own
front door must not leave the LAN route suppressed for the remainder of a
cooldown it earned while you were out.

## What the user sees

`NodeConnectionStatus` is deliberately coarse:

- **Connected nearby** — local route
- **Connected remotely** — *any* other rung
- **Connecting** — rungs still undecided
- **Offline** — every route failed

Every non-local rung collapses to "remotely" on purpose. Whether the bytes took
a direct peer connection, a relay, or the operator's own ingress changes
nothing the user can act on.

TURN, STUN, ICE and NAT never appear in primary UI. They live in
`NodeConnectionDiagnostics`, behind explicit disclosure. A test asserts the
headline enum contains no such token, so adding `connectedViaRelay` later fails
the build rather than the product.

## What this removes

No rung needs an inbound port, a public DNS name, or a TLS certificate on the
Node. Automatic TLS was a symptom of assuming the phone must dial *in*; once
the Node can dial out or meet the phone peer-to-peer, the requirement
disappears — along with UPnP and port forwarding.

Operator-configured HTTPS remains fully supported for those who already run
their own ingress. It is one rung among several, not a prerequisite, and the
architecture stays vendor-neutral.

## Files

- `lib/services/node/kubus_node_transport.dart` — the contract
- `lib/services/node/http_node_transport.dart` — rungs 1 and 3
- `lib/services/node/node_transport_resolver.dart` — selection, health, failover
- `lib/services/node/node_transport_health.dart` — per-route health
- `lib/services/node/node_transport_policy.dart` — pluggable ordering and penalties
- `lib/services/node/turn_configuration.dart` — STUN/TURN config, credentials
- `lib/services/node/node_connection_status.dart` — user-facing status
