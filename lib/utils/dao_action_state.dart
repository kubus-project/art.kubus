class DaoActionState {
  String? reviewActionId;
  String? voteActionId;
  bool proposalSubmitInFlight = false;

  bool beginProposalSubmit() {
    if (proposalSubmitInFlight) return false;
    proposalSubmitInFlight = true;
    return true;
  }

  void endProposalSubmit() {
    proposalSubmitInFlight = false;
  }

  bool beginVote(String proposalId, bool isYes) {
    if (voteActionId != null) return false;
    voteActionId = proposalVoteActionId(proposalId, isYes);
    return true;
  }

  void endVote() {
    voteActionId = null;
  }

  void beginReview(String reviewId) {
    reviewActionId = reviewId;
  }

  void endReview() {
    reviewActionId = null;
  }

  static String proposalVoteActionId(String proposalId, bool isYes) {
    return '$proposalId:${isYes ? 'yes' : 'no'}';
  }
}
