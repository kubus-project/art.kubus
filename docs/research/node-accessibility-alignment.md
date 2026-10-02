# Node accessibility and the research position

How the transport ladder relates to the project's stated architecture, and
where it deliberately stops short of claims the implementation cannot support.

## The tension this work addresses

The research argues for redistributing access, control, storage and resilience
— and explicitly *not* for requiring every participant to operate
infrastructure. Those two commitments pull against each other in practice:
self-hosting is where autonomy lives, and self-hosting has historically
demanded port forwarding, dynamic DNS, reverse proxies and certificates.

An artist who wants to process their own capture on their own machine should
not first have to become a network administrator. When the barrier is that
high, "you can run your own Node" is true on paper and false in practice, and
the autonomy the architecture claims to distribute stays with the technically
confident.

The ladder lowers that barrier without moving the work to a mandatory cloud.

## What is claimed, precisely

**Node operation remains optional.** Nothing here makes a Node a prerequisite
for ordinary participation. Phone capture, the Spatial Library and processing
via KUBUS Network all work without one. A Node increases autonomy; it is not an
entry requirement.

**Local-first still holds.** LAN and operator-configured HTTPS work with the
backend entirely offline. Only the rungs that require introduction between two
NATed peers depend on signaling. That is a hard requirement, verified by
degradation tests, not an aspiration.

**Self-hosting is preserved and vendor-neutral.** Operator-configured HTTPS
remains a first-class rung. An operator already running Tailscale, Cloudflare
Tunnel, Caddy, nginx or their own domain keeps using it. No commercial tunnel
service is required, and none is privileged.

**The data plane is not centralised.** Captures and processed scenes travel on
the established transport. The backend introduces peers; it does not carry
their content.

## What is *not* claimed

**This is not complete decentralisation, and saying so would be dishonest.**

Two peers behind NAT cannot discover each other unaided. Something both can
reach must introduce them — a constraint of IP networking, not a design
preference. The honest description is:

> A hybrid, local-first, distributed architecture with a small, short-lived
> control plane.

**TURN relay is a separate service and a practical compromise.** When NAT
topology defeats direct connectivity, a relay carries the encrypted traffic.
That relay is *not* part of the art.kubus backend — it is a distinct service
(coturn or equivalent) that forwards opaque bytes and understands no
application concept. Someone operates and pays for it.

This is presented as an infrastructural compromise that buys accessibility,
not as evidence of decentralisation. It is also **optional**: owning or
operating a Node never requires a relay, and the system works entirely without
one whenever LAN, direct WebRTC, or an operator's own HTTPS ingress is
available. Policy pushes every unrelayed route ahead of it, and pushes it
further down still for bulk spatial transfers — so relay stays the exception
rather than a quiet default. See `docs/node/turn-and-relay.md`.

The separation that matters: **control plane ≠ data plane ≠ relay.**

**Backend signaling is observable metadata.** The control plane can see *that*
a device wishes to reach a Node, and when. It cannot see what they exchange.
Sessions expire in two minutes and SDP is never logged. That residual exposure
is documented in `docs/node/threat-model.md` rather than minimised.

## Why WebRTC, specifically

WebRTC is used as a **connectivity mechanism**, not as an architecture. It does
not replace the Node protocol, the storage model, or IPFS. The same canonical
`/local/v1/...` operations travel over it; only the carriage changes.

It was chosen because it solves NAT traversal with standard, widely-implemented
protocols (ICE/STUN/DTLS/SCTP) instead of a bespoke tunnel, and because it
degrades to a relay only when it must. The alternative — asking each operator
to expose a port and obtain a certificate — reintroduces exactly the barrier
this work exists to remove.

## Terminology

The current token is **KUB8**. Earlier drafts used "kubit"; no occurrence
remains in the repositories or site content.

The system should not be described as having Solana as its backbone. The
implementation combines phone-local private storage, PostgreSQL as authoritative
application data, publicSyncService, OrbitDB synchronisation, IPFS/DNSLink
public fallback, kubus Nodes, optional distributed compute, and selected
Solana/Web3 mechanisms. Describing one component as the whole would misstate
the architecture.

## Where infrastructure sits relative to the artwork

The physical artwork is the subject; the infrastructure is not. That principle
shows up concretely in this work:

- Transport vocabulary (TURN, STUN, ICE, NAT) never reaches primary UI. The
  headline is "Connected nearby" or "Connected remotely"; a test enforces the
  absence of those tokens so it cannot regress.
- A person is told what they can *do* — whether this capture can be processed —
  rather than which traversal strategy succeeded.
- Diagnostics exist for operators who want them, behind explicit disclosure.

## Related

- `docs/node/transport-ladder.md`
- `docs/node/webrtc-protocol.md`
- `docs/node/signaling.md`
- `docs/node/turn-and-relay.md`
- `docs/node/threat-model.md`
