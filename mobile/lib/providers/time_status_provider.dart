import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'dart:math';

class TimeStatus {
  final int dailyLimitMinutes;
  final int minutesUsed;
  final bool hasLimit;
  final bool isManuallyBlocked;
  final bool isBedtimeBlocked;
  final bool isExamMode;
  final String? bedtimeStartStr;
  final String? bedtimeEndStr;
  final List<String> blockedNetworkApps;
  final int minutesRemaining;

  TimeStatus({
    this.dailyLimitMinutes = 0,
    this.minutesUsed = 0,
    this.hasLimit = false,
    this.isManuallyBlocked = false,
    this.isBedtimeBlocked = false,
    this.isExamMode = false,
    this.bedtimeStartStr,
    this.bedtimeEndStr,
    this.blockedNetworkApps = const [],
    this.minutesRemaining = 0,
  });

  factory TimeStatus.fromMap(Map<dynamic, dynamic> map) {
    final limit = map['daily_limit_minutes'] ?? 0;
    final used = map['minutes_used'] ?? 0;
    final hasLimit = map['has_limit'] ?? false;
    
    return TimeStatus(
      dailyLimitMinutes: limit,
      minutesUsed: used,
      hasLimit: hasLimit,
      isManuallyBlocked: map['is_manually_blocked'] ?? false,
      isBedtimeBlocked: map['is_bedtime_blocked'] ?? false,
      isExamMode: map['is_exam_mode'] ?? false,
      bedtimeStartStr: map['bedtime_start'],
      bedtimeEndStr: map['bedtime_end'],
      blockedNetworkApps: List<String>.from(map['blocked_network_apps'] ?? []),
      minutesRemaining: hasLimit ? max(0, limit - used) : 0,
    );
  }

  bool get isLocked =>
      isExamMode || isBedtimeBlocked || isManuallyBlocked || (hasLimit && minutesRemaining <= 0);
}

final timeStatusProvider = NotifierProvider.family<TimeStatusNotifier, AsyncValue<TimeStatus>, int>(
  (profileId) => TimeStatusNotifier(profileId),
);

class TimeStatusNotifier extends Notifier<AsyncValue<TimeStatus>> {
  final int profileId;

  TimeStatusNotifier(this.profileId);

  @override
  AsyncValue<TimeStatus> build() {
    loadFromHive();
    return const AsyncValue.loading();
  }

  void loadFromHive() {
    try {
      final box = Hive.box('time_rules');
      final statusData = box.get('status_$profileId');
      if (statusData != null) {
        state = AsyncValue.data(TimeStatus.fromMap(statusData));
      } else {
        state = AsyncValue.data(TimeStatus());
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void updateFromMap(Map<String, dynamic> data) {
    state = AsyncValue.data(TimeStatus.fromMap(data));
  }
}
