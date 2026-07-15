import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/config.dart';
import '../features/map/navigation/walking_navigation_models.dart';
import 'http_client_factory.dart';

abstract class WalkingDirectionsApi {
  Future<WalkingRoute> route({
    required LatLng origin,
    required LatLng destination,
  });

  void dispose();
}

class WalkingDirectionsException implements Exception {
  const WalkingDirectionsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calculates pedestrian routes entirely in the client.
///
/// The service downloads a bounded OpenStreetMap walking graph from an
/// Overpass interpreter, then performs endpoint snapping, A* path finding and
/// maneuver generation locally in Dart. The user's coordinates are never sent
/// to art.kubus and no remote directions engine is involved.
class WalkingDirectionsService implements WalkingDirectionsApi {
  WalkingDirectionsService({
    http.Client? client,
    String? endpoint,
    Duration timeout = const Duration(seconds: 20),
    Duration minimumRequestInterval = const Duration(seconds: 1),
    double maximumRouteDistanceMeters = 8000,
    double graphMarginMeters = 450,
    double maximumSnapDistanceMeters = 180,
    double snapCandidateSlackMeters = 35,
    int maximumResponseBytes = 8 * 1024 * 1024,
    int maximumElements = 160000,
  })  : _client = client ?? createPlatformHttpClient(),
        _ownsClient = client == null,
        _endpoint = _validatedEndpoint(
          endpoint ?? AppConfig.walkingGraphEndpoint,
        ),
        _timeout = timeout,
        _minimumRequestInterval = minimumRequestInterval,
        _maximumRouteDistanceMeters = maximumRouteDistanceMeters,
        _graphMarginMeters = graphMarginMeters,
        _maximumSnapDistanceMeters = maximumSnapDistanceMeters,
        _snapCandidateSlackMeters = snapCandidateSlackMeters,
        _maximumResponseBytes = maximumResponseBytes,
        _maximumElements = maximumElements;

  static const double _walkingSpeedMetersPerSecond = 1.35;
  static const int _maximumSnapCandidates = 8;

  final http.Client _client;
  final bool _ownsClient;
  final Uri _endpoint;
  final Duration _timeout;
  final Duration _minimumRequestInterval;
  final double _maximumRouteDistanceMeters;
  final double _graphMarginMeters;
  final double _maximumSnapDistanceMeters;
  final double _snapCandidateSlackMeters;
  final int _maximumResponseBytes;
  final int _maximumElements;
  final Distance _distance = const Distance();

  DateTime? _lastRequestAt;
  _WalkingGraphRecord? _cachedGraph;

  @override
  Future<WalkingRoute> route({
    required LatLng origin,
    required LatLng destination,
  }) async {
    _validateCoordinate(origin);
    _validateCoordinate(destination);
    final directDistance = _meters(origin, destination);
    if (directDistance > _maximumRouteDistanceMeters) {
      throw const WalkingDirectionsException(
        'This walking route is too long for on-device navigation.',
      );
    }
    if (directDistance < 1) {
      return WalkingRoute(
        points: List<LatLng>.unmodifiable(<LatLng>[origin, destination]),
        steps: List<WalkingRouteStep>.unmodifiable(<WalkingRouteStep>[
          WalkingRouteStep(
            type: 'arrive',
            modifier: 'straight',
            roadName: '',
            location: destination,
            distanceMeters: 0,
            durationSeconds: 0,
            geometryIndex: 1,
          ),
        ]),
        distanceMeters: directDistance,
        durationSeconds: directDistance / _walkingSpeedMetersPerSecond,
      );
    }

    var graph = _cachedGraph;
    if (graph == null ||
        !graph.bounds.contains(origin) ||
        !graph.bounds.contains(destination)) {
      final bounds = _GraphBoundsRecord.around(
        origin,
        destination,
        marginMeters: _graphMarginMeters,
      );
      graph = await _loadGraph(bounds);
      _cachedGraph = graph;
    }

    final path = _findPath(graph, origin, destination);
    return _buildRoute(path, origin, destination);
  }

