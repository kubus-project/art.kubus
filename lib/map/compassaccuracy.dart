import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:async';

GlobalKey<_CompassAccuracyWidgetState> compassKey = GlobalKey<_CompassAccuracyWidgetState>();

class CompassAccuracyWidget extends StatefulWidget {
  const CompassAccuracyWidget({super.key});

  @override
  _CompassAccuracyWidgetState createState() => _CompassAccuracyWidgetState();
}
CompassAccuracyWidget compassWidget = CompassAccuracyWidget(key: compassKey);

class _CompassAccuracyWidgetState extends State<CompassAccuracyWidget> {
  double _currentHeading = 0.0;
  StreamSubscription<CompassEvent>? _compassSubscription;

  @override
  void initState() {
    super.initState();
    _compassSubscription = FlutterCompass.events!.listen((CompassEvent event) {
      setState(() {
        _currentHeading = event.heading!;
      });
    });
  }

  double getCompassAccuracy() {
    if (_currentHeading >= 0.0 && _currentHeading <= 360.0) {
      return 1.0; // High accuracy
    } else {
      return 0.0; // Low accuracy
    }
  }

  @override
  Widget build(BuildContext context) {
    double accuracy = getCompassAccuracy();

    return Container(
      child: Text('Compass Accuracy: $accuracy'),
    );
  }
}