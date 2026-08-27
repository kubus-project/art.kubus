# TURN and relay

Where the relay sits, and — more importantly — where it does not.

## Three separate things

These are never merged, and the separation is the point:

| | Role | Sees |
| --- | --- | --- |
| **Control plane** (art.kubus backend) | Authenticates user/device/Node, carries short-lived signaling, issues short-lived TURN credentials, serves STUN/TURN configuration | Metadata: *that* a device wants to reach a Node |
| **Data plane** (the Node) | Holds private captures, processes them, serves results | The content, because it is the owner's own machine |
| **Relay** (Coturn on the HA witness host) | Forwards encrypted WebRTC packets when direct connectivity fails | Ciphertext and packet sizes. Nothing else. |

The relay is deployed on the isolated HA witness overlay, not on an API/backend
host. Flutter does not encode that host or deployment topology: it consumes the
authoritative STUN/TURN URLs and expiring credentials returned by the backend.

**The relay is not part of the backend.** It is a separate service, deployed
and scaled separately, and it understands nothing about captures, spatial
libraries, jobs, or any other application concept. It moves opaque bytes.

The backend's only relationship to the relay is issuing a credential for it.
It never proxies content, and content never passes through the control plane.

## TURN is optional

A Node does not need a relay to be owned, operated, or reached. The system
works entirely without TURN when any of these hold:

- the phone and Node share a network (LAN),
- direct WebRTC succeeds via ICE/STUN,
- the operator has configured their own verified HTTPS ingress.

`IceConfiguration.turn` is nullable, and a configuration containing only STUN
is fully valid — asserted by test. TURN exists for NAT and firewall topologies
that defeat direct connectivity, and for nothing else.

Presenting a relay as a requirement would contradict the point of running your
own Node.

## Credentials

**Permanent TURN credentials must never ship in any client** — Flutter, web, or
Node. A credential embedded in a binary or bundle can be extracted, cannot be
revoked per user, and turns the relay into open infrastructure for whoever
finds it.

Instead: the authenticated control plane issues a **short-lived, expiring**
credential per connection attempt, using coturn's REST mechanism or equivalent.
The client never holds the shared secret — only the short-lived product of it.

`TurnCredentials` has no constructor for a non-expiring credential, and none
should be added. The client also enforces a **maximum lifetime on receipt**
rather than trusting what it is handed: a control plane that starts issuing
day-long credentials should fail loudly, not quietly widen the window in which
a leaked credential is useful.

An expired credential is dropped from the ICE server list rather than offered.
Handing WebRTC a credential the relay will reject only wastes negotiation time
and obscures why a connection actually failed.

`toLogSafeJson()` omits the credential entirely.

## Abuse controls

Relay bandwidth is real money, and an open relay is a service other people will
happily consume. Required on the relay/control-plane side:

- per-user and per-Node **quotas**
- **rate limits** on credential issuance
- short credential lifetimes (already enforced client-side)
- **observability**: allocations, bytes relayed, issuance rate

None of these live in the client, and the client must not be treated as the
enforcement point.

## Avoiding the relay

Preferring direct connectivity is not only a latency argument — it is a cost
argument, and a spatial capture is exactly the payload that turns "occasional
fallback" into a standing bill.

`TransportSelectionContext` carries the approximate payload size and whether
the network is metered. `NodeTransportPolicy.penaltyFor` uses them to push the
relay far down for bulk transfers (≥ 8 MB) and for metered connections.

The relay is **penalised, never removed**. If it is genuinely the only
surviving route, a slow upload beats no upload. Both behaviours are tested.

## Ordering is not fixed

The preference order is **not** hard-coded, and deliberately so: the right
order has not been benchmarked on real networks, and it is unlikely to be one
answer for every client.

`NodeTransportPolicy` is an interface. Two implementations ship:

- **`NativeTransportPolicy`** — LAN first. A native client can reach a private
  address directly, and that route needs no internet, adds no hop, and keeps a
  capture inside the user's own network.
- **`BrowserTransportPolicy`** — WebRTC first. Direct private-network HTTP from
  a public origin is frequently blocked by mixed-content and
  private-network-access policy, so a browser should not spend its first
  attempt there. That is a property of the platform, not of the network.

Both put the relay last. Beyond that, the current orders are **starting
positions to be measured**, not claims of optimality. A deployment that wants
no relay at all can supply a policy that omits it, and it will never be
attempted — also tested.

## Files

- `lib/services/node/turn_configuration.dart` — STUN/TURN config, credentials
- `lib/services/node/node_transport_policy.dart` — ordering and penalties
- `lib/services/node/node_transport_resolver.dart` — applies the policy
