import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../config/config.dart';
import 'community_video_network.dart';

/// A feed clip that may start muted by itself. The video slide implements it.
abstract class CommunityVideoAutoplayCandidate {
  /// Share of the clip on screen, from 0 to 1.
  double get autoplayVisibleFraction;

  /// Whether a running autoplay may continue: its page is the active one, it is
  /// not a compact preview, the viewer has not paused it by hand, and reduced
  /// motion is off. Routes, fullscreen and tickers do not end an autoplay here;
  /// the clip pauses itself for those and the scheduler then releases it.
  bool get autoplayAllowed;

  /// Whether this clip may start an autoplay now: [autoplayAllowed], and it is
  /// on the current route, not in fullscreen, not already holding a player.
  bool get autoplayMayStart;

  /// The viewer started this clip, so it plays with its own sound.
  bool get playingWithSound;

  /// Autoplay owns the clip, starting or muted and playing.
  bool get autoplayOwned;

  /// The autoplay is still starting, or the clip is playing muted.
  bool get autoplayPlaying;

  /// Starts a silent playback. Completes false when it could not start.
  Future<bool> startAutoplay();

  /// Pauses and releases an autoplaying clip, back to its poster.
  void stopAutoplay();
}

/// Autoplays at most one feed video at a time, muted.
///
/// One static timer runs only while candidates exist. A clip starts once it has
/// been at least [startFraction] on screen for [dwell] (two ticks), and stops
/// once it falls below [stopFraction]; in between it keeps its state. Each
/// visit gets one attempt. A clip the viewer started with sound is never
/// interrupted, and the sound is handled by the clip itself, not here.
class CommunityVideoAutoplay {
  CommunityVideoAutoplay._();

  static const Duration tickInterval = Duration(milliseconds: 250);
  static const Duration dwell = Duration(milliseconds: 300);
  static const Duration retryCooldown = Duration(seconds: 30);
  static const double startFraction = 0.6;
  static const double stopFraction = 0.4;

  /// Tests set this to force the feature on or off. Null uses the build flag
  /// and the browser's data-saver request.
  @visibleForTesting
  static bool? enabledOverride;

  static bool get enabled {
    final override = enabledOverride;
    if (override != null) return override;
    return AppConfig.isFeatureEnabled('communityVideoAutoplay') &&
        !communityVideoDataSaverEnabled();
  }

  static final List<CommunityVideoAutoplayCandidate> _candidates =
      <CommunityVideoAutoplayCandidate>[];
  static final Map<CommunityVideoAutoplayCandidate, _Visit> _visits =
      <CommunityVideoAutoplayCandidate, _Visit>{};
  static CommunityVideoAutoplayCandidate? _owner;
  static Timer? _timer;

  /// Adds [candidate] and starts the timer. While autoplay is off (flag,
  /// data saver) nothing is registered and no timer is created, so a disabled
  /// feed costs no polling at all.
  static void register(CommunityVideoAutoplayCandidate candidate) {
    if (!enabled) return;
    if (_candidates.contains(candidate)) return;
    _candidates.add(candidate);
    _visits[candidate] = _Visit();
    _timer ??= Timer.periodic(tickInterval, (_) => tick());
  }

  static void unregister(CommunityVideoAutoplayCandidate candidate) {
    _candidates.remove(candidate);
    _visits.remove(candidate);
    if (identical(_owner, candidate)) _owner = null;
    if (_candidates.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// True when a candidate other than [candidate] plays with the viewer's sound.
  static bool soundPlayingElsewhere(
    CommunityVideoAutoplayCandidate candidate,
  ) {
    return _candidates.any(
      (other) => !identical(other, candidate) && other.playingWithSound,
    );
  }

  @visibleForTesting
  static int get candidateCount => _candidates.length;

  @visibleForTesting
  static bool get timerRunning => _timer != null;

  /// One scheduling step. Runs from the timer; tests call it directly.
  @visibleForTesting
  static void tick() {
    final on = enabled;
    if (!on) {
      // Switched off while clips are still mounted: stop the timer and end any
      // running autoplay. Registration is refused until it is switched back on.
      _timer?.cancel();
      _timer = null;
      final running = _owner;
      if (running != null) {
        _owner = null;
        running.stopAutoplay();
      }
      return;
    }
    final now = DateTime.now();

    final owner = _owner;
    if (owner != null) {
      final visit = _visits[owner];
      if (!owner.autoplayOwned) {
        // The viewer took the sound (the clip keeps playing for them) or the
        // clip was released elsewhere. Either way this visit gets no retry.
        _owner = null;
        visit?.consumed = true;
      } else if (!on ||
          !owner.autoplayAllowed ||
          owner.autoplayVisibleFraction < stopFraction ||
          !owner.autoplayPlaying) {
        // Left the screen, switched off, or paused by something else (a
        // lifecycle change, a covering route). One attempt per visit: the
        // clip waits until it leaves the screen and comes back.
        _owner = null;
        owner.stopAutoplay();
        visit?.consumed = true;
      }
    }

    final soundPlaying = _candidates.any((c) => c.playingWithSound);
    for (final candidate in List<CommunityVideoAutoplayCandidate>.of(
      _candidates,
    )) {
      final visit = _visits[candidate];
      if (visit == null) continue;
      final fraction = candidate.autoplayVisibleFraction;
      if (fraction < stopFraction) {
        // Left the screen: this visit is over, the next one may start afresh.
        visit
          ..dwellMs = 0
          ..consumed = false;
        continue;
      }
      if (fraction < startFraction ||
          identical(_owner, candidate) ||
          candidate.autoplayOwned ||
          !on ||
          !candidate.autoplayMayStart ||
          visit.consumed) {
        visit.dwellMs = 0;
        continue;
      }
      final failedAt = visit.failedAt;
      if (failedAt != null && now.difference(failedAt) < retryCooldown) {
        visit.dwellMs = 0;
        continue;
      }
      visit.dwellMs += tickInterval.inMilliseconds;
      if (visit.dwellMs < dwell.inMilliseconds) continue;
      if (_owner != null || soundPlaying) continue;

      // One start per tick, so the first clip to dwell wins.
      visit
        ..dwellMs = 0
        ..consumed = true;
      _owner = candidate;
      unawaited(_start(candidate));
      break;
    }
  }

  static Future<void> _start(CommunityVideoAutoplayCandidate candidate) async {
    final started = await candidate.startAutoplay();
    if (started) return;
    if (identical(_owner, candidate)) _owner = null;
    _visits[candidate]?.failedAt = DateTime.now();
  }
}

class _Visit {
  int dwellMs = 0;
  bool consumed = false;
  DateTime? failedAt;
}
