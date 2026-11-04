import 'package:flutter/material.dart';

import '../screens/desktop/desktop_shell.dart';
import '../screens/web3/institution/institution_detail_screen.dart';
import 'user_profile_navigation.dart';

class InstitutionNavigation {
  InstitutionNavigation._();

  static Future<void> open(
    BuildContext context, {
    required String institutionId,
    String? profileTargetId,
    Map<String, dynamic>? data,
    String? title,
    Future<void> Function(String profileTargetId)? openProfileTarget,
  }) async {
    final resolvedProfileTargetId = resolveProfileTargetId(
      institutionId: institutionId,
      explicitProfileTargetId: profileTargetId,
      data: data,
    );
    if (resolvedProfileTargetId != null) {
      if (openProfileTarget != null) {
        await openProfileTarget(resolvedProfileTargetId);
        return;
      }
      await UserProfileNavigation.open(
        context,
        userId: resolvedProfileTargetId,
      );
      return;
    }

    final resolvedInstitutionId = institutionId.trim();
    if (resolvedInstitutionId.isEmpty) return;

    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final shellScope = isDesktop ? DesktopShellScope.of(context) : null;
    final screen = InstitutionDetailScreen(
      institutionId: resolvedInstitutionId,
      embedded: shellScope != null,
    );

    if (shellScope != null) {
      shellScope.pushScreen(
        DesktopSubScreen(
          title: _normalizedText(title) ?? 'Institution',
          child: screen,
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static String? resolveProfileTargetId({
    String? institutionId,
    String? explicitProfileTargetId,
    Map<String, dynamic>? data,
  }) {
    final explicit = _normalizedText(explicitProfileTargetId);
    if (explicit != null) return explicit;

    // A venue id, membership user id, owner wallet, or arbitrary payload key
    // never proves a public account relation. Callers must pass an explicit
    // profile target obtained from the verified account-link contract.
    return null;
  }

  static bool looksLikeInstitutionRecordId(String value) {
    return _uuidPattern.hasMatch(value.trim());
  }

  static String? _normalizedText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );
}
