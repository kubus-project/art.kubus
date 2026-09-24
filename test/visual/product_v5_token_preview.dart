import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/utils/app_color_utils.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/general_background.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/kubus_card.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ProductV5TokenPreview());

class ProductV5TokenPreview extends StatefulWidget {
  const ProductV5TokenPreview({super.key});

  @override
  State<ProductV5TokenPreview> createState() => _ProductV5TokenPreviewState();
}

class _ProductV5TokenPreviewState extends State<ProductV5TokenPreview> {
  late final ThemeProvider _themes = ThemeProvider();
  bool _dark = false;
  bool _largeText = false;

  @override
  void dispose() {
    _themes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PRODUCT v5 token preview',
      debugShowCheckedModeBanner: false,
      theme: _themes.lightTheme,
      darkTheme: _themes.darkTheme,
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        final platformMedia = MediaQuery.of(context);
        return MediaQuery(
          data: platformMedia.copyWith(
            textScaler: TextScaler.linear(_largeText ? 2 : 1),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _TokenPreviewPage(
        dark: _dark,
        largeText: _largeText,
        onDarkChanged: (value) => setState(() => _dark = value),
        onLargeTextChanged: (value) => setState(() => _largeText = value),
      ),
    );
  }
}

class _TokenPreviewPage extends StatelessWidget {
  const _TokenPreviewPage({
    required this.dark,
    required this.largeText,
    required this.onDarkChanged,
    required this.onLargeTextChanged,
  });

