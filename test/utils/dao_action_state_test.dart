import 'package:art_kubus/utils/dao_action_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DaoActionState', () {
    test('proposal submit blocks duplicates and resets explicitly', () {
      final state = DaoActionState();

      expect(state.beginProposalSubmit(), isTrue);
      expect(state.proposalSubmitInFlight, isTrue);
      expect(state.beginProposalSubmit(), isFalse);

      state.endProposalSubmit();

      expect(state.proposalSubmitInFlight, isFalse);
      expect(state.beginProposalSubmit(), isTrue);
    });

    test('vote action id is scoped by proposal and choice', () {
      expect(
        DaoActionState.proposalVoteActionId('proposal-1', true),
        'proposal-1:yes',
      );
      expect(
        DaoActionState.proposalVoteActionId('proposal-1', false),
        'proposal-1:no',
      );
    });

    test('vote blocks concurrent actions and resets explicitly', () {
      final state = DaoActionState();

      expect(state.beginVote('proposal-1', true), isTrue);
      expect(state.voteActionId, 'proposal-1:yes');
      expect(state.beginVote('proposal-1', false), isFalse);
      expect(state.beginVote('proposal-2', true), isFalse);

      state.endVote();

      expect(state.voteActionId, isNull);
      expect(state.beginVote('proposal-1', false), isTrue);
      expect(state.voteActionId, 'proposal-1:no');
    });

    test('review action id resets explicitly', () {
      final state = DaoActionState();

      state.beginReview('review-1');

      expect(state.reviewActionId, 'review-1');

      state.endReview();

      expect(state.reviewActionId, isNull);
    });
  });
}
