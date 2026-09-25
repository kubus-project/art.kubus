# Artist Support Contract

## Current state

The app has wallet and KUB8 send operations, but the audited public artwork/profile model does not provide a verified artist-support recipient relationship or a purpose-bound support endpoint. `Artwork.artist` is a cultural attribution string. `Artwork.walletAddress` can identify an account associated with the record. Neither proves that the wallet belongs to the cultural artist or is an authorized recipient. An import account, owner, manager, artist profile, and payment recipient are distinct roles.

There is no safe current artist-support interaction. Public subject pages must keep the action hidden. No local-only balance change, generic wallet transfer, guessed recipient, simulated receipt, or "coming soon" control is permitted.

## Required eligibility

A server response must identify a public recipient tied to the cultural subject through an explicit, verified relationship. Eligible subjects should have a claimed/associated artist profile or a specifically authorized institution/project recipient. Imported/unclaimed works are ineligible by default. Ambiguous attribution or ownership fails closed.

## Future API/data contract

The backend should expose a purpose-bound support capability containing:

- recipient subject type and stable ID;
- verified public recipient ID and wallet/payment destination managed by the backend;
- explicit eligibility and supported assets/networks;
- minimum/maximum and available payment method rules;
- a server-created support intent and idempotency key;
- transfer result/receipt, including asset, amount, status, and transaction reference;
- privacy policy for notes and any optional public aggregate.

The client must not derive a recipient address from artist text or profile ownership. A future UX may offer preset amounts, custom amount, and an optional private note only after the backend supports the full operation. Recipient totals or donor rankings stay private unless recipient/platform policy explicitly opts into a public aggregate.

## Separation from contribution

Support transfers value to a verified recipient. Contribution points recognize verified archive work and are non-transferable. They must use separate APIs, ledgers, copy, and balances. Supporting an artist must not reduce a contribution score; earning recognition must not imply token ownership.
