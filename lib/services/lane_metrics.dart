/// Static distance/cost table for the three-hub network (Berlin, Munich,
/// Hamburg). Shared by the operations transfer-tracker UI and the
/// relocation-suggestion engine so both quote the same lane numbers.
class LaneMetrics {
  final String distance;
  final String leadTimeLabel;
  final int leadTimeDays;
  final String carrier;
  final String route;
  final double costPerUnit;

  const LaneMetrics({
    required this.distance,
    required this.leadTimeLabel,
    required this.leadTimeDays,
    required this.carrier,
    required this.route,
    required this.costPerUnit,
  });
}

class LaneMetricsService {
  static const Map<String, LaneMetrics> _lanes = {
    'Berlin_Hamburg': LaneMetrics(
      distance: '289 km',
      leadTimeLabel: '4.5 Hours',
      leadTimeDays: 1,
      carrier: 'DHL Freight Express',
      route: 'Autobahn A24',
      costPerUnit: 1.20,
    ),
    'Berlin_Munich': LaneMetrics(
      distance: '585 km',
      leadTimeLabel: '8.2 Hours',
      leadTimeDays: 1,
      carrier: 'DB Schenker Logistics',
      route: 'Autobahn A9',
      costPerUnit: 1.50,
    ),
    'Hamburg_Munich': LaneMetrics(
      distance: '792 km',
      leadTimeLabel: '11.4 Hours',
      leadTimeDays: 2,
      carrier: 'Amazon Surface Freight',
      route: 'Autobahn A7',
      costPerUnit: 1.80,
    ),
  };

  static const LaneMetrics _fallback = LaneMetrics(
    distance: '450 km',
    leadTimeLabel: '6.0 Hours',
    leadTimeDays: 1,
    carrier: 'Inter-Hub Regional Courier',
    route: 'Federal Highway',
    costPerUnit: 1.50,
  );

  static LaneMetrics forRoute(String from, String to) {
    return _lanes['${from}_$to'] ?? _lanes['${to}_$from'] ?? _fallback;
  }
}
