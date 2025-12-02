import 'package:equatable/equatable.dart';

class GroupPostPreview extends Equatable {
  final String id;
  final String? content;
  final DateTime? createdAt;

  const GroupPostPreview({
    required this.id,
    this.content,
    this.createdAt,
  });

  @override
  List<Object?> get props => [id, content, createdAt];
}

class CommunityGroupSummary extends Equatable {
  final String id;
  final String name;
  final String? slug;
  final String? description;
  final String? coverImage;
  final bool isPublic;
  final String ownerWallet;
  final int memberCount;
  final bool isMember;
  final bool isOwner;
  final GroupPostPreview? latestPost;

  const CommunityGroupSummary({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.coverImage,
    required this.isPublic,
    required this.ownerWallet,
    required this.memberCount,
    required this.isMember,
    required this.isOwner,
    this.latestPost,
  });

  CommunityGroupSummary copyWith({
    String? name,
    String? slug,
    String? description,
    String? coverImage,
    bool? isPublic,
    String? ownerWallet,
    int? memberCount,
    bool? isMember,
    bool? isOwner,
    GroupPostPreview? latestPost,
  }) {
    return CommunityGroupSummary(
      id: id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      coverImage: coverImage ?? this.coverImage,
      isPublic: isPublic ?? this.isPublic,
      ownerWallet: ownerWallet ?? this.ownerWallet,
      memberCount: memberCount ?? this.memberCount,
      isMember: isMember ?? this.isMember,
      isOwner: isOwner ?? this.isOwner,
      latestPost: latestPost ?? this.latestPost,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        description,
        coverImage,
        isPublic,
        ownerWallet,
        memberCount,
        isMember,
        isOwner,
        latestPost,
      ];
}

class CommunityGroupReference extends Equatable {
  final String id;
  final String name;
  final String? slug;
  final String? coverImage;
  final String? description;

  const CommunityGroupReference({
    required this.id,
    required this.name,
    this.slug,
    this.coverImage,
    this.description,
  });

  @override
  List<Object?> get props => [id, name, slug, coverImage, description];
}
