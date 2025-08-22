import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../onboarding/web3_onboarding.dart';
import '../onboarding/onboarding_data.dart';

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
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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
        child: Column(
          children: [
            _buildGovernanceHeader(),
            _buildNavigationTabs(),
            Expanded(
              child: IndexedStack(
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
          ],
        ),
      ),
    );
  }

  Widget _buildGovernanceHeader() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.how_to_vote,
                  color: Colors.white,
                  size: 30,
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Decentralized governance for the AR art platform',
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Your Voting Power', '125 KUB8'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Active Proposals', '7'),
              ),
              const SizedBox(width: 12),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        margin: const EdgeInsets.symmetric(horizontal: 4),
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
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[400],
              ),
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
        padding: const EdgeInsets.all(24),
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
        'title': 'New Artist Verification System',
        'description': 'Implement a new verification system for artists to prevent fraud and ensure authenticity.',
        'type': 'Platform Update',
        'votes': '2.1K',
        'timeLeft': '3 days',
        'status': 'Active',
      },
      {
        'title': 'POAP Rewards for Event Attendance',
        'description': 'Introduce POAP tokens for users who attend AR art exhibitions and events.',
        'type': 'Rewards',
        'votes': '1.8K',
        'timeLeft': '5 days',
        'status': 'Active',
      },
    ];

    final proposal = proposals[index % proposals.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4CAF50)),
                ),
                child: Text(
                  proposal['type']!,
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
            proposal['title']!,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            proposal['description']!,
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
        padding: const EdgeInsets.all(24),
        itemCount: votingHistory.length,
        itemBuilder: (context, index) {
          final vote = votingHistory[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
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
        padding: const EdgeInsets.all(24),
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
        padding: const EdgeInsets.all(24),
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
    final transactions = [
      {'type': 'Allocation', 'amount': '50,000 KUB8', 'purpose': 'AR Development Fund', 'date': '2025-08-20'},
      {'type': 'Reward', 'amount': '25,000 KUB8', 'purpose': 'Artist Incentives', 'date': '2025-08-18'},
      {'type': 'Grant', 'amount': '15,000 KUB8', 'purpose': 'Community Events', 'date': '2025-08-15'},
    ];

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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Color(0xFF4CAF50), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx['purpose']!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${tx['type']} • ${tx['date']}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                tx['amount']!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
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
        padding: const EdgeInsets.all(24),
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
    final delegates = [
      {'name': 'art.artist', 'power': '45.2K KUB8', 'delegators': '128', 'participation': '96%'},
      {'name': 'curator.eth', 'power': '32.1K KUB8', 'delegators': '87', 'participation': '89%'},
      {'name': 'gallery.dao', 'power': '28.5K KUB8', 'delegators': '65', 'participation': '94%'},
    ];

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
        ...delegates.map((delegate) => Container(
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF00D4AA)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delegate['name']!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${delegate['power']} • ${delegate['delegators']} delegators • ${delegate['participation']} participation',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _delegateVote(delegate['name']!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 32),
                ),
                child: const Text('Delegate'),
              ),
            ],
          ),
        )).toList(),
      ],
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _revokeDelegation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[600]!),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Revoke Delegation'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _selfDelegate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Self Delegate'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _delegateVote(String delegateName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Delegate Voting Power', style: GoogleFonts.inter(color: Colors.white)),
        content: Text(
          'Are you sure you want to delegate your 125 KUB8 voting power to $delegateName?',
          style: GoogleFonts.inter(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Voting power delegated to $delegateName'),
                  backgroundColor: const Color(0xFF4CAF50),
                ),
              );
            },
            child: const Text('Confirm', style: TextStyle(color: Color(0xFF4CAF50))),
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
