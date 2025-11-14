import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';

class MarkerCreator extends StatefulWidget {
  const MarkerCreator({super.key});

  @override
  State<MarkerCreator> createState() => _MarkerCreatorState();
}

class _MarkerCreatorState extends State<MarkerCreator> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  
  String? _selectedImagePath;
  String _selectedCategory = 'Digital Art';
  String _selectedLocation = 'Gallery A';
  bool _isPublic = true;
  bool _enableAR = true;
  bool _enableNFT = false;
  double _royaltyPercentage = 10.0;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              _buildHeader(),
              _buildProgressIndicator(),
              Expanded(child: _buildStepContent()),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create AR Marker',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                'Step ${_currentStep + 1} of 4',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon:  Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () => _showHelp(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(4, (index) {
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
              decoration: BoxDecoration(
                color: index <= _currentStep 
                    ? themeProvider.accentColor 
                    : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildImageUploadStep();
      case 1:
        return _buildArtworkDetailsStep();
      case 2:
        return _buildLocationAndSettingsStep();
      case 3:
        return _buildReviewStep();
      default:
        return Container();
    }
  }

  Widget _buildImageUploadStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Upload Artwork'),
          const SizedBox(height: 24),
          _buildImageUpload(),
          const SizedBox(height: 24),
          if (_selectedImagePath != null) _buildImagePreview(),
          const SizedBox(height: 16),
          _buildUploadTips(),
        ],
      ),
    );
  }

  Widget _buildArtworkDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Artwork Details'),
            const SizedBox(height: 24),
            _buildTextField(
              'Artwork Title',
              _titleController,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter artwork title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Description',
              _descriptionController,
              maxLines: 4,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              'Category',
              _selectedCategory,
              ['Digital Art', 'Photography', 'Painting', 'Sculpture', 'Mixed Media'],
              (value) => setState(() => _selectedCategory = value!),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Tags (comma separated)',
              _tagsController,
              hint: 'e.g., modern, abstract, colorful',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Price (KUB8)',
              _priceController,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter price';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationAndSettingsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Location & Settings'),
          const SizedBox(height: 24),
          _buildDropdown(
            'Display Location',
            _selectedLocation,
            ['Gallery A', 'Gallery B', 'Main Hall', 'Outdoor Space', 'Virtual Gallery'],
            (value) => setState(() => _selectedLocation = value!),
          ),
          const SizedBox(height: 24),
          _buildSwitchTile(
            'Public Artwork',
            'Allow public discovery and viewing',
            _isPublic,
            (value) => setState(() => _isPublic = value),
          ),
          const SizedBox(height: 12),
          _buildSwitchTile(
            'Enable AR Features',
            'Allow users to view artwork in augmented reality',
            _enableAR,
            (value) => setState(() => _enableAR = value),
          ),
          const SizedBox(height: 12),
          _buildSwitchTile(
            'Create as NFT',
            'Mint this artwork as an NFT on the blockchain',
            _enableNFT,
            (value) => setState(() => _enableNFT = value),
          ),
          if (_enableNFT) ...[
            const SizedBox(height: 16),
            _buildRoyaltySlider(),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Review & Publish'),
          const SizedBox(height: 24),
          _buildReviewCard(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Provider.of<ThemeProvider>(context).accentColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your artwork will be processed and the AR marker generated within a few minutes.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUpload() {
    return GestureDetector(
      onTap: () => _selectImage(),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedImagePath != null 
                ? Provider.of<ThemeProvider>(context).accentColor 
                : Provider.of<ThemeProvider>(context).accentColor,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: _selectedImagePath != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      _selectedImagePath!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImagePath = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Icon(
                      Icons.cloud_upload,
                      color: Provider.of<ThemeProvider>(context).accentColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Upload Artwork',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to select from gallery',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _selectedImagePath!,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Upload Tips',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Use high-resolution images (minimum 1080p)\n'
            '• Ensure good lighting and contrast\n'
            '• Avoid overly complex patterns for better AR tracking\n'
            '• Supported formats: JPG, PNG, WebP',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedImagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _selectedImagePath!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            _titleController.text.isNotEmpty ? _titleController.text : 'Artwork Title',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _descriptionController.text.isNotEmpty ? _descriptionController.text : 'Artwork Description',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          _buildReviewItem('Category', _selectedCategory),
          _buildReviewItem('Location', _selectedLocation),
          _buildReviewItem('Price', _priceController.text.isNotEmpty ? '${_priceController.text} KUB8' : '0 KUB8'),
          _buildReviewItem('Tags', _tagsController.text.isNotEmpty ? _tagsController.text : 'No tags'),
          _buildReviewItem('Public', _isPublic ? 'Yes' : 'No'),
          _buildReviewItem('AR Enabled', _enableAR ? 'Yes' : 'No'),
          _buildReviewItem('NFT', _enableNFT ? 'Yes (${_royaltyPercentage.toInt()}% royalty)' : 'No'),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style:  TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Provider.of<ThemeProvider>(context).accentColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> options,
    void Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2)),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            style:  TextStyle(color: Theme.of(context).colorScheme.onSurface),
            items: options.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    void Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Provider.of<ThemeProvider>(context).accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildRoyaltySlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Royalty Percentage: ${_royaltyPercentage.toInt()}%',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _royaltyPercentage,
          min: 0,
          max: 20,
          divisions: 20,
          label: '${_royaltyPercentage.toInt()}%',
          activeColor: Provider.of<ThemeProvider>(context).accentColor,
          onChanged: (value) {
            setState(() {
              _royaltyPercentage = value;
            });
          },
        ),
        Text(
          'Royalty you\'ll earn on secondary sales',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() => _currentStep--),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Previous',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentStep < 3 ? _nextStep : _createArtwork,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.accentColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _currentStep < 3 ? 'Next' : 'Create Artwork',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 3) {
      if (_validateCurrentStep()) {
        setState(() => _currentStep++);
      }
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_selectedImagePath == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select an image')),
          );
          return false;
        }
        return true;
      case 1:
        return _formKey.currentState?.validate() ?? false;
      default:
        return true;
    }
  }

  void _selectImage() {
    // Simulate image selection
    setState(() {
      _selectedImagePath = 'https://picsum.photos/400/600?random=${DateTime.now().millisecondsSinceEpoch}';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image selected successfully')),
    );
  }

  void _createArtwork() {
    // Simulate artwork creation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title:  Text('Success!', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              'Your artwork has been created successfully!',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_enableNFT)
              Text(
                'NFT minting process has been initiated.',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.54)),
                textAlign: TextAlign.center,
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            child: const Text('Create Another'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to gallery
            },
            child: const Text('View Gallery'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _currentStep = 0;
      _selectedImagePath = null;
      _titleController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _tagsController.clear();
      _selectedCategory = 'Digital Art';
      _selectedLocation = 'Gallery A';
      _isPublic = true;
      _enableAR = true;
      _enableNFT = false;
      _royaltyPercentage = 10.0;
    });
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title:  Text('AR Marker Creation', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Follow the 4-step process to create your AR artwork:\n\n'
          '1. Upload: Select your artwork image\n'
          '2. Details: Enter title, description, and pricing\n'
          '3. Settings: Configure location and features\n'
          '4. Review: Confirm and publish your artwork',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}







