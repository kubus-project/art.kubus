# Wave 5A character rebalance: visual evidence

Pairs show BEFORE (`dev@4dc26a17`, the Wave 4C merge) on the left and
AFTER (`339eff1a`, clean tree) on the right. Both come from the same local
fixtures, rendered by
`test/qa/product_v5_character_rebalance_visual_matrix_test.dart` with real
Sofia Sans and Space Mono.

```
KUBUS_RUN_VISUAL_QA=1 QA_LABEL=after flutter test test/qa/product_v5_character_rebalance_visual_matrix_test.dart
```

| Scene | What to look at |
| --- | --- |
| A, J profile 1440 dark / light | One header row; stat and Performance tiles with context icons and no clipping (BEFORE clips every tile) |
| B profile header 900–1920 | Back, Profile and utilities share one row; BEFORE has a second action band |
| C, J settings desktop dark / light SL | Marketing / Activity / Essential groups, separate App notifications, flat sidebar, teal ON; BEFORE is one long table under a blue banner |
| D settings mobile | Same groups; essential mail locked ON (BEFORE shows it OFF) |
| E artwork editor | One rail with hairline sections, readiness glyphs, no nested Collaboration card |
| F, G Artist Studio / Institution Hub | Rail no longer repeats the hub title; numbers carry context tiles |
| H, I wallet desktop / mobile / light SL | Canonical KUB8 lattice mark leads the balance; SOL unchanged; the wrong-mint "KUB8" stays generic |
| X profile 1280 at 200 % text | BEFORE: 50–71 px overflow on every stat; AFTER: none |
| X wallet 320 SL | Full balance, no ellipsis |
| X settings / wallet / editor at 200 % (AFTER only) | Large-text layouts; the settings dialog itself is not text-scaled by the harness |

Scene D's BEFORE was recaptured from the same commit after fixing a
harness-only provider error; the invalid original is kept out of this set.
Text scaling here is Flutter's; a human browser-zoom pass is still
required.
