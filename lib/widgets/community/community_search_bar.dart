import 'package:flutter/material.dart';

import '../../widgets/search/kubus_general_search.dart';
import '../../widgets/search/kubus_search_controller.dart';
import '../../utils/design_tokens.dart';

class CommunitySearchBar extends StatelessWidget {
  const CommunitySearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.semanticsLabel,
    this.onSubmitted,
    this.trailingBuilder,
    this.width,
    this.height = KubusHeaderMetrics.searchBarHeight,
  });

  final KubusSearchController controller;
  final String hintText;
  final String semanticsLabel;
  final ValueChanged<String>? onSubmitted;
  final Widget Function(BuildContext context, String query)? trailingBuilder;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final search = KubusGeneralSearch(
      controller: controller,
      hintText: hintText,
      semanticsLabel: semanticsLabel,
      onSubmitted: onSubmitted,
      trailingBuilder: trailingBuilder,
    );

    if (width == null) {
      return SizedBox(height: height, child: search);
    }

    return SizedBox(
      width: width,
      height: height,
      child: search,
    );
  }
}
