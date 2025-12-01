import 'package:flutter/material.dart';
import 'web3_onboarding.dart';

class DAOOnboardingData {
  static const String featureName = 'DAO';
  
  static final List<OnboardingPage> pages = [
    const OnboardingPage(
      title: 'Welcome to DAO Governance',
      description: 'Participate in decentralized decision-making for the art.kubus ecosystem. Your voice matters in shaping the future of digital art.',
      icon: Icons.account_balance,
      gradientColors: [Color.fromARGB(255, 6, 89, 141), Color(0xFF0B6E4F)],
      features: [
        'Vote on important community proposals',
        'Create and submit your own proposals',
        'Earn KUB8 tokens for active participation',
        'Connect with fellow art enthusiasts',
      ],
    ),
    const OnboardingPage(
      title: 'Your Voting Power',
      description: 'Your voting power is determined by your KUB8 token balance. The more tokens you hold, the greater your influence in governance decisions.',
      icon: Icons.how_to_vote,
      gradientColors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
      features: [
        'Voting power = Your KUB8 balance',
        'Vote on active proposals',
        'See real-time voting results',
        'Track your participation history',
      ],
    ),
    const OnboardingPage(
      title: 'Create Proposals',
      description: 'Have an idea to improve the platform? Submit proposals for new features, policy changes, or community initiatives.',
      icon: Icons.lightbulb_outline,
      gradientColors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
      features: [
        'Submit detailed proposals with descriptions',
        'Set voting duration and requirements',
        'Gather community support',
        'Track proposal status and engagement',
      ],
    ),
    const OnboardingPage(
      title: 'Ready to Govern',
      description: 'You\'re all set to participate in DAO governance! Start by exploring active proposals or creating your first one.',
      icon: Icons.rocket_launch,
      gradientColors: [Color(0xFFEC4899), Color(0xFF0B6E4F)],
      features: [
        'Browse and vote on active proposals',
        'Check your voting history',
        'Monitor governance statistics',
        'Connect with the community',
      ],
    ),
  ];
}

class ArtistStudioOnboardingData {
  static const String featureName = 'Artist Studio';
  
  static final List<OnboardingPage> pages = [
    const OnboardingPage(
      title: 'Welcome to Artist Studio',
      description: 'Your creative workspace for managing artworks, creating AR markers, and analyzing your artistic journey in the metaverse.',
      icon: Icons.palette,
      gradientColors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
      features: [
        'Manage your digital artwork collection',
        'Create interactive AR markers',
        'Track performance analytics',
        'Monetize your creative work',
      ],
    ),
    const OnboardingPage(
      title: 'Artwork Gallery',
      description: 'Showcase your digital creations and NFTs. Upload, organize, and display your artworks for the world to discover.',
      icon: Icons.photo_library,
      gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
      features: [
        'Upload and organize your artworks',
        'Create detailed artwork descriptions',
        'Set pricing and availability',
        'Track views and engagement',
      ],
    ),
    const OnboardingPage(
      title: 'AR Marker Creator',
      description: 'Transform your artworks into immersive AR experiences. Place markers in real-world locations for others to discover.',
      icon: Icons.view_in_ar,
      gradientColors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
      features: [
        'Create geo-located AR markers',
        'Attach artworks to real locations',
        'Set discovery rewards in KUB8',
        'Monitor marker interactions',
      ],
    ),
    const OnboardingPage(
      title: 'Analytics Dashboard',
      description: 'Track your artistic performance with detailed analytics on views, discoveries, earnings, and community engagement.',
      icon: Icons.analytics,
      gradientColors: [Color(0xFFEC4899), Color(0xFF0B6E4F)],
      features: [
        'Monitor artwork performance',
        'Track KUB8 earnings',
        'Analyze discovery patterns',
        'Export detailed reports',
      ],
    ),
    const OnboardingPage(
      title: 'Start Creating',
      description: 'Your studio is ready! Begin by uploading your first artwork or creating an AR marker to share with the community.',
      icon: Icons.create,
      gradientColors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
      features: [
        'Upload your first artwork',
        'Create your first AR marker',
        'Explore community creations',
        'Start earning KUB8 tokens',
      ],
    ),
  ];
}

