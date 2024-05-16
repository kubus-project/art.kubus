import 'package:flutter/material.dart';

class NFTCollectionPage extends StatefulWidget {

  const NFTCollectionPage({super.key,});

  @override
  State<NFTCollectionPage> createState() => _NFTCollectionPageState();
}

class _NFTCollectionPageState extends State<NFTCollectionPage> {
  final List<String> nftItems = [
    'NFT Image 1',
    'NFT Image 2',
    // Add more NFT image URLs here
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Your Collection', style: TextStyle(fontFamily: 'Sofia Sans', color: Colors.white),), 
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

  Widget buildNFTItem(String imageUrl) {
    return GestureDetector(
      onTap: () {
        // Handle onTap
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(imageUrl), // Replace with Image.network for images
        ),
      ),
    );
  }
}
