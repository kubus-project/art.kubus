import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../onboarding/web3_onboarding.dart';
import '../onboarding/onboarding_data.dart';
import '../../providers/dao_provider.dart';

class GovernanceHub extends StatefulWidget {
  const GovernanceHub({super.key});

  @override
  State<GovernanceHub> createState() => _GovernanceHubState();
}

class _GovernanceHubState extends State<GovernanceHub> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Proposal creation form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  String _selectedCategory = 'Platform Update';
  final _votingPeriodController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Initialize pages list but don't build widgets yet
    _checkOnboarding();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _votingPeriodController.dispose();
    super.dispose();
  }

  Future<void> _checkOnboarding() async {
    if (await isOnboardingNeeded(DAOOnboardingData.featureName)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOnboarding();
      });
    }
  }

  void _showOnboarding() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Web3OnboardingScreen(
          featureName: DAOOnboardingData.featureName,
          pages: DAOOnboardingData.pages,
          onComplete: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'DAO Governance',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: _showOnboarding,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showGovernanceInfo,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildGovernanceHeader(),
                    _buildNavigationTabs(),
                  ],
                ),
              ),
            ];
          },
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildActiveProposals(),
              _buildVotingHistory(),
              _buildCreateProposal(),
              _buildTreasury(),
              _buildDelegation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGovernanceHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF00D4AA)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(
                  Icons.how_to_vote,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'art.kubus DAO',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Decentralized governance for the AR art platform',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Your Voting Power', '125 KUB8'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard('Active Proposals', '7'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard('Total Members', '2.4K'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabButton('Proposals', Icons.how_to_vote, 0),
            _buildTabButton('History', Icons.history, 1),
            _buildTabButton('Create', Icons.add_circle_outline, 2),
            _buildTabButton('Treasury', Icons.account_balance, 3),
            _buildTabButton('Delegate', Icons.people, 4),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[400],
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[400],
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveProposals() {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return _buildProposalCard(index);
        },
      ),
    );
  }

  Widget _buildProposalCard(int index) {
    final proposals = [
      {
        'type': 'COMMUNITY',
        'title': 'Artist Revenue Share Update',
        'description': 'Proposal to increase artist revenue share from 70% to 80% for all marketplace transactions',
        'votes': 234,
        'timeLeft': '3 days',
      },
      {
        'type': 'TECHNICAL',
        'title': 'New AR Feature Implementation',
        'description': 'Add advanced AR tracking capabilities for better artwork visualization and interaction',
        'votes': 156,
        'timeLeft': '5 days',
      },
      {
        'type': 'TREASURY',
        'title': 'Community Fund Allocation',
        'description': 'Allocate 50,000 KUB8 tokens for community development and educational programs',
        'votes': 89,
        'timeLeft': '1 week',
      },
      {
        'type': 'GOVERNANCE',
        'title': 'Voting Power Restructure',
        'description': 'Modify voting power calculation to include both token holding and community participation',
        'votes': 312,
        'timeLeft': '2 days',
      },
      {
        'type': 'PARTNERSHIP',
        'title': 'Museum Partnership Program',
        'description': 'Establish partnerships with major museums for digital art exhibitions and collections',
        'votes': 78,
        'timeLeft': '6 days',
      },
    ];

    final proposal = proposals[index % proposals.length];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4CAF50)),
                ),
                child: Text(
                  proposal['type'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.more_vert, color: Colors.grey[400]),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            proposal['title'] as String,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            proposal['description'] as String,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[400],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildVoteInfo(Icons.how_to_vote, '${proposal['votes']} votes'),
              const SizedBox(width: 16),
              _buildVoteInfo(Icons.access_time, '${proposal['timeLeft']} left'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _vote(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Vote Yes'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _vote(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey[600]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Vote No'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoteInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.grey[400], size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildVotingHistory() {
    final votingHistory = [
      {
        'title': 'Artist Revenue Share Update',
        'date': '2025-08-15',
        'vote': 'Yes',
        'result': 'Passed',
        'participation': '78%',
        'yourPower': '125 KUB8',
      },
      {
        'title': 'New AR Feature Implementation',
        'date': '2025-08-10',
        'vote': 'No',
        'result': 'Failed',
        'participation': '65%',
        'yourPower': '125 KUB8',
      },
      {
        'title': 'Community Fund Allocation',
        'date': '2025-08-05',
        'vote': 'Yes',
        'result': 'Passed',
        'participation': '82%',
        'yourPower': '125 KUB8',
      },
    ];

    return Container(
      color: const Color(0xFF0A0A0A),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: votingHistory.length,
        itemBuilder: (context, index) {
          final vote = votingHistory[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        vote['title']!,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: vote['result'] == 'Passed' 
                            ? const Color(0xFF4CAF50).withOpacity(0.1)
                            : const Color(0xFFFF5252).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: vote['result'] == 'Passed' 
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF5252),
                        ),
                      ),
                      child: Text(
                        vote['result']!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: vote['result'] == 'Passed' 
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF5252),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildHistoryInfo('Date', vote['date']!),
                    const SizedBox(width: 24),
                    _buildHistoryInfo('Your Vote', vote['vote']!),
                    const SizedBox(width: 24),
                    _buildHistoryInfo('Participation', vote['participation']!),
                  ],
                ),
                const SizedBox(height: 8),
                _buildHistoryInfo('Your Voting Power', vote['yourPower']!),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCreateProposal() {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New Proposal',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Submit a proposal for the community to vote on',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            _buildFormField(
              'Proposal Title',
              'Enter a clear, descriptive title',
              _titleController,
            ),
            const SizedBox(height: 16),
            _buildCategorySelector(),
            const SizedBox(height: 16),
            _buildFormField(
              'Description',
              'Provide detailed explanation of your proposal',
              _descriptionController,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Voting Period (Days)',
              'How many days should voting be open?',
              _votingPeriodController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            _buildProposalRequirements(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitProposal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Submit Proposal',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(
    String label,
    String hint,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4CAF50)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    final categories = [
      'Platform Update',
      'New Feature',
      'Policy Change',
      'Treasury Allocation',
      'Community Initiative',
      'Technical Improvement',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: DropdownButton<String>(
            value: _selectedCategory,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white),
            items: categories.map((category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProposalRequirements() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF4CAF50), size: 20),
              const SizedBox(width: 8),
              Text(
                'Proposal Requirements',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRequirementItem('Minimum 100 KUB8 tokens to submit', true),
          _buildRequirementItem('Proposal must be clearly defined', true),
          _buildRequirementItem('Voting period: 3-14 days', true),
          _buildRequirementItem('Quorum: 15% of total supply', false),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitProposal() {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Color(0xFFFF5252),
        ),
      );
      return;
    }

    // Simulate proposal submission
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'Proposal Submitted',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Text(
          'Your proposal has been submitted successfully. It will be reviewed by the community and voting will begin in 24 hours.',
          style: GoogleFonts.inter(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearForm();
              setState(() => _selectedIndex = 0);
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFF4CAF50))),
          ),
        ],
      ),
    );
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _votingPeriodController.clear();
    setState(() {
      _selectedCategory = 'Platform Update';
    });
  }

  Widget _buildTreasury() {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DAO Treasury',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Community-controlled funds for platform development',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            _buildTreasuryOverview(),
            const SizedBox(height: 24),
            _buildRecentTransactions(),
            const SizedBox(height: 24),
            _buildTreasuryProposals(),
          ],
        ),
      ),
    );
  }

  Widget _buildTreasuryOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF4CAF50)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Treasury Value',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      '2,450,000 KUB8',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '≈ \$490,000 USD',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildTreasuryStatCard('Monthly Inflow', '125K KUB8', Icons.trending_up)),
              const SizedBox(width: 12),
              Expanded(child: _buildTreasuryStatCard('Monthly Outflow', '89K KUB8', Icons.trending_down)),
              const SizedBox(width: 12),
              Expanded(child: _buildTreasuryStatCard('Reserve Ratio', '78%', Icons.security)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTreasuryStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Consumer<DAOProvider>(
      builder: (context, daoProvider, child) {
        final transactions = daoProvider.getRecentTransactions(limit: 5);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Transactions',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            if (transactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        color: Colors.grey[600],
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No recent transactions',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...transactions.map((tx) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tx.type == 'allocation'
                            ? Colors.blue.withOpacity(0.2)
                            : tx.type == 'reward'
                                ? Colors.green.withOpacity(0.2)
                                : Colors.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        tx.type == 'allocation'
                            ? Icons.account_balance
                            : tx.type == 'reward'
                                ? Icons.emoji_events
                                : Icons.card_giftcard,
                        color: tx.type == 'allocation'
                            ? Colors.blue
                            : tx.type == 'reward'
                                ? Colors.green
                                : Colors.purple,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.type.toString().split('.').last.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            tx.description,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${tx.amount.toStringAsFixed(0)} ${tx.currency}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _formatDate(tx.timestamp),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }

  Widget _buildTreasuryProposals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Pending Treasury Proposals',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _selectedIndex = 2),
              child: const Text('Create Proposal', style: TextStyle(color: Color(0xFF4CAF50))),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD93D).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD93D)),
                    ),
                    child: Text(
                      'Treasury',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFFFD93D),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '5 days left',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Mobile App Development Fund',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Allocate 200,000 KUB8 for mobile app development and testing',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _vote(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _vote(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey[600]!),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDelegation() {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vote Delegation',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Delegate your voting power to trusted community members',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            _buildCurrentDelegation(),
            const SizedBox(height: 24),
            _buildTopDelegates(),
            const SizedBox(height: 24),
            _buildDelegationActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentDelegation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Color(0xFF4CAF50), size: 24),
              const SizedBox(width: 12),
              Text(
                'Your Delegation Status',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDelegationInfo('Voting Power', '125 KUB8'),
              ),
              Expanded(
                child: _buildDelegationInfo('Delegated To', 'Self'),
              ),
              Expanded(
                child: _buildDelegationInfo('Delegators', '3'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDelegationInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTopDelegates() {
    return Consumer<DAOProvider>(
      builder: (context, daoProvider, child) {
        final delegates = daoProvider.getTopDelegates(limit: 5);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Delegates',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            if (delegates.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.people,
                        color: Colors.grey[600],
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No delegates yet',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...delegates.map((delegate) => GestureDetector(
                onTap: () => _delegateVote(delegate.name),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            delegate.name.substring(0, 1).toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              delegate.name,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${delegate.delegatorCount} delegators • ${(delegate.participationRate * 100).toStringAsFixed(0)}% participation',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${(delegate.votingPower / 1000).toStringAsFixed(1)}K KUB8',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Active',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF4CAF50),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to delegate',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
          ],
        );
      },
    );
  }

  Widget _buildDelegationActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delegation Actions',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose how to use your voting power',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 16),
        // Delegate to Others Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showDelegateSelection,
            icon: const Icon(Icons.people_outline, size: 20),
            label: const Text('Delegate to Trusted Members'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _selfDelegate,
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Self Delegate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[600]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _revokeDelegation,
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Revoke'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[600]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showDelegateSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select a Delegate',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a trusted community member to vote on your behalf',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<DAOProvider>(
                  builder: (context, daoProvider, child) {
                    final delegates = daoProvider.getTopDelegates(limit: 10);
                    
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: delegates.length,
                      itemBuilder: (context, index) {
                        final delegate = delegates[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _delegateVote(delegate.name);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2A2A2A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      delegate.name.substring(0, 1).toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        delegate.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        '${delegate.delegatorCount} delegators • ${(delegate.participationRate * 100).toStringAsFixed(0)}% participation',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${(delegate.votingPower / 1000).toStringAsFixed(1)}K KUB8',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _delegateVote(String delegateName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Delegate Voting Power', style: GoogleFonts.inter(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delegate your 125 KUB8 voting power to $delegateName?',
              style: GoogleFonts.inter(color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4CAF50)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF4CAF50), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Delegation Benefits',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Your delegate will vote on your behalf\n• You can revoke delegation anytime\n• Your voting power remains yours',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey[400],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completeDelegation(delegateName);
            },
            child: const Text('Confirm Delegation', style: TextStyle(color: Color(0xFF4CAF50))),
          ),
        ],
      ),
    );
  }

  void _completeDelegation(String delegateName) {
    // Here you would typically call a smart contract or API
    // For now, we'll simulate the delegation
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voting power successfully delegated to $delegateName'),
        backgroundColor: const Color(0xFF4CAF50),
        action: SnackBarAction(
          label: 'View Details',
          textColor: Colors.white,
          onPressed: () {
            // Show delegation details
            _showDelegationDetails(delegateName);
          },
        ),
      ),
    );
    
    // Update the delegation status in the UI
    setState(() {
      // You would update your delegation state here
    });
  }

  void _showDelegationDetails(String delegateName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24),
                const SizedBox(width: 12),
                Text(
                  'Delegation Active',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Delegate', delegateName),
            _buildDetailRow('Voting Power', '125 KUB8'),
            _buildDetailRow('Status', 'Active'),
            _buildDetailRow('Started', 'Just now'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _revokeDelegation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[600]!),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Revoke Delegation'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _revokeDelegation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delegation revoked successfully'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  void _selfDelegate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Self-delegation enabled'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  void _vote(bool isYes) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Vote ${isYes ? 'Yes' : 'No'} cast successfully!'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }

  void _showGovernanceInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How DAO Governance Works',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'The art.kubus DAO allows community members to vote on platform decisions, new features, and policies. Your voting power is based on your KUB8 token holdings.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[400],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
