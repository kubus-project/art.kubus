# Profile gallery and basic curation — v0.8.8

Status, 17 November 2026: the owner selected **Gallery wall** as the default, requested tighter image-led cards with equal spacing on all sides, and retained **Folded rooms** and **Reading field** as selectable curation layouts. The storage, permission and publication contract below is a proposal awaiting owner approval. It does not authorize a production migration, merge or deployment.

Requirement: `AMEND-PROFILE-GALLERY-001`, alongside existing profile, attribution and media requirements. This is v0.8.8 work. Dedicated curator identities, organization invitations, multi-curator commissioning and independent curator exhibitions remain v0.9.

## Visual decision

The real reference is [rokcernezel.com/portfolio](https://rokcernezel.com/portfolio/), inspected in a rendered browser on 17 November: artwork-led footprints, varied scale, quiet captions, spatial depth and open ground. Reuse that compositional discipline, not its navigation shell, Atlas renderer, project taxonomy or content. The Flutter PRODUCT design system remains authoritative.

- **Gallery wall (`wall`, default):** shallow planes, a clear reading order and image-sized frames. The artwork's source ratio determines its footprint; the frame does not stretch to fill its column. Use one shared inset on all four sides (16 logical pixels at the normal density), with captions aligned to the image edge. Retain complete images without cropping. Cards remain centered in their available slots.
- **Folded rooms (`rooms`):** paired shallow planes using the same artwork/media/caption primitives and saved ordering.
- **Reading field (`field`):** a lead work and smaller works interleaved with available descriptions, preserving the same underlying order and identity.

All three appear in the owner's **Curate gallery → Layout** menu. Changing layout preserves item and section order; it does not republish or discard edits. Visitors see the host's published choice. It is not a device-local visitor preference.

Use Sofia Sans, existing semantic theme/spacing tokens and the shared media resolver. Avoid nested dashboard cards, visible eyebrow labels, invented metrics and arbitrary placeholders. No parallax or automatic movement is needed for comprehension. Reduced motion keeps every work, caption and action available in normal scrolling order.

The isolated review prototype is under programme `output/playwright/v088-gallery/`. Refined A was rendered at 1440,393 and320 pixels in light/dark with reduced motion: all images loaded, all frame insets measured16px, and no horizontal overflow. This is design proof, not Flutter or persistence acceptance.

## Shared component ownership

One shared Flutter gallery and curation controller serve profile, exhibition and institution host adapters. The three modes are layout strategies within this component, not separate renderers or a new CMS. Desktop and mobile use the same provider, domain model, media rules, order and revision.

Each host adapter obtains its permitted items from the existing canonical content relationship resolver. Artist profiles use canonical `profiles.id` authorship, including walletless accounts; uploader/owner is not automatically cultural author. Exhibition and institution adapters do not create content ownership, attribution, membership or new institution-event relations. A host with no eligible works has a truthful empty state.

## Persisted state

Proposed backend table `entity_presentation_layouts` has nullable `profile_id`, `exhibition_id` and `institution_id` foreign keys, a check requiring exactly one host, and a unique partial index for each host. This avoids confusing profile, account and institution UUID namespaces. It stores `revision`, private `draft_layout`, `published_layout`, `published_revision`, publication/update timestamps and the updating `users.id`. Deleting a host follows the existing host deletion/retention contract; no layout action deletes artwork.

No row means the current automatic order. The schema change must update both backend snapshots and have fresh/upgrade/idempotency/rollback PostgreSQL proof before any owner-approved production application. Do not put public layout state into the profile preferences object, which also contains private account preferences.

Layout schema version1:

```json
{
  "schemaVersion": 1,
  "mode": "wall",
  "artworkOrder": ["canonical-artwork-uuid"],
  "artworkSizes": {"canonical-artwork-uuid": "standard"},
  "leadArtworkId": null,
  "sectionOrder": ["identity", "work", "publicArt", "activity", "recognition", "stats"],
  "hiddenSections": []
}
```

These UUID strings illustrate the type; persisted values must be real canonical UUIDs. Allowed artwork sizes are `small`, `standard` and `lead`, mapped to shared responsive tokens. No media URLs, CSS, colors, arbitrary HTML, author labels or credentials are stored. The server validates bounds and duplicate/unknown IDs, host applicability and current eligibility. Published output never includes private draft IDs.

For profiles, use the actual `ProfileSection` IDs in `profile_section_order.dart`: `identity` is fixed first; `ownerTools` is private, fixed last and never accepted in a public layout. Applicable public sections can be reordered or hidden. Hiding a section is a presentation choice, not withdrawal or deletion of its records. Exhibition/institution adapters declare their own bounded existing section IDs; do not reuse profile IDs by pretending those hosts are profiles.

## Permission contract

Bearer authority and current `users.id` establish editor identity. A profile UUID is never treated as an account UUID, and a wallet is not required.

| Host | Save and preview draft | Publish |
|---|---|---|
| Personal/artist profile | Current canonical profile owner | Same owner |
| Exhibition | Existing owner and existing collaboration roles accepted by `canEditEntity` | Existing owner and roles accepted by `canPublishEntity` |
| Institution | Existing institution write authority under the current claimant/admin contract | The same existing authorized publisher; no new professional identity or invitation flow |

Existing exhibition role thresholds are edit from `curator`, publish from `publisher`; this reuses an existing collaboration role and does not introduce the v0.9 curator identity. Do not create profile collaborators or new institution member capabilities as an incidental feature. If an existing host resolver cannot establish authority, fail closed and withhold the edit controls. Administrative authority follows existing backend rules; it does not bypass closure, restriction or media holds.

Resolve authorization on every save, preview and publish in the current transaction/context, including membership revocation while the editor is open. Account switching clears controller data and cancels/discards requests from the previous account epoch.

## API and concurrency

The exact route naming can follow backend conventions; behavior is fixed:

- Public GET returns only the current published host presentation and currently public typed item DTOs, under the existing public restriction/read fence. No raw draft or private layout source is exposed.
- Authenticated draft GET is private/no-store and requires current editor authority.
- Draft save requires `expectedRevision` (or equivalent `If-Match`) and an idempotency key. Validate and write atomically under the row lock; revision increments on a successful mutation.
- Publish requires the current revision, current publish authority and current content/media eligibility. Copy the validated draft into published state in the same transaction and queue the existing host public-sync/outbox operation. Publish increments revision and records the published revision.
- Conflicting revisions return409 with authorized current revision information; do not silently overwrite, merge, retry or replay a stale action. The editor offers Reload and keeps unsaved local changes available for deliberate reconciliation.
- Repeating the same idempotency key and payload returns the original result. A changed payload with the same key is rejected. Validation and authority failures never report success.

No separate gallery mirror/store or publication scheduler is introduced. Reuse the host's existing public projection/outbox. Private drafts never enter public sync. A local successful save is not proof of mirror propagation or public publication acceptance.

## Preview, publication and media

**Preview** uses the editor's authorized draft in the same component. **Save draft** persists only draft state. **Publish** changes the public presentation after the revision/authorization checks. **Reset to automatic** changes the draft first and requires explicit publication to change visitors' view. Controls appear only when they perform these actions.

Public projections and cached responses must recheck current host/item privacy, editorial state, linked-account activity, closure and independent restrictions. Hidden references are omitted before public serialization. If a saved item becomes unavailable, the owner gets an accurate unavailable state without exposing its private media to visitors; remaining items keep their order.

Use the existing protected media/detail authority and preview transport from backend225/client440; do not accept a stale snapshot or Orbit fallback as current media authorization. No public/external media fetch occurs before the applicable current authority succeeds. Failed authority, expired read fences and account changes fail closed. Do not crop artworks, invent missing covers, or rewrite cultural author credits. Cached already-public copies have the documented independent-copy limits; do not promise erasure.

## Accessibility and acceptance

Every drag reorder has equivalent keyboard/menu Move earlier/Move later actions, announced position and preserved focus. DOM/semantics order follows the saved reading order. Pointer perspective is optional; reduced motion disables parallax/moving depth. Text scaling grows captions and controls without clipping or shrinking all text. Keep normal scrolling, canonical links, browser Back, and real touch targets.

Required acceptance: owner/visitor/guest and revoked-editor cases; accountA→B; concurrent save/publish; save→reload→publish; all three layout choices; artist/exhibition/institution host adapters; six real HOF works plus an unrelated eligible profile; long names, text-heavy and missing-cover records; EN/SL; light/dark; desktop,393 and320; larger text; reduced motion; Chromium/Firefox and required native evidence. Real PostgreSQL, source-matched rendered tests and independent authorization/privacy review precede release acceptance.

## Approval and implementation order

The visual direction and B/C availability are owner-selected. Approval of this concrete storage/permission/publication proposal authorizes backend-first engineering, focused tests, review, commits and small PRs. It does not authorize protected merges, production migrations, deployment or final release acceptance.

After approval: backend storage/auth/versioning and projection → shared Flutter presentation and truthful curation controls → source-matched cross-account/concurrency/media E2E → independent review and exact-head CI. Retain all outstanding original deep-review and operational gates; v0.8.8 is not accepted merely because this document or prototype is reconciled.
