# WebRTC DataChannel protocol

How canonical Node operations travel over a peer connection.

## Principle

There is **one** Node API. WebRTC does not get its own routes.

A DataChannel implementation frames the *same* `/local/v1/...` operations that
HTTP carries. There is deliberately no `/webrtc/captures` or `/webrtc/jobs`:
duplicating the API per transport would mean every future route had to be
implemented, tested and kept consistent twice, and the two copies would drift.

`KubusNodeRequest` and `KubusNodeResponse` are therefore transport-neutral, and
mirror the shape of the existing local API rather than inventing a second
vocabulary.

## Frame layout

Big-endian, 16-byte header:

```text
  0       1       2       3       4              8
  +-------+-------+-------+-------+--------------+
  | magic | ver   | type  | flags | requestId    |
  +-------+-------+-------+-------+--------------+
  | metadataLength (u32) | payloadLength (u32)   |
  +----------------------+-----------------------+
  | metadata (UTF-8 JSON, metadataLength bytes)  |
  +----------------------------------------------+
  | payload (payloadLength bytes)                |
  +----------------------------------------------+
```

Metadata is JSON: small, self-describing, versionable. Payload stays **raw
bytes** — base64-ing a capture would inflate it by roughly a third for no
benefit, which is the same mistake the node-side streaming upload was
introduced to fix.

### Types

| Value | Type | Purpose |
| ----- | ---- | ------- |
| 1 | `requestHead` | Opens a request; method/path/query/headers in metadata |
| 2 | `requestChunk` | Request body chunk |
| 3 | `responseHead` | Opens a response; status in metadata |
| 4 | `responseChunk` | Response body chunk |
| 5 | `cancel` | Caller abandoned; receiver stops work |
| 6 | `windowUpdate` | Application-level backpressure |
| 7 | `error` | Transport-level failure for one request |

`flagFinal` (0x01) marks the last frame of a body, so a receiver knows a stream
*ended* rather than *stalled*.

`requestId` correlates chunks and responses, so one channel carries several
operations without ambiguity.

## Channel strategy

**One reliable, ordered DataChannel.**

Separate control/upload/download channels were considered and rejected. SCTP
already multiplexes by `requestId` at the application layer, additional
channels multiply negotiation and failure modes, and mobile/browser
implementations are most reliable on the well-trodden single-channel path.
Head-of-line blocking is bounded because payload frames are capped at 64 KiB —
no single frame can monopolise the channel for long.

If a future workload genuinely suffers (large download concurrent with an
interactive request), a second channel can be added without changing the frame
format.

## Size bounds

- **Payload:** 64 KiB per frame. Comfortably inside every implementation's
  limits, and bounds the cost of one malicious frame.
- **Metadata:** 16 KiB per frame.

A 100 MB capture therefore becomes thousands of bounded frames rather than one
message a peer must hold whole.

## Streaming

`KubusFrameSplitter` never materialises the source. It coalesces tiny source
events so a byte-at-a-time stream does not produce a frame per byte, and
re-splits large ones so a single big read cannot emit an oversized frame.
Memory stays flat regardless of how the source chunks.

`KubusStreamReassembler` is push-based and sink-oriented: each chunk is handed
onward (to disk, in practice) as it arrives. **Awaiting the sink is the
backpressure** — a slow disk slows acceptance rather than growing an unbounded
queue.

### Bounds, each a threat-model case

| Bound | Prevents |
| ----- | -------- |
| `maxBufferedBytes` | Peer flooding chunks faster than the sink drains |
| `maxTotalBytes` | Peer filling the disk by never sending a final frame |
| Frame after final | Appending to a committed stream |
| Mismatched `requestId` | Cross-request injection |

## Integrity

The final frame carries total length and a CRC-32.

DTLS already guarantees the bytes on the wire, so this is **not** about
transmission corruption. It catches *reassembly* faults — dropped, duplicated
or misordered chunks — which are our own bugs and would otherwise surface much
later as an unreadable capture. Both cases are tested: a dropped chunk fails
the length check, and a same-length corrupted chunk fails the checksum, which
nothing else would catch.

CRC-32 is verified against the standard IEEE check value (`0xCBF43926`) rather
than only against itself.

## Hardening

Rejected at decode, with tests:

- A declared length disagreeing with the bytes present — the cheapest possible
  DoS. Trust the buffer, never the claim.
- Foreign or corrupt messages, via the magic byte.
- A version mismatch, as a **distinct typed error** so it can be reported as
  "update one side" rather than "corrupt data".
- Metadata that is not valid JSON, or is not an object.

## Files

- `lib/services/node/webrtc_frame.dart` — frame format and codec
- `lib/services/node/webrtc_frame_stream.dart` — chunking, reassembly, CRC-32
