import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'allowlists.dart';

/// Flags raw Material progress indicators outside the kubus loading
/// primitives so every loading state uses the branded language
/// (`InlineLoading` / `InlineProgress` / `AppLoading`).
class KubusNoRawProgressIndicator extends DartLintRule {
  const KubusNoRawProgressIndicator() : super(code: _code);

  static const _code = LintCode(
    name: 'kubus_no_raw_progress_indicator',
    problemMessage:
        'Raw progress indicator. Use InlineLoading / InlineProgress '
        '(lib/widgets/inline_loading.dart) so loading states stay on-brand.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.fullName;
    if (isAllowed(path, progressIndicatorAllowedSuffixes)) return;

    context.registry.addInstanceCreationExpression((node) {
      final name = node.constructorName.type.name.lexeme;
      if (name == 'CircularProgressIndicator' ||
          name == 'LinearProgressIndicator') {
        reporter.atNode(node, _code);
      }
    });
  }
}