  final bool dark;
  final bool largeText;
  final ValueChanged<bool> onDarkChanged;
  final ValueChanged<bool> onLargeTextChanged;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return KubusProductBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('PRODUCT v5 tokens', style: KubusTextStyles.screenTitle),
          actions: [
            IconButton(
              tooltip: dark ? 'Use light theme' : 'Use dark theme',
              onPressed: () => onDarkChanged(!dark),
              icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode),
            ),
            IconButton(
              tooltip:
                  largeText ? 'Use regular text size' : 'Use 200% text size',
              onPressed: () => onLargeTextChanged(!largeText),
              icon: const Icon(Icons.text_fields),
            ),
            const SizedBox(width: KubusSpacing.xs),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Shared token and primitive fixture',
                          style: KubusTextStyles.lede),
                      const SizedBox(height: KubusSpacing.xl),
                      _Section(
                        title: 'Ground and surfaces',
                        child: Wrap(
                          spacing: KubusSpacing.md,
                          runSpacing: KubusSpacing.md,
                          children: [
                            _SurfaceSample(
                              name: 'Ground',
                              color: roles.ground,
                              foreground: roles.foreground,
                              rule: roles.rule,
                              width: constraints.maxWidth < 600 ? 280 : 235,
                            ),
                            _SurfaceSample(
                              name: 'Surface',
                              color: roles.surface,
                              foreground: roles.foreground,
                              rule: roles.rule,
                              width: constraints.maxWidth < 600 ? 280 : 235,
                            ),
                            _SurfaceSample(
                              name: 'Raised surface',
                              color: roles.surfaceRaised,
                              foreground: roles.foreground,
                              rule: roles.rule,
                              width: constraints.maxWidth < 600 ? 280 : 235,
                            ),
                            _SurfaceSample(
                              name: 'Overlay / explicit glass',
                              color: roles.surfaceOverlay,
                              foreground: roles.foreground,
                              rule: roles.rule,
                              width: constraints.maxWidth < 600 ? 280 : 235,
                              glass: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.lg),
                      _Section(
                        title: 'Foreground and rules',
                        child: KubusCard(
                          padding: const EdgeInsets.all(KubusSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Foreground',
                                  style: KubusTextStyles.body
                                      .copyWith(color: roles.foreground)),
                              Text('Muted foreground',
                                  style: KubusTextStyles.body
                                      .copyWith(color: roles.foregroundMuted)),
                              Text('Subtle foreground',
                                  style: KubusTextStyles.body
                                      .copyWith(color: roles.foregroundSubtle)),
                              const SizedBox(height: KubusSpacing.sm),
                              Divider(color: roles.rule, height: 1),
                              const SizedBox(height: KubusSpacing.sm),
                              Container(height: 2, color: roles.ruleStrong),
                              const SizedBox(height: KubusSpacing.sm),
                              Text('Active and focus use one family blue',
                                  style: KubusTypography.structural(
                                    fontSize: 11,
                                    color: roles.active,
                                  )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.lg),
                      _Section(
                        title: 'Button roles',
                        child: Wrap(
                          spacing: KubusSpacing.sm,
                          runSpacing: KubusSpacing.sm,
                          children: [
                            KubusButton(
                              onPressed: () {},
                              label: 'Primary',
                              icon: Icons.arrow_forward,
                            ),
                            KubusButton(
                              onPressed: () {},
                              label: 'Secondary',
                              variant: KubusButtonVariant.secondary,
                            ),
                            KubusButton(
                              onPressed: () {},
                              label: 'Quiet',
                              variant: KubusButtonVariant.quiet,
                            ),
                            KubusButton(
                              onPressed: () {},
                              label: 'Destructive',
                              variant: KubusButtonVariant.destructive,
                            ),
                            KubusButton(
                              onPressed: () {},
                              label: 'Contextual · success',
                              variant: KubusButtonVariant.contextual,
                              backgroundColor: roles.success,
                            ),
                            const KubusButton(
                              onPressed: null,
                              label: 'Disabled',
                              variant: KubusButtonVariant.secondary,
                            ),
                            KubusButton(
                              onPressed: () {},
                              label: 'Loading',
                              isLoading: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.lg),
                      _Section(
                        title: 'Chips and semantic status',
                        child: Wrap(
                          spacing: KubusSpacing.sm,
                          runSpacing: KubusSpacing.sm,
                          children: [
                            const KubusChip(label: 'Neutral tag'),
                            KubusChip(
                              label: 'Success',
                              backgroundColor: roles.success,
                            ),
                            _StatusSample('Warning', roles.warning),
                            _StatusSample('Error', roles.error),
                            _StatusSample('Personal accent', roles.userAccent),
                          ],
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.lg),
                      _Section(
                        title: 'Typography registers',
                        child: KubusCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Sofia Sans carries content and actions.',
                                  style: KubusTypography.content(fontSize: 20)),
                              const SizedBox(height: KubusSpacing.sm),
                              Text('STRUCTURAL LABEL · 03',
                                  style: KubusTextStyles.structuralLabel),
                              const SizedBox(height: KubusSpacing.xs),
                              Text('48.1374, 11.5755 · v5.0.0',
                                  style: KubusTextStyles.machineValue),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.lg),
                      _Section(
                        title: 'Accent stays separate from structure',
                        child: Text(
                          'ColorScheme.primary remains the family active role. '
                          'The user accent is available only through '
                          'KubusColorRoles.userAccent.',
                          style: KubusTextStyles.body.copyWith(
                            color: roles.foregroundMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SurfaceSample extends StatelessWidget {
  const _SurfaceSample({
    required this.name,
    required this.color,
    required this.foreground,
    required this.rule,
    required this.width,
    this.glass = false,
  });

  final String name;
  final Color color;
  final Color foreground;
  final Color rule;
  final double width;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: KubusCard(
        isGlass: glass,
        color: color,
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: KubusTypography.content(
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            Container(height: 1, color: rule),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              style: KubusTextStyles.metadataRegister.copyWith(
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusSample extends StatelessWidget {
  const _StatusSample(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Chip(
        label: Text(
          label,
          style: KubusTypography.content(
            color: AppColorUtils.onColor(color),
          ),
        ),
        backgroundColor: color,
        side: BorderSide.none,
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
            child: Text(title, style: KubusTextStyles.sectionTitle),
          ),
          child,
        ],
      );
}
