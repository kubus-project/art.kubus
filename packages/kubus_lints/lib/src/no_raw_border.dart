import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'allowlists.dart';

/// Flags `Border.all(...)` / `BorderSide(...)` whose `color:` argument is an
/// inline `Color` literal or `Colors.*` constant. Use `KubusBorders.*`.
class KubusNoRawBorder extends DartLintRule {
  const KubusNoRawBorder() : super(code: _code);

  static const _code = LintCode(
    name: 'kubus_no_raw_border',
    problemMessage:
        'Ad-hoc border color. Use KubusBorders.hairline/glass/focus/active/'
        'accentTint (lib/utils/design_tokens.dart).',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.fullName;
    // KubusBorders itself lives in design_tokens.dart (allowlisted).
    if (isAllowed(path, rawColorAllowedSuffixes)) return;

    void check(AstNode node, ArgumentList args) {
      for (final arg in args.arguments) {
        if (arg is! NamedExpression) continue;
        if (arg.name.label.name != 'color') continue;
        final expr = arg.expression.unParenthesized;
        final src = expr.toSource();
        final isRaw = src.startsWith('Color(') ||
            src.startsWith('Color.from') ||
            src.startsWith('Colors.');
        if (isRaw) reporter.atNode(node, _code);
      }
    }

    context.registry.addInstanceCreationExpression((node) {
      final name = node.constructorName.toSource();
      if (name == 'BorderSide' || name == 'Border.all') {
        check(node, node.argumentList);
      }
    });
    context.registry.addMethodInvocation((node) {
      // `Border.all` is a const factory; without `const`/`new` it parses as
      // a MethodInvocation, not an InstanceCreationExpression.
      if (node.target?.toSource() == 'Border' &&
          node.methodName.name == 'all') {
        check(node, node.argumentList);
      }
    });
  }
}
