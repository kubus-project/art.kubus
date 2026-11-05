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

    // A venue record id, membership user id, owner wallet or other payload key
    // never proves a public account relation: those need an explicit target from
    // the verified account-link contract. A profile-backed institution, however,
    // is identified by its own account (its subject id is that account's wallet
    // or handle, not a venue record UUID), so that id is its own profile target.
    final normalizedInstitutionId = _normalizedText(institutionId);
    if (normalizedInstitutionId == null ||
        looksLikeInstitutionRecordId(normalizedInstitutionId)) {
      return null;
    }
    return normalizedInstitutionId;
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
