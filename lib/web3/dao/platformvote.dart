import 'package:flutter/material.dart';

class Proposal {
  final String title;
  final String description;
  int votes;

  Proposal({required this.title, required this.description, this.votes = 0});
}

class PlatformVote extends StatefulWidget {
  const PlatformVote({super.key});

  @override
  PlatformVotePageState createState() => PlatformVotePageState();
}

class PlatformVotePageState extends State<PlatformVote> {
  final List<Proposal> proposals = [];
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  void _addProposal() {
    if (titleController.text.isNotEmpty && descriptionController.text.isNotEmpty) {
      setState(() {
        proposals.add(Proposal(
          title: titleController.text,
          description: descriptionController.text,
        ));
      });
      titleController.clear();
      descriptionController.clear();
    }
  }

  void _voteOnProposal(int index) {
    setState(() {
      proposals[index].votes += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Proposals'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildProposalForm(),
              const SizedBox(height: 20),
              _buildProposalList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProposalForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create a Proposal',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: 'Title',
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: descriptionController,
          decoration: InputDecoration(
            labelText: 'Description',
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _addProposal,
          child: const Text('Submit Proposal'),
        ),
      ],
    );
  }

  Widget _buildProposalList() {
    return Expanded(
      child: ListView.builder(
        itemCount: proposals.length,
        itemBuilder: (context, index) {
          final proposal = proposals[index];
          return Card(
            child: ListTile(
              title: Text(proposal.title),
              subtitle: Text(proposal.description),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(proposal.votes.toString()),
                  IconButton(
                    icon: const Icon(Icons.thumb_up),
                    onPressed: () => _voteOnProposal(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}