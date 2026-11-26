class BillingAdminMetrics {
  final int activeSubscriptions;
  final int pastDueSubscriptions;
  final int paidPayments;
  final int failedPayments;
  final int pendingEvents;

  const BillingAdminMetrics({
    required this.activeSubscriptions,
    required this.pastDueSubscriptions,
    required this.paidPayments,
    required this.failedPayments,
    required this.pendingEvents,
  });

  factory BillingAdminMetrics.fromJson(Map<String, dynamic> json) {
    return BillingAdminMetrics(
      activeSubscriptions: _readInt(json['active_subscriptions']),
      pastDueSubscriptions: _readInt(json['past_due_subscriptions']),
      paidPayments: _readInt(json['paid_payments']),
      failedPayments: _readInt(json['failed_payments']),
      pendingEvents: _readInt(json['pending_events']),
    );
  }
}

class BillingAdminPage {
  final BillingAdminMetrics metrics;
  final List<Map<String, dynamic>> items;
  final int totalCount;

  const BillingAdminPage({
    required this.metrics,
    required this.items,
    required this.totalCount,
  });

  factory BillingAdminPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final rawMetrics = json['metrics'];

    return BillingAdminPage(
      metrics: BillingAdminMetrics.fromJson(
        rawMetrics is Map ? Map<String, dynamic>.from(rawMetrics) : const {},
      ),
      items: items,
      totalCount: _readInt(json['total_count']),
    );
  }
}

int _readInt(Object? value) => value is num ? value.toInt() : 0;
