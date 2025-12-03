import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../../../config/config.dart';
import '../../../config/api_keys.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/web3provider.dart';
import '../../../services/backend_api_service.dart';

class ArtworkCreator extends StatefulWidget {
  final VoidCallback? onCreated;

  const ArtworkCreator({super.key, this.onCreated});

  @override
  State<ArtworkCreator> createState() => _ArtworkCreatorState();
}

class _ArtworkCreatorState extends State<ArtworkCreator> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  Uint8List? _selectedModelBytes;
  String? _selectedModelName;
  String _selectedCategory = 'Digital Art';
  String _selectedLocation = 'Gallery A';
  bool _isPublic = true;
  bool _enableAR = AppConfig.enableARViewer;
  bool _enableNFT = AppConfig.enableNFTMinting;
  double _royaltyPercentage = 10.0;
  int _currentStep = 0;
  bool _isSubmitting = false;
  final BackendApiService _api = BackendApiService();
  final ImagePicker _imagePicker = ImagePicker();

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
                'Create an Artwork',
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
    const studioColor = Color(0xFFF59E0B);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(4, (index) {
          return Expanded(
            child: Container(
              height: 5,
              margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
              decoration: BoxDecoration(
                color: index <= _currentStep 
                    ? studioColor 
                    : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
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
          if (_selectedImageBytes != null) _buildImagePreview(),
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
          if (_enableAR) ...[
            const SizedBox(height: 12),
            _buildModelUploadRow(),
          ],
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
            color: Provider.of<ThemeProvider>(context).accentColor,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: _selectedImageBytes != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      _selectedImageBytes!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedImageBytes = null;
                        _selectedImageName = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onPrimary,
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
            child: Image.memory(
              _selectedImageBytes!,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadTips() {
    final accent = Provider.of<ThemeProvider>(context, listen: false).accentColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Upload Tips',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '- Use high-resolution images (minimum 1080p)\n'
            '- Ensure good lighting and contrast\n'
            '- Avoid overly complex patterns for better AR tracking\n'
            '- Supported formats: JPG, PNG, WebP',
              style: GoogleFonts.inter(
              fontSize: 12,
              color: onSurface.withValues(alpha: 0.8),
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
          if (_selectedImageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _selectedImageBytes!,
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
            activeThumbColor: Provider.of<ThemeProvider>(context).accentColor,
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

  Widget _buildModelUploadRow() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final hasModel = _selectedModelBytes != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.view_in_ar, color: themeProvider.accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasModel ? (_selectedModelName ?? 'Model selected') : 'Upload AR model (glb/gltf/usdz)',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  hasModel ? 'Ready for AR launch' : 'Optional, but required to enable AR experience',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _pickModelFile,
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              hasModel ? 'Replace' : 'Upload',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    const studioColor = Color(0xFFF59E0B);
    
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
              onPressed: _isSubmitting ? null : (_currentStep < 3 ? _nextStep : _createArtwork),
              style: ElevatedButton.styleFrom(
                backgroundColor: studioColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting && _currentStep == 3
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onSurface),
                      ),
                    )
                  : Text(
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

  Future<void> _pickCoverImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = file.name.isNotEmpty ? file.name : path.basename(file.path);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cover selected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _pickModelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['glb', 'gltf', 'usdz'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        throw Exception('No bytes available for selected file.');
      }
      setState(() {
        _selectedModelBytes = Uint8List.fromList(file.bytes!);
        _selectedModelName = file.name;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('3D model selected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick model: $e')),
      );
    }
  }

  List<String> _parseTags() {
    return _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_selectedImageBytes == null) {
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
    _pickCoverImage();
  }

  void _createArtwork() {
    _submitArtwork();
  }

  Future<void> _submitArtwork() async {
    if (_isSubmitting) return;
    if (!_validateCurrentStep()) return;
    final messenger = ScaffoldMessenger.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final profileProvider = context.read<ProfileProvider>();
    final web3Provider = context.read<Web3Provider>();
    final artworkProvider = context.read<ArtworkProvider>();

    final wallet = (profileProvider.currentUser?.walletAddress ?? web3Provider.walletAddress).trim();
    if (wallet.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Connect your wallet to publish artwork.')),
      );
      return;
    }

    if (_selectedImageBytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please select a cover image.')),
      );
      return;
    }

    if (_enableAR && _selectedModelBytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Upload a 3D model to enable AR.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _api.ensureAuthLoaded(walletAddress: wallet);

      final coverUpload = await _api.uploadFile(
        fileBytes: _selectedImageBytes!,
        fileName: _selectedImageName ?? 'artwork_cover.jpg',
        fileType: 'image',
        metadata: {
          'source': 'artist_studio',
          'uploadFolder': 'artworks/covers',
        },
        walletAddress: wallet,
      );

      final coverUrl = coverUpload['uploadedUrl'] as String? ?? coverUpload['data']?['url'] as String?;
      if (coverUrl == null || coverUrl.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Upload succeeded but cover URL missing.')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      String? modelUrl;
      String? modelCid;
      if (_enableAR && _selectedModelBytes != null) {
        final modelUpload = await _api.uploadFile(
          fileBytes: _selectedModelBytes!,
          fileName: _selectedModelName ?? 'ar_model.glb',
          fileType: 'model',
          metadata: {
            'source': 'artist_studio',
            'uploadFolder': 'ar/models',
          },
          walletAddress: wallet,
        );
        modelUrl = modelUpload['uploadedUrl'] as String? ?? modelUpload['data']?['url'] as String?;
        modelCid = modelUpload['data']?['cid'] as String?;
      }

      final price = double.tryParse(_priceController.text.trim());
      String? mintSignature;
      String? priceSyncSignature;

      if (_enableNFT && AppConfig.useRealBlockchain) {
        try {
          final web3 = context.read<Web3Provider>();
          final metadata = <String, dynamic>{
            'name': _titleController.text.trim(),
            'symbol': 'KUB8',
            'description': _descriptionController.text.trim(),
            'uri': coverUrl,
            'sellerFeeBasisPoints': (_royaltyPercentage * 100).round(),
            'collectionMint': ApiKeys.kub8MintAddress,
            'creators': [
              {
                'address': wallet,
                'verified': true,
                'share': 100,
              },
            ],
            if (modelCid != null) 'modelCid': modelCid,
            if (modelUrl != null) 'animation_url': modelUrl,
          };
          mintSignature = await web3.mintArtworkNFT(metadata);
        } catch (e) {
          debugPrint('NFT mint attempt failed (soft): $e');
        }

        if (price != null) {
          try {
            // Simulated price sync to chain; when on-chain listing is wired, replace with real call.
            priceSyncSignature = 'price-${DateTime.now().millisecondsSinceEpoch}';
          } catch (e) {
            debugPrint('Price sync failed (soft): $e');
          }
        }
      }

      final metadata = <String, dynamic>{
        'source': 'artist_studio',
        'locationName': _selectedLocation,
        if (_enableNFT) 'royaltyPercent': _royaltyPercentage,
        if (_enableNFT && mintSignature != null) 'nftMintTx': mintSignature,
        if (price != null) 'listPriceKub8': price,
        if (priceSyncSignature != null) 'priceSyncTx': priceSyncSignature,
      };

      final artwork = await _api.createArtworkRecord(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: coverUrl,
        walletAddress: wallet,
        artistName: profileProvider.currentUser?.displayName,
        category: _selectedCategory,
        tags: _parseTags(),
        isPublic: _isPublic,
        enableAR: _enableAR && modelUrl != null,
        modelUrl: modelUrl,
        modelCid: modelCid,
        arScale: 1,
        mintAsNFT: _enableNFT,
        price: price,
        locationName: _selectedLocation,
        metadata: metadata,
      );

      if (artwork != null) {
        artworkProvider.addOrUpdateArtwork(artwork);
      } else {
        // If backend didn't return data, still treat as success per requirement
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Artwork submitted. Backend response pending.'),
            backgroundColor: themeProvider.accentColor,
          ),
        );
        await artworkProvider.loadArtworks();
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          title: Text('Success!', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _resetForm();
                widget.onCreated?.call();
              },
              child: const Text('Create Another'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onCreated?.call();
              },
              child: const Text('View Gallery'),
            ),
          ],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to create artwork: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _currentStep = 0;
      _titleController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _tagsController.clear();
      _selectedCategory = 'Digital Art';
      _selectedLocation = 'Gallery A';
      _isPublic = true;
      _enableAR = AppConfig.enableARViewer;
      _enableNFT = AppConfig.enableNFTMinting;
      _royaltyPercentage = 10.0;
      _selectedImageBytes = null;
      _selectedImageName = null;
      _selectedModelBytes = null;
      _selectedModelName = null;
      _isSubmitting = false;
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