  Future<_WalkingGraphRecord> _loadGraph(_GraphBoundsRecord bounds) async {
    final lastRequestAt = _lastRequestAt;
    if (lastRequestAt != null) {
      final remaining =
          _minimumRequestInterval - DateTime.now().difference(lastRequestAt);
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    }
    _lastRequestAt = DateTime.now();

    final query = _overpassQuery(bounds);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
      if (!kIsWeb) 'User-Agent': 'art.kubus/1.0 (https://kubus.site)',
    };

    late final http.Response response;
    try {
      response = await _client.post(
        _endpoint,
        headers: headers,
        body: <String, String>{'data': query},
      ).timeout(_timeout);
    } on TimeoutException {
      throw const WalkingDirectionsException(
        'The walking map request timed out.',
      );
    } on http.ClientException {
      throw const WalkingDirectionsException(
        'The walking map could not be downloaded.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WalkingDirectionsException(
        'The walking map request failed (${response.statusCode}).',
      );
    }
    if (response.bodyBytes.length > _maximumResponseBytes) {
      throw const WalkingDirectionsException(
        'The downloaded walking map is too large.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const WalkingDirectionsException(
        'The walking map response was invalid.',
      );
    }
    if (decoded is! Map) {
      throw const WalkingDirectionsException(
        'The walking map response was invalid.',
      );
    }
    final elements = decoded['elements'];
    if (elements is! List || elements.length > _maximumElements) {
      throw const WalkingDirectionsException(
        'The walking map response was invalid or too large.',
      );
    }

    final nodes = <int, LatLng>{};
    final rawWays = <Map<Object?, Object?>>[];
    for (final element in elements) {
      if (element is! Map) continue;
      final type = element['type'];
      if (type == 'node') {
        final id = _integer(element['id']);
        final latitude = _number(element['lat']);
        final longitude = _number(element['lon']);
        if (id == null || latitude == null || longitude == null) continue;
        final point = LatLng(latitude, longitude);
        try {
          _validateCoordinate(point);
        } on WalkingDirectionsException {
          continue;
        }
        nodes[id] = point;
      } else if (type == 'way') {
        rawWays.add(Map<Object?, Object?>.from(element));
      }
    }

    final adjacency = <int, List<_WalkingEdgeRecord>>{};
    for (final way in rawWays) {
      final tags = _stringMap(way['tags']);
      if (!_isWalkable(tags)) continue;
      final nodeIds = (way['nodes'] as List?)
          ?.map(_integer)
          .whereType<int>()
          .toList(growable: false);
      if (nodeIds == null || nodeIds.length < 2) continue;
      final roadName = (tags['name'] ?? tags['ref'] ?? '').trim();
      final footDirection = _footDirection(tags);
      final speed =
          tags['highway'] == 'steps' ? 0.8 : _walkingSpeedMetersPerSecond;
      for (var index = 0; index + 1 < nodeIds.length; index += 1) {
        final from = nodeIds[index];
        final to = nodeIds[index + 1];
        final fromPoint = nodes[from];
        final toPoint = nodes[to];
        if (fromPoint == null || toPoint == null) continue;
        final meters = _meters(fromPoint, toPoint);
        if (!meters.isFinite || meters <= 0 || meters > 2000) continue;
        if (footDirection != _FootDirection.reverseOnly) {
          (adjacency[from] ??= <_WalkingEdgeRecord>[]).add(
            _WalkingEdgeRecord(
              from: from,
              to: to,
              distanceMeters: meters,
              durationSeconds: meters / speed,
              roadName: roadName,
            ),
          );
        }
        if (footDirection != _FootDirection.forwardOnly) {
          (adjacency[to] ??= <_WalkingEdgeRecord>[]).add(
            _WalkingEdgeRecord(
              from: to,
              to: from,
              distanceMeters: meters,
              durationSeconds: meters / speed,
              roadName: roadName,
            ),
          );
        }
      }
    }

