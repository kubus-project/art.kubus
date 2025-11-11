import 'package:flutter/material.dart';
import 'dart:math';

final random = Random();

class ArtVoteWidget extends StatefulWidget {
  final List<ArtPiece> artPieces;
  final ArtDAO artDAO;

  const ArtVoteWidget({super.key, required this.artPieces, required this.artDAO});

  @override
  ArtVoteWidgetState createState() => ArtVoteWidgetState();
}

class ArtVoteWidgetState extends State<ArtVoteWidget> {
  int _currentIndex = 0;

  void _addVote(bool isUpvote) {
    setState(() {
      widget.artDAO.addVote(
        widget.artPieces[_currentIndex].id,
        Vote(userId: 'user1', isUpvote: isUpvote),
      );
      _currentIndex = (_currentIndex + 1) % widget.artPieces.length;
    });
  }

  void _addReview(String comment, int rating) {
    setState(() {
      widget.artDAO.addReview(
        widget.artPieces[_currentIndex].id,
        Review(userId: 'user1', comment: comment, rating: rating),
      );
    });
  }

  void _onSwipeRight() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + widget.artPieces.length) % widget.artPieces.length;
    });
  }

  double _calculateAverageRating(List<Review> reviews) {
    if (reviews.isEmpty) return 0.0;
    return reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final artPiece = widget.artPieces[_currentIndex];
    final averageRating = _calculateAverageRating(artPiece.reviews);
    final coordinates = '${(random.nextDouble() * 180 - 90).toStringAsFixed(4)}, ${(random.nextDouble() * 360 - 180).toStringAsFixed(4)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Art Vote'),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            _onSwipeRight();
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: () => _showFullScreenImage(artPiece.imageUrl),
                    child: Image.network(
                      artPiece.imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
                      child: Text(
                        artPiece.title,
                        style: Theme.of(context).textTheme.headlineLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: MediaQuery.of(context).size.width / 4 - 40,
                    child: Container(
                      width: 80,
                      height: 80,                      
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.thumb_up, size: 40, color: Colors.black),
                        onPressed: () => _addVote(true),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: MediaQuery.of(context).size.width / 4 - 40,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.thumb_down, size: 40, color: Theme.of(context).colorScheme.onPrimary),
                        onPressed: () => _addVote(false),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  artPiece.artist,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(artPiece.description, style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  coordinates,
      
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Votes: ${artPiece.votes.length}', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _showReviewsDialog(context, artPiece.reviews),
                    child: Text(
                      'Average Rating: ${averageRating.toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReviewDialog(BuildContext context) {
    final commentController = TextEditingController();
    int rating = 5;

    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Add Review'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: commentController,
                        decoration: const InputDecoration(
                          labelText: 'Comment',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Rating'),
                      Slider(
                        value: rating.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: rating.toString(),
                        onChanged: (double value) {
                          setState(() {
                            rating = value.toInt();
                          });
                        },
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
                    TextButton(
                      onPressed: () {
                        _addReview(commentController.text, rating);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Submit'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showReviewsDialog(BuildContext context, List<Review> reviews) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reviews'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return ListTile(
                      title: Text(review.comment),
                      subtitle: Text('Rating: ${review.rating}'),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showReviewDialog(context);
              },
              child: const Text('Add Review'),
            ),
          ],
        );
      },
    );
  }
}

class ArtPiece {
  final String id;
  final String title;
  final String artist;
  final String description;
  final String imageUrl;
  final List<Vote> votes;
  final List<Review> reviews;

  ArtPiece({
    required this.id,
    required this.title,
    required this.artist,
    required this.description,
    required this.imageUrl,
    this.votes = const [],
    this.reviews = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'description': description,
      'imageUrl': imageUrl,
      'votes': votes.map((vote) => vote.toMap()).toList(),
      'reviews': reviews.map((review) => review.toMap()).toList(),
    };
  }

  factory ArtPiece.fromMap(Map<String, dynamic> map) {
    return ArtPiece(
      id: map['id'],
      title: map['title'],
      artist: map['artist'],
      description: map['description'],
      imageUrl: map['imageUrl'],
      votes: List<Vote>.from(map['votes']?.map((x) => Vote.fromMap(x)) ?? []),
      reviews: List<Review>.from(map['reviews']?.map((x) => Review.fromMap(x)) ?? []),
    );
  }
}

class Vote {
  final String userId;
  final bool isUpvote;

  Vote({
    required this.userId,
    required this.isUpvote,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'isUpvote': isUpvote,
    };
  }

  factory Vote.fromMap(Map<String, dynamic> map) {
    return Vote(
      userId: map['userId'],
      isUpvote: map['isUpvote'],
    );
  }
}

class Review {
  final String userId;
  final String comment;
  final int rating;

  Review({
    required this.userId,
    required this.comment,
    required this.rating,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'comment': comment,
      'rating': rating,
    };
  }

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      userId: map['userId'],
      comment: map['comment'],
      rating: map['rating'],
    );
  }
}

class ArtDAO {
  final List<ArtPiece> _artPieces = [];

  final List<String> _randomImageUrls = List.generate(
    100,
    (index) => 'https://picsum.photos/200/300?random=$index',
  );

  final List<String> _mockTitles = [
    'Sunset Overdrive',
    'Mystic Mountains',
    'Urban Jungle',
    'Serenity',
    'Abstract Thoughts',
    'Nature\'s Palette',
    'Cosmic Dreams',
    'Silent Night',
    'Golden Hour',
    'Ethereal Beauty'
  ];

  final List<String> _mockArtists = [
    'PixelDreamer', 'CodeMuse', 'DesignNinja', 'ScriptWizard', 'TechSage', 'DataDancer', 'CloudCrafter', 'BinaryBard', 'VirtualVoyager', 'CyberSculptor'
  ];

  final List<String> _mockDescriptions = [
    'A beautiful depiction of a sunset over the city.',
    'Majestic mountains covered in mist.',
    'The hustle and bustle of city life captured in a frame.',
    'A peaceful and serene landscape.',
    'An abstract representation of complex thoughts.',
    'A vibrant display of nature\'s colors.',
    'A glimpse into the vastness of the cosmos.',
    'A quiet and calm night scene.',
    'The golden hues of the setting sun.',
    'A stunning portrayal of ethereal beauty.'
  ];

  void addArtPiece(ArtPiece artPiece) {
    _artPieces.add(artPiece);
  }

  ArtPiece? getArtPieceById(String id) {
    try {
      return _artPieces.firstWhere((artPiece) => artPiece.id == id);
    } catch (e) {
      return null;
    }
  }

  bool updateArtPiece(ArtPiece updatedArtPiece) {
    for (int i = 0; i < _artPieces.length; i++) {
      if (_artPieces[i].id == updatedArtPiece.id) {
        _artPieces[i] = updatedArtPiece;
        return true;
      }
    }
    return false;
  }

  bool deleteArtPiece(String id) {
    int initialLength = _artPieces.length;
    _artPieces.removeWhere((artPiece) => artPiece.id == id);
    return _artPieces.length < initialLength;
  }

  List<ArtPiece> listAllArtPieces() {
    return List.unmodifiable(_artPieces);
  }

  bool addVote(String artPieceId, Vote vote) {
    ArtPiece? artPiece = getArtPieceById(artPieceId);
    if (artPiece != null) {
      artPiece.votes.add(vote);
      return true;
    }
    return false;
  }

  bool addReview(String artPieceId, Review review) {
    ArtPiece? artPiece = getArtPieceById(artPieceId);
    if (artPiece != null) {
      artPiece.reviews.add(review);
      return true;
    }
    return false;
  }

  void populateArtPiecesWithRandomImages(int count) {
    for (int i = 0; i < count; i++) {
      final artPiece = ArtPiece(
        id: 'art${i + 1}',
        title: _mockTitles[i % _mockTitles.length],
        artist: _mockArtists[i % _mockArtists.length],
        description: _mockDescriptions[i % _mockDescriptions.length],
        imageUrl: _randomImageUrls[i % _randomImageUrls.length],
      );
      addArtPiece(artPiece);
    }
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final artDAO = ArtDAO();
    artDAO.populateArtPiecesWithRandomImages(10);

    return MaterialApp(
      title: 'Art Vote',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ArtVoteWidget(
        artPieces: artDAO.listAllArtPieces(),
        artDAO: artDAO,
      ),
    );
  }
}
