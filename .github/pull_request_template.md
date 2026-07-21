## Change summary

- Problem and outcome:
- Target branch (`dev` for ordinary work; `master` only for release/hotfix):
- Source branch:
- Affected deployment environment (`none`, `development-web`, `production-web`, `android-release`, `ios-release`):

## Validation

- [ ] Local validation commands and actual results are listed below
- [ ] `PR validation required` completed or is expected to complete
- [ ] UI screenshots/recordings are attached when appearance or layout changed
- [ ] Responsive mobile/desktop parity was checked where applicable
- [ ] Staging verification is described when deployment behavior changed

Commands and results:

```text

```

## Impact and recovery

- Backend/API impact:
- Database/schema impact (both snapshots updated when applicable):
- Release relevance:
- Rollback notes:
- [ ] No credential, token, key, Basic Auth value, or secret-bearing artifact was added
- [ ] Feature flags, theme/token rules, provider initialization, and async context safety were considered

## Release PR only (`dev` or `hotfix/*` -> `master`)

- [ ] Source provenance is `dev` or `hotfix/*`
- [ ] This PR will use a merge commit, not squash
- [ ] Staging serves the exact candidate SHA and required checks are green
- [ ] Production deployment remains gated and has not been approved or run by this PR
- [ ] Version/artifact metadata and rollback ownership are recorded
- [ ] A hotfix reconciliation PR into `dev` exists or is explicitly assigned