    final activeNodeIds = <int>{
      ...adjacency.keys,
      for (final edges in adjacency.values)
        for (final edge in edges) edge.to,
    };
    nodes.removeWhere((id, _) => !activeNodeIds.contains(id));
    if (nodes.isEmpty || adjacency.isEmpty) {
      throw const WalkingDirectionsException(
        'No walkable streets were found near this route.',
      );
    }
    return _WalkingGraphRecord(
      bounds: bounds,
      nodes: Map<int, LatLng>.unmodifiable(nodes),
      adjacency: Map<int, List<_WalkingEdgeRecord>>.unmodifiable(
        adjacency.map(
          (id, edges) => MapEntry(
            id,
            List<_WalkingEdgeRecord>.unmodifiable(edges),
          ),
        ),
      ),
    );
  }

  String _overpassQuery(_GraphBoundsRecord bounds) {
    final bbox = '${bounds.south.toStringAsFixed(7)},'
        '${bounds.west.toStringAsFixed(7)},'
        '${bounds.north.toStringAsFixed(7)},'
        '${bounds.east.toStringAsFixed(7)}';
    return '[out:json][timeout:15][maxsize:$_maximumResponseBytes];'
        'way["highway"]["area"!="yes"]($bbox);'
        'out body;>;out skel qt;';
  }

  _WalkingPathRecord _findPath(
    _WalkingGraphRecord graph,
    LatLng origin,
    LatLng destination,
  ) {
    final starts = _nearestCandidates(graph.nodes, origin);
    final destinations = _nearestCandidates(graph.nodes, destination);
    if (starts.isEmpty || destinations.isEmpty) {
      throw const WalkingDirectionsException(
        'No walkable street is close enough to this route.',
      );
    }

    final destinationConnectors = <int, double>{
      for (final candidate in destinations)
        candidate.nodeId: candidate.distanceMeters,
    };
    final queue = _MinQueue();
    final costs = <int, double>{};
    final durations = <int, double>{};
    final previous = <int, _WalkingEdgeRecord>{};
    for (final start in starts) {
      final existing = costs[start.nodeId];
      if (existing != null && existing <= start.distanceMeters) continue;
      costs[start.nodeId] = start.distanceMeters;
      durations[start.nodeId] =
          start.distanceMeters / _walkingSpeedMetersPerSecond;
      queue.add(
        _QueueEntryRecord(
          nodeId: start.nodeId,
          pathCost: start.distanceMeters,
          priority: start.distanceMeters +
              _meters(graph.nodes[start.nodeId]!, destination),
        ),
      );
    }

    int? bestDestinationNode;
    var bestTotalCost = double.infinity;
    var expanded = 0;
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final knownCost = costs[current.nodeId];
      if (knownCost == null || current.pathCost > knownCost + 0.001) continue;
      if (current.priority >= bestTotalCost) break;
      expanded += 1;
      if (expanded > graph.nodes.length * 2) break;

      final destinationConnector = destinationConnectors[current.nodeId];
      if (destinationConnector != null) {
        final total = knownCost + destinationConnector;
        if (total < bestTotalCost) {
          bestTotalCost = total;
          bestDestinationNode = current.nodeId;
        }
      }

      for (final edge in graph.adjacency[current.nodeId] ?? const []) {
        final nextCost = knownCost + edge.distanceMeters;
        if (nextCost >= (costs[edge.to] ?? double.infinity)) continue;
        costs[edge.to] = nextCost;
        durations[edge.to] =
            (durations[current.nodeId] ?? 0) + edge.durationSeconds;
        previous[edge.to] = edge;
        queue.add(
          _QueueEntryRecord(
            nodeId: edge.to,
            pathCost: nextCost,
            priority: nextCost + _meters(graph.nodes[edge.to]!, destination),
          ),
        );
      }
    }

    final endNode = bestDestinationNode;
    if (endNode == null) {
      throw const WalkingDirectionsException(
        'No connected walking route was found.',
      );
    }

    final reversedEdges = <_WalkingEdgeRecord>[];
    var cursor = endNode;
    while (true) {
      final edge = previous[cursor];
      if (edge == null) break;
      reversedEdges.add(edge);
      cursor = edge.from;
    }
    final edges = reversedEdges.reversed.toList(growable: false);
    final startNode = edges.isEmpty ? endNode : edges.first.from;
    final originConnector = _meters(origin, graph.nodes[startNode]!);
    final destinationConnector = _meters(graph.nodes[endNode]!, destination);
    return _WalkingPathRecord(
      graph: graph,
      startNode: startNode,
      endNode: endNode,
      edges: edges,
      originConnectorMeters: originConnector,
      destinationConnectorMeters: destinationConnector,
      durationSeconds: (durations[endNode] ?? 0) +
          destinationConnector / _walkingSpeedMetersPerSecond,
    );
  }

  List<_SnapCandidateRecord> _nearestCandidates(
    Map<int, LatLng> nodes,
    LatLng target,
  ) {
    final candidates = <_SnapCandidateRecord>[];
    for (final entry in nodes.entries) {
      final meters = _meters(target, entry.value);
      if (meters > _maximumSnapDistanceMeters) continue;
      final candidate = _SnapCandidateRecord(
        nodeId: entry.key,
        distanceMeters: meters,
      );
      final insertionIndex = candidates.indexWhere(
        (current) => current.distanceMeters > meters,
      );
      if (insertionIndex < 0) {
        candidates.add(candidate);
      } else {
        candidates.insert(insertionIndex, candidate);
      }
      if (candidates.length > _maximumSnapCandidates) {
        candidates.removeLast();
      }
    }
    if (candidates.isEmpty) return candidates;
    final furthestUsefulDistance = math.min(
      _maximumSnapDistanceMeters,
      candidates.first.distanceMeters + _snapCandidateSlackMeters,
    );
    return candidates
        .where(
          (candidate) => candidate.distanceMeters <= furthestUsefulDistance,
        )
        .toList(growable: false);
  }

  WalkingRoute _buildRoute(
    _WalkingPathRecord path,
    LatLng origin,
    LatLng destination,
  ) {
    final points = <LatLng>[origin];
    final segmentNames = <String>[];
    final segmentDurations = <double>[];

    void appendPoint(LatLng point, String roadName, double durationSeconds) {
      if (_meters(points.last, point) < 0.2) return;
      points.add(point);
      segmentNames.add(roadName);
      segmentDurations.add(durationSeconds);
    }

    final startPoint = path.graph.nodes[path.startNode]!;
    appendPoint(
      startPoint,
      '',
      path.originConnectorMeters / _walkingSpeedMetersPerSecond,
    );
    final graphStartIndex = points.length - 1;
    for (final edge in path.edges) {
      appendPoint(
        path.graph.nodes[edge.to]!,
        edge.roadName,
        edge.durationSeconds,
      );
    }
    final graphEndIndex = points.length - 1;
    appendPoint(
      destination,
      '',
      path.destinationConnectorMeters / _walkingSpeedMetersPerSecond,
    );

    if (points.length < 2) {
      throw const WalkingDirectionsException(
        'No usable walking route geometry was found.',
      );
    }
    final distanceMeters = _polylineDistance(points);
    final steps = _buildManeuvers(points, segmentNames, segmentDurations);
    return WalkingRoute(
      points: List<LatLng>.unmodifiable(points),
      steps: List<WalkingRouteStep>.unmodifiable(steps),
      distanceMeters: distanceMeters,
      durationSeconds: path.durationSeconds,
      graphStartIndex: graphStartIndex,
      graphEndIndex: graphEndIndex,
    );
  }

  List<WalkingRouteStep> _buildManeuvers(
    List<LatLng> points,
    List<String> segmentNames,
    List<double> segmentDurations,
  ) {
    final maneuverIndices = <int>[0];
    for (var vertex = 1; vertex + 1 < points.length; vertex += 1) {
      final turn = _turnAngle(
        _bearing(points[vertex - 1], points[vertex]),
        _bearing(points[vertex], points[vertex + 1]),
      );
      final previousName = segmentNames[vertex - 1];
      final nextName = segmentNames[vertex];
      final changesNamedRoad = previousName.isNotEmpty &&
          nextName.isNotEmpty &&
          previousName != nextName;
      if (turn.abs() >= 25 || changesNamedRoad) maneuverIndices.add(vertex);
    }
    if (maneuverIndices.last != points.length - 1) {
      maneuverIndices.add(points.length - 1);
    }

    final steps = <WalkingRouteStep>[];
    for (var index = 0; index < maneuverIndices.length; index += 1) {
      final geometryIndex = maneuverIndices[index];
      final isFirst = index == 0;
      final isLast = index == maneuverIndices.length - 1;
      final nextGeometryIndex =
          isLast ? geometryIndex : maneuverIndices[index + 1];
      var distanceMeters = 0.0;
      var durationSeconds = 0.0;
      for (var segment = geometryIndex;
          segment < nextGeometryIndex;
          segment += 1) {
        distanceMeters += _meters(points[segment], points[segment + 1]);
        durationSeconds += segmentDurations[segment];
      }
      final modifier = isFirst || isLast
          ? 'straight'
          : _turnModifier(
              _turnAngle(
                _bearing(points[geometryIndex - 1], points[geometryIndex]),
                _bearing(points[geometryIndex], points[geometryIndex + 1]),
              ),
            );
      final roadName = geometryIndex < segmentNames.length
          ? segmentNames[geometryIndex]
          : '';
      steps.add(
        WalkingRouteStep(
          type: isFirst
              ? 'depart'
              : isLast
                  ? 'arrive'
                  : 'turn',
          modifier: modifier,
          roadName: roadName,
          location: points[geometryIndex],
          distanceMeters: distanceMeters,
          durationSeconds: durationSeconds,
          geometryIndex: geometryIndex,
        ),
      );
    }
    return steps;
  }

  bool _isWalkable(Map<String, String> tags) {
    final highway = (tags['highway'] ?? '').toLowerCase();
    if (highway.isEmpty ||
        const <String>{
          'motorway',
          'motorway_link',
          'trunk',
          'trunk_link',
          'raceway',
          'construction',
          'proposed',
          'abandoned',
          'razed',
        }.contains(highway)) {
      return false;
    }
    if ((tags['area'] ?? '').toLowerCase() == 'yes') return false;
    final foot = (tags['foot'] ?? '').toLowerCase();
    if (const <String>{'no', 'private', 'use_sidepath'}.contains(foot)) {
      return false;
    }
    final access = (tags['access'] ?? '').toLowerCase();
    final explicitlyWalkable =
        const <String>{'yes', 'designated', 'permissive'}.contains(foot);
    if (!explicitlyWalkable &&
        const <String>{'no', 'private'}.contains(access)) {
      return false;
    }
    return true;
  }

  _FootDirection _footDirection(Map<String, String> tags) {
    final value = (tags['oneway:foot'] ?? '').toLowerCase();
    if (const <String>{'yes', 'true', '1'}.contains(value)) {
      return _FootDirection.forwardOnly;
    }
    if (value == '-1' || value == 'reverse') {
      return _FootDirection.reverseOnly;
    }
    return _FootDirection.both;
  }

  String _turnModifier(double angle) {
    final magnitude = angle.abs();
    if (magnitude < 25) return 'straight';
    final side = angle > 0 ? 'right' : 'left';
    if (magnitude < 55) return 'slight $side';
    if (magnitude < 135) return side;
    if (magnitude < 170) return 'sharp $side';
    return 'uturn';
  }

  double _turnAngle(double incoming, double outgoing) {
    var delta = outgoing - incoming;
    while (delta > 180) {
      delta -= 360;
    }
    while (delta < -180) {
      delta += 360;
    }
    return delta;
  }

  double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final deltaLongitude = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(deltaLongitude) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLongitude);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _polylineDistance(List<LatLng> points) {
    var total = 0.0;
    for (var index = 0; index + 1 < points.length; index += 1) {
      total += _meters(points[index], points[index + 1]);
    }
    return total;
  }

  double _meters(LatLng from, LatLng to) =>
      _distance.as(LengthUnit.Meter, from, to);

  static Uri _validatedEndpoint(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(raw, 'endpoint', 'Must be an HTTPS URL.');
    }
    return uri;
  }

  static int? _integer(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    return null;
  }

  static double? _number(Object? value) {
    if (value is! num) return null;
    final number = value.toDouble();
    return number.isFinite ? number : null;
  }

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return const <String, String>{};
    return <String, String>{
      for (final entry in value.entries)
        if (entry.key != null && entry.value != null)
          entry.key.toString(): entry.value.toString(),
    };
  }

  static void _validateCoordinate(LatLng point) {
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude < -90 ||
        point.latitude > 90 ||
        point.longitude < -180 ||
        point.longitude > 180) {
      throw const WalkingDirectionsException('Invalid route coordinate.');
    }
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
  }
}

enum _FootDirection { both, forwardOnly, reverseOnly }

class _GraphBoundsRecord {
  const _GraphBoundsRecord({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  factory _GraphBoundsRecord.around(
    LatLng origin,
    LatLng destination, {
    required double marginMeters,
  }) {
    final middleLatitude = (origin.latitude + destination.latitude) / 2;
    final latitudeMargin = marginMeters / 111320;
    final longitudeScale =
        math.cos(middleLatitude * math.pi / 180).abs().clamp(0.1, 1.0);
    final longitudeMargin = marginMeters / (111320 * longitudeScale);
    return _GraphBoundsRecord(
      south: (math.min(origin.latitude, destination.latitude) - latitudeMargin)
          .clamp(-90.0, 90.0),
      west:
          (math.min(origin.longitude, destination.longitude) - longitudeMargin)
              .clamp(-180.0, 180.0),
      north: (math.max(origin.latitude, destination.latitude) + latitudeMargin)
          .clamp(-90.0, 90.0),
      east:
          (math.max(origin.longitude, destination.longitude) + longitudeMargin)
              .clamp(-180.0, 180.0),
    );
  }

  final double south;
  final double west;
  final double north;
  final double east;

  bool contains(LatLng point) =>
      point.latitude >= south &&
      point.latitude <= north &&
      point.longitude >= west &&
      point.longitude <= east;
}

class _WalkingGraphRecord {
  const _WalkingGraphRecord({
    required this.bounds,
    required this.nodes,
    required this.adjacency,
  });

  final _GraphBoundsRecord bounds;
  final Map<int, LatLng> nodes;
  final Map<int, List<_WalkingEdgeRecord>> adjacency;
}

class _WalkingEdgeRecord {
  const _WalkingEdgeRecord({
    required this.from,
    required this.to,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.roadName,
  });

  final int from;
  final int to;
  final double distanceMeters;
  final double durationSeconds;
  final String roadName;
}

class _SnapCandidateRecord {
  const _SnapCandidateRecord({
    required this.nodeId,
    required this.distanceMeters,
  });

  final int nodeId;
  final double distanceMeters;
}

class _WalkingPathRecord {
  const _WalkingPathRecord({
    required this.graph,
    required this.startNode,
    required this.endNode,
    required this.edges,
    required this.originConnectorMeters,
    required this.destinationConnectorMeters,
    required this.durationSeconds,
  });

  final _WalkingGraphRecord graph;
  final int startNode;
  final int endNode;
  final List<_WalkingEdgeRecord> edges;
  final double originConnectorMeters;
  final double destinationConnectorMeters;
  final double durationSeconds;
}

class _QueueEntryRecord {
  const _QueueEntryRecord({
    required this.nodeId,
    required this.pathCost,
    required this.priority,
  });

  final int nodeId;
  final double pathCost;
  final double priority;
}

class _MinQueue {
  final List<_QueueEntryRecord> _entries = <_QueueEntryRecord>[];

  bool get isNotEmpty => _entries.isNotEmpty;

  void add(_QueueEntryRecord value) {
    _entries.add(value);
    var index = _entries.length - 1;
    while (index > 0) {
      final parent = (index - 1) ~/ 2;
      if (_entries[parent].priority <= value.priority) break;
      _entries[index] = _entries[parent];
      index = parent;
    }
    _entries[index] = value;
  }

  _QueueEntryRecord removeFirst() {
    final first = _entries.first;
    final last = _entries.removeLast();
    if (_entries.isEmpty) return first;
    var index = 0;
    while (true) {
      final left = index * 2 + 1;
      if (left >= _entries.length) break;
      final right = left + 1;
      var child = left;
      if (right < _entries.length &&
          _entries[right].priority < _entries[left].priority) {
        child = right;
      }
      if (_entries[child].priority >= last.priority) break;
      _entries[index] = _entries[child];
      index = child;
    }
    _entries[index] = last;
    return first;
  }
}
