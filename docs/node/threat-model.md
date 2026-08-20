# Node connectivity threat model

Scope: the transport ladder, WebRTC framing, and signaling. Pairing and the
Node's own local API have their own existing coverage; this covers what the new
connectivity work adds.

## Central invariant

> **Transport success is not Node trust.**

Reaching *a* peer proves packets flow. It proves nothing about *whose* Node it
is. Identity is cryptographic and independent of route: an IP address, a DNS
name, a WebRTC peer id and a TURN allocation are all attacker-influenceable and
none of them are identity.

This is why there is one Node identity across every rung, and why a new
identity per transport would be a security regression rather than a
convenience.

---

## Threats and mitigations

### Node identity substitution

*An attacker answers instead of the user's Node.*

Every signaling envelope binds `nodeId` to the paired Node's stable identity and
is refused on mismatch. Completing a connection is never sufficient. **Status:
mitigated at the signaling layer; the peer-connection layer must also verify
identity after the channel opens, and that check lands with the WebRTC
implementation.**

### Signaling impersonation

*A third party injects offers/answers for someone else's session.*

Messages are bound to `sessionId`, `nodeId` and `deviceId`, and validated
against the local pairing record. A well-formed message describing another
party's session is refused. **Status: mitigated.**

### Replay

*A captured message is re-sent later.*

Single-use `nonce` plus short expiry. Both are checked on receipt; a sender
cannot grant itself a longer window by claiming one. **Status: mitigated.**

### Credential theft from SDP

*Long-lived secrets leak via session description.*

The permanent Node credential is never placed in SDP. Signaling carries session
identifiers and nonces only. **Status: mitigated by design; enforced when the
authenticated exchange lands.**

### Malicious ICE candidates

*Candidates used to probe or attack internal hosts.*

Candidates are exchanged only within a validated, identity-bound session and
are never persisted or logged. Standard ICE processing applies. **Status:
partially mitigated — candidate filtering policy belongs with the WebRTC
implementation.**

### Large-message DoS

*A peer sends a frame that exhausts memory.*

Payload capped at 64 KiB and metadata at 16 KiB per frame, enforced at both
encode and decode. **Status: mitigated, tested.**

### Lying length header

*A frame claims a payload far larger than it carries.*

The decoder verifies declared lengths against actual buffer size and rejects
mismatches. Trust the buffer, never the claim. **Status: mitigated, tested.**

### Chunk flooding

*A peer sends chunks faster than the receiver can drain them.*

`maxBufferedBytes` bounds accepted-but-undrained bytes; exceeding it terminates
the stream. Awaiting the sink provides natural backpressure. **Status:
mitigated, tested.**

### Disk exhaustion

*A peer streams forever, never sending a final frame.*

`maxTotalBytes` bounds a single reassembled stream. **Status: mitigated,
tested.**

### Stream injection

*Frames appended to a committed stream, or crossed between requests.*

Frames after a final frame are refused; frames whose `requestId` does not match
are refused. **Status: mitigated, tested.**

### Reassembly corruption

*Dropped, duplicated or reordered chunks produce a silently wrong capture.*

Total length plus order-sensitive CRC-32 in the final frame. Both failure modes
are tested; a same-length corruption is caught only by the checksum. **Status:
mitigated, tested.**

### Request duplication via failover

*A transport switch replays a mutation, creating two captures or two jobs.*

Only `isSafeToRetry` requests may move between routes: reads always, mutations
only with an idempotency key. Non-idempotent writes throw instead. **Status:
mitigated, tested.**

### Network topology disclosure

*An observer learns the operator's internal network.*

Presence records publish identity, capability and freshness only; LAN addresses
are excluded and enforced by `forbiddenKeys`. SDP and candidates are never
logged — `toLogSafeJson()` emits payload length only. **Status: mitigated,
tested.**

### Relay abuse

*TURN used as free bandwidth by third parties.*

Not yet implemented. Requires short-lived credentials issued by an
authenticated endpoint, quotas, rate limits and observability. Permanent TURN
credentials must never ship in the app. **Status: open — lands with TURN.**

### Public Kubo RPC exposure

*IPFS RPC reachable from the internet.*

Out of scope for this work and unchanged: Kubo RPC stays local-only. No rung
proxies it. **Status: unchanged, must remain NO.**

---

## Open items

These are genuinely not yet built, and are listed so they are not mistaken for
covered ground:

1. **Post-connection identity proof** — challenge/response over the established
   channel, binding the session to the Node identity.
2. **TURN credential issuance** — short-lived, authenticated, quota'd.
3. **Signaling rate limiting** — server-side.
4. **ICE candidate filtering policy**.

## Residual risk

The control plane observes *that* a device wishes to reach a Node, and when.
Content is never exposed, and retention is bounded to two minutes. This is
stated plainly rather than described as fully decentralised.
