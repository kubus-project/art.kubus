# art.kubus 0.7.5

Release 0.7.5 updates the frontend version to `0.7.5+26081002`.

## Highlights

- Measures campaign activation at real durable creation boundaries: artworks,
  events, exhibitions, and both marker-creation paths. A campaign participant
  who publishes their first artwork is now measurable without creating a map
  marker.
- Uses a bounded contribution taxonomy shared with the deployed backend and
  records first-contribution milestones per authenticated account rather than
  once per device installation.
- Preserves campaign entry routes for the English and Slovenian app roots and
  bounds campaign attribution to seven days.

## Reliability and privacy

- Campaign attribution now expires in long-lived web tabs and resumed mobile
  processes as well as across restarts; expired UTM and entry-route data cannot
  attach to later contributions.
- Telemetry remains first-party and fire-and-forget after a confirmed product
  mutation, so analytics failure cannot turn an artwork, event, exhibition, or
  marker creation into a failed action.

## Validation

- Focused campaign attribution, direct-entry, contract, contribution, and
  end-to-end activation tests passed.
- Strict Flutter analysis, architecture guard, documentation validation, and
  release CI are required before promotion.
