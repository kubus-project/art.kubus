# Community composer correction evidence

These are reviewed Flutter widget-test captures, not real authenticated browser acceptance. The test uses existing profile/token seams and a fake picker with distinct valid numbered PNG fixtures. Image codec completion and decoded thumbnail frames are asserted before capture. The full strip is scrolled into view; square previews intentionally crop with BoxFit.cover.

- 390x844 light English, and 1.5x text.
- 320px dark Slovenian.
- 1440x1000 dark Slovenian desktop dialog at 1.5x text.
- 1440x1000 tray with ten mixed items, uploading/locked and failed states.
- 320px dark tray at 2x text after reorder and removal.

Reproduce with KUBUS_RUN_VISUAL_QA=1 and COMMUNITY_MULTI_MEDIA_ENABLED=true in test/qa/community_composer_visual_test.dart. Output goes to output/qa/community-composer. No production browser session or deployment is represented by these screenshots.