class InstitutionHubOnboardingData {
  static const String featureName = 'Institution Hub';
  
  static final List<OnboardingPage> pages = [
    const OnboardingPage(
      title: 'Welcome to Institution Hub',
      description: 'Manage cultural events, exhibitions, and educational programs. Connect your institution with the digital art community.',
      icon: Icons.museum,
      gradientColors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
      features: [
        'Create and manage cultural events',
        'Host virtual exhibitions',
        'Engage with the art community',
        'Track event performance',
      ],
    ),
    const OnboardingPage(
      title: 'Event Management',
      description: 'Organize exhibitions, workshops, and cultural events. Manage attendees, scheduling, and promotional activities.',
      icon: Icons.event,
      gradientColors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
      features: [
        'Schedule exhibitions and workshops',
        'Manage event registration',
        'Send notifications to attendees',
        'Track event engagement',
      ],
    ),
    const OnboardingPage(
      title: 'Event Creation Tools',
      description: 'Design compelling events with rich descriptions, media content, and interactive elements to attract participants.',
      icon: Icons.create_new_folder,
      gradientColors: [Color(0xFF072A40), Color(0xFF0B6E4F)],
      features: [
        'Design event pages with media',
        'Set capacity and pricing',
        'Create promotional materials',
        'Integrate with calendar systems',
      ],
    ),
    const OnboardingPage(
      title: 'Analytics & Insights',
      description: 'Measure the success of your events with comprehensive analytics on attendance, engagement, and community impact.',
      icon: Icons.insights,
      gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
      features: [
        'Track attendance and engagement',
        'Monitor revenue and costs',
        'Analyze participant feedback',
        'Generate detailed reports',
      ],
    ),
    const OnboardingPage(
      title: 'Launch Your Events',
      description: 'Ready to connect with the art community! Start by creating your first event or exploring ongoing exhibitions.',
      icon: Icons.launch,
      gradientColors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
      features: [
        'Create your first event',
        'Explore community events',
        'Connect with other institutions',
        'Build your cultural network',
      ],
    ),
  ];
}

class MarketplaceOnboardingData {
  static const String featureName = 'Marketplace';
  
  static final List<OnboardingPage> pages = [
    const OnboardingPage(
      title: 'Welcome to NFT Marketplace',
      description: 'Discover, buy, and sell unique digital art NFTs in our vibrant marketplace. Connect with artists and collectors worldwide.',
      icon: Icons.store,
      gradientColors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      features: [
        'Browse thousands of unique NFTs',
        'Buy and sell with secure transactions',
        'Discover trending and featured art',
        'Support your favorite artists',
      ],
    ),
    const OnboardingPage(
      title: 'Discover Amazing Art',
      description: 'Explore our curated collection of digital art from talented creators. Filter by style, price, rarity, and more.',
      icon: Icons.explore,
      gradientColors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
      features: [
        'Filter by price, category, and rarity',
        'View detailed artwork information',
        'Check authenticity and provenance',
        'Save favorites to your wishlist',
      ],
    ),
    const OnboardingPage(
      title: 'List Your Creations',
      description: 'Artists can easily list their NFTs for sale. Set your price, add descriptions, and reach collectors worldwide.',
      icon: Icons.sell,
      gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
      features: [
        'Upload and mint your digital art',
        'Set fixed prices or enable auctions',
        'Add detailed descriptions and tags',
        'Track sales and earnings',
      ],
    ),
    const OnboardingPage(
      title: 'Start Trading',
      description: 'You\'re ready to dive into the NFT marketplace! Start exploring, buying, or listing your first digital artwork.',
      icon: Icons.shopping_cart,
      gradientColors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
      features: [
        'Explore featured collections',
        'Make your first purchase',
        'List your artwork for sale',
        'Join the creative community',
      ],
    ),
  ];
}
