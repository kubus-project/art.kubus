import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/no_inline_google_fonts.dart';
import 'src/no_raw_backdrop_filter.dart';
import 'src/no_raw_border.dart';
import 'src/no_raw_color.dart';
import 'src/no_raw_progress_indicator.dart';

PluginBase createPlugin() => _KubusLintsPlugin();

class _KubusLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const KubusNoRawColor(),
        const KubusNoRawBorder(),
        const KubusNoRawBackdropFilter(),
        const KubusNoInlineGoogleFonts(),
        const KubusNoRawProgressIndicator(),
      ];
}
