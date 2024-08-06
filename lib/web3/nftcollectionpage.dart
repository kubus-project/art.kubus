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

  @override
  void initState() {
    super.initState();
    nftItems = List.generate(10, (index) {
      return {
        'imageUrl': 'https://picsum.photos/200/300?random=${random.nextInt(100)}',
        'name': nftNames[random.nextInt(nftNames.length)]
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
        // Handle onTap
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
}