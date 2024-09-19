import 'dart:math';
import 'package:flutter/material.dart';

class NFTCollectionPage extends StatefulWidget {
  const NFTCollectionPage({super.key});

  @override
  State<NFTCollectionPage> createState() => _NFTCollectionPageState();
}

class _NFTCollectionPageState extends State<NFTCollectionPage> {
  final Random random = Random();
  late final List<Map<String, String>> nftItems;
  final List<String> nftNames = [
    'TechArtsy Ape',
    'Digital Dragon',
    'Crypto Cat',
    'Blockchain Bird',
    'Virtual Viper',
    'Pixel Panther',
    'Meta Monkey',
    'Cyber Cheetah',
    'Quantum Quokka',
    'Holo Hawk'
  ];
  final List<String> authors = [
    'PixelDreamer', 'CodeMuse', 'DesignNinja', 'ScriptWizard', 'TechSage', 'DataDancer', 'CloudCrafter', 'BinaryBard', 'VirtualVoyager', 'CyberSculptor'
  ];
  final List<String> descriptions = [
    'A unique piece of digital art.',
    'A stunning representation of modern technology.',
    'A beautiful blend of colors and shapes.',
    'An abstract piece with deep meaning.',
    'A vibrant and dynamic artwork.',
    'A serene and calming piece.',
    'A bold and striking artwork.',
    'A whimsical and playful piece.',
    'A detailed and intricate artwork.',
    'A minimalist and elegant piece.'
  ];
  final List<Map<String, double>> coordinates = [
    {'latitude': 40.7128, 'longitude': -74.0060}, // New York, USA
    {'latitude': 51.5074, 'longitude': -0.1278},  // London, UK
    {'latitude': 48.8566, 'longitude': 2.3522},   // Paris, France
    {'latitude': 35.6895, 'longitude': 139.6917}, // Tokyo, Japan
    {'latitude': 52.5200, 'longitude': 13.4050},  // Berlin, Germany
    {'latitude': -33.8688, 'longitude': 151.2093},// Sydney, Australia
    {'latitude': 43.651070, 'longitude': -79.347015}, // Toronto, Canada
    {'latitude': 55.7558, 'longitude': 37.6173},  // Moscow, Russia
    {'latitude': 39.9042, 'longitude': 116.4074}, // Beijing, China
    {'latitude': 25.276987, 'longitude': 55.296249} // Dubai, UAE
  ];

  @override
  void initState() {
    super.initState();
    nftItems = List.generate(10, (index) {
      return {
        'imageUrl': 'https://picsum.photos/200/300?random=${random.nextInt(100)}',
        'name': nftNames[random.nextInt(nftNames.length)],
        'author': authors[random.nextInt(authors.length)],
        'description': descriptions[random.nextInt(descriptions.length)],
        'latitude': coordinates[random.nextInt(coordinates.length)]['latitude'].toString(),
        'longitude': coordinates[random.nextInt(coordinates.length)]['longitude'].toString()
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Your Collection'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount =
              constraints.maxWidth ~/ 200; // Adjust based on item width
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: nftItems.length,
            itemBuilder: (context, index) {
              return buildNFTItem(nftItems[index]);
            },
          );
        },
      ),
    );
  }

  Widget buildNFTItem(Map<String, String> nftItem) {
    return GestureDetector(
      onTap: () {
        _showNFTDetails(nftItem);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                nftItem['imageUrl']!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.error, color: Colors.red);
                },
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: Text(
                  nftItem['name']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'RobotoMono',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNFTDetails(Map<String, String> nftItem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nftItem['name']!,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Author: ${nftItem['author']}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Coordinates: ${nftItem['latitude']}, ${nftItem['longitude']}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      nftItem['description']!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        nftItem['imageUrl']!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 300,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.error, color: Colors.red);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _showSellDialog(nftItem);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Sell'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _showAuctionDialog(nftItem);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Auction'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSellDialog(Map<String, String> nftItem) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sell NFT'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Handle sell action
                Navigator.of(context).pop();
              },
              child: const Text('Sell'),
            ),
          ],
        );
      },
    );
  }
  void _showAuctionDialog(Map<String, String> nftItem) {
  double days = 0;
  double hours = 0;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: const Text('Auction NFT'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Starting Bid',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Buyout Price',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Days:'),
                    Expanded(
                      child: Slider(
                        value: days,
                        min: 0,
                        max: 30,
                        divisions: 30,
                        label: days.round().toString(),
                        onChanged: (double value) {
                          setState(() {
                            days = value;
                          });
                        },
                      ),
                    ),
                    Text(days.round().toString()),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Hours:'),
                    Expanded(
                      child: Slider(
                        value: hours,
                        min: 0,
                        max: 23,
                        divisions: 23,
                        label: hours.round().toString(),
                        onChanged: (double value) {
                          setState(() {
                            hours = value;
                          });
                        },
                      ),
                    ),
                    Text(hours.round().toString()),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Handle auction action
                  Navigator.of(context).pop();
                },
                child: const Text('Auction'),
              ),
            ],
          );
        },
      );
    },
  );
}}