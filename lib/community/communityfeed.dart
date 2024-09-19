import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:share/share.dart'; // Import the share package

class InfiniteScrollFeed extends StatefulWidget {
  const InfiniteScrollFeed({super.key});

  @override
  State<InfiniteScrollFeed> createState() => _InfiniteScrollFeedState();
}

class _InfiniteScrollFeedState extends State<InfiniteScrollFeed> {
  final ScrollController _scrollController = ScrollController();
  final List<Profile> _profiles = [];
  final List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMoreData = true; // Assuming there's always data initially

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('sl_SI', null);
    _fetchData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && !_isLoading && _hasMoreData) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (!_isLoading) {
      setState(() => _isLoading = true);

      try {
        await Future.delayed(const Duration(seconds: 2)); // Simulate network delay

        List<Profile> newProfiles = _generateRandomProfiles(10);
        List<Post> newPosts = _generateRandomPosts(10);

        if (newProfiles.isEmpty || newPosts.isEmpty) {
          _hasMoreData = false; // No more data to fetch
        }

        if (mounted) {
          setState(() {
            _profiles.addAll(newProfiles);
            _posts.addAll(newPosts);
          });
        }
      } catch (e) {
        // Handle errors, e.g., show a snackbar or log the error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to fetch data')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  List<Profile> _generateRandomProfiles(int count) {
    List<String> names = ['PixelDreamer', 'CodeMuse', 'DesignNinja', 'ScriptWizard', 'TechSage', 'DataDancer', 'CloudCrafter', 'BinaryBard', 'VirtualVoyager', 'CyberSculptor'];
    Random random = Random();

    return List<Profile>.generate(count, (index) => Profile(names[random.nextInt(names.length)]));
  }

  List<Post> _generateRandomPosts(int count) {
    List<String> loremIpsum = [
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
      "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
      "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
      "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
      "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
    ];
    Random random = Random();
    DateFormat dateFormat = DateFormat("dd. MM. yyyy", "sl_SI");
    DateFormat timeFormat = DateFormat("HH:mm");

    return List<Post>.generate(count, (index) {
      String content = loremIpsum[random.nextInt(loremIpsum.length)];
      DateTime now = DateTime.now();
      DateTime postDate = now.subtract(Duration(days: random.nextInt(30), hours: random.nextInt(24), minutes: random.nextInt(60)));
      String date = dateFormat.format(postDate);
      String time = timeFormat.format(postDate);
      // Generate random latitude and longitude
      double latitude = random.nextDouble() * 180 - 90; // Latitude ranges from -90 to 90
      double longitude = random.nextDouble() * 360 - 180; // Longitude ranges from -180 to 180
      String location = "Lat: ${latitude.toStringAsFixed(2)}, Long: ${longitude.toStringAsFixed(2)}";
      String artName = "Art Name ${random.nextInt(100)}";
      String pictureUrl = "https://picsum.photos/200/300?random=${random.nextInt(100)}";

      return Post(content, "$date\n$time", location, artName, pictureUrl);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Feed'),
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: _profiles.length + 1, // Add one for the loading indicator or 'no more data' message
        itemBuilder: (context, index) {
          if (index < _profiles.length) {
            return _buildPostCard(index);
          } else {
            return _isLoading ? const Center(child: CircularProgressIndicator()) : (!_hasMoreData ? const Center(child: Text('No more posts')) : const SizedBox.shrink());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPostScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPostCard(int index) {
    return Card(
      child: Column(
        children: [
          if (_posts[index].pictureUrl.isNotEmpty && _posts[index].pictureUrl != 'https://example.com/default-image.jpg') // Check if the post has a valid picture URL
            Image.network(_posts[index].pictureUrl, width: double.infinity, fit: BoxFit.cover), // Make the image full width
          ListTile(
            title: Text(_profiles[index].name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_posts[index].content),
                const SizedBox(height: 4), // Add some space between content and location
                Text(_posts[index].location, style: const TextStyle(fontWeight: FontWeight.bold)), // Display the location
              ],
            ),
            trailing: Text(_posts[index].timestamp),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              LikeButton(post: _posts[index]), // Pass color to LikeButton
              IconButton(icon: const Icon(Icons.comment), onPressed: () => onCommentPressed(context, index)),
              IconButton(icon: const Icon(Icons.share), onPressed: () => onSharePressed(context, index)),
            ],
          ),
        ],
      ),
    );
  }

  void onSharePressed(BuildContext context, int index) {
    final String content = "Check out this post: ${_posts[index].content}";
    Share.share(content); // Use the Share.share method to share content
  }
}

class Profile {
  final String name;

  Profile(this.name);
}

class Post {
  final String content;
  final String timestamp;
  final String location;
  final String artName;
  final String pictureUrl;
  bool isLiked = false;

  Post(this.content, this.timestamp, this.location, this.artName, String? pictureUrl)
      : pictureUrl = pictureUrl ?? 'https://example.com/default-image.jpg';
}

class LikeButton extends StatefulWidget {
  final Post post;

  const LikeButton({super.key, required this.post});

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  void _toggleLike() {
    setState(() {
      widget.post.isLiked = !widget.post.isLiked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(widget.post.isLiked ? Icons.favorite : Icons.favorite_border),
      onPressed: _toggleLike,
    );
  }
}

void onCommentPressed(BuildContext context, int index) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Comment on post $index')));
}

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _artNameController = TextEditingController();
  final TextEditingController _pictureUrlController = TextEditingController();

  @override
  void dispose() {
    _contentController.dispose();
    _locationController.dispose();
    _artNameController.dispose();
    _pictureUrlController.dispose();
    super.dispose();
  }

  void _addPost() {
    // Add logic to add the post
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Post'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: 'Content'),
            ),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            TextField(
              controller: _artNameController,
              decoration: const InputDecoration(labelText: 'Art Name'),
            ),
            TextField(
              controller: _pictureUrlController,
              decoration: const InputDecoration(labelText: 'Picture URL'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addPost,
              child: const Text('Add Post'),
            ),
          ],
        ),
      ),
    );
  }
}