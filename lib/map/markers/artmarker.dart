import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class ArtMarker extends StatefulWidget {
  final LatLng position;
  final String title;
  final String description;

  const ArtMarker({
    super.key,
    required this.position,
    required this.title,
    required this.description,
  });

  @override
  State<ArtMarker> createState() => _ArtMarkerState();
}

class _ArtMarkerState extends State<ArtMarker> {
  bool _isMarkerTapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isMarkerTapped = true;
        });
        _showMarkerInfoDialog(context);
      },
      child: Icon(
        Icons.square_outlined,
        color: _isMarkerTapped ? Theme.of(context).iconTheme.color : Theme.of(context).iconTheme.color?.withOpacity(0.54),
        size: 9,
      ),
    );
  }

  void _showMarkerInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.title),
        content: Text(widget.description),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isMarkerTapped = false;
              });
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}