import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../utils/design_tokens.dart';

/// Shared responsive support destination for mobile, desktop and profile.
enum SupportSection { faq, contact, bug, requests }

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key, this.initialSection = SupportSection.faq});
  final SupportSection initialSection;

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();
  final _steps = TextEditingController();
  final _expected = TextEditingController();
  final _actual = TextEditingController();
  final _reply = TextEditingController();
  late SupportSection _section;
  bool _busy = false, _loading = false, _includePlatform = false;
  String? _error;
  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic>? _ticket;

  String t(String en, String sl) =>
      Localizations.localeOf(context).languageCode == 'sl' ? sl : en;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    if (_section == SupportSection.requests) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTickets());
    }
  }

  @override
  void dispose() {
    for (final c in [_subject, _email, _message, _steps, _expected, _actual, _reply]) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(SupportSection section) {
    setState(() { _section = section; _ticket = null; _error = null; });
    if (section == SupportSection.requests) _loadTickets();
  }

  Future<void> _loadTickets() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await BackendApiService().getMySupportTickets();
      if (mounted) setState(() => _tickets = result);
    } catch (_) {
      if (mounted) setState(() => _error = t(
        'Sign in to view requests or check your connection.',
        'Za ogled zahtevkov se prijavite oziroma preverite povezavo.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String id) async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await BackendApiService().getMySupportTicket(id);
      if (mounted) setState(() => _ticket = result);
    } catch (_) {
      if (mounted) setState(() => _error = t('Could not load request.', 'Zahtevka ni mogoče naložiti.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final bug = _section == SupportSection.bug;
    var message = _message.text.trim();
    if (bug) {
      message = [
        'Issue:\n' + message,
        'Steps:\n' + _steps.text.trim(),
        'Expected:\n' + _expected.text.trim(),
        'Actual:\n' + _actual.text.trim(),
        if (_includePlatform) 'Platform (consented): ' +
          (kIsWeb ? 'web' : defaultTargetPlatform.name),
      ].join('\n\n');
    }
    setState(() { _busy = true; _error = null; });
    try {
      await BackendApiService().createSupportTicket(
        kind: bug ? 'bug' : 'support',
        subject: _subject.text.trim(),
        message: message,
        email: _email.text.trim(),
      );
      if (!mounted) return;
      for (final c in [_subject, _message, _steps, _expected, _actual]) { c.clear(); }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(
        'Request submitted to support.', 'Zahtevek je bil poslan podpori.'))));
      _go(SupportSection.requests);
    } catch (_) {
      if (mounted) setState(() => _error = t(
        'Submission failed. Sign in, check your connection and retry.',
        'Pošiljanje ni uspelo. Prijavite se, preverite povezavo in poskusite znova.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendReply() async {
    final ticket = _ticket;
    if (_busy || ticket == null || _reply.text.trim().isEmpty) return;
    setState(() { _busy = true; _error = null; });
    try {
      await BackendApiService().replyToSupportTicket(
        ticket['id'].toString(), _reply.text.trim());
      _reply.clear();
      await _open(ticket['id'].toString());
    } catch (_) {
      if (mounted) setState(() => _error = t('Reply failed.', 'Odgovor ni bil poslan.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _panel(Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool required = false, int rows = 1, TextInputType? keyboardType}) {
    return TextFormField(
      controller: c, maxLines: rows,
      maxLength: rows == 1 ? 200 : 4000,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, alignLabelWithHint: rows > 1),
      validator: (v) => required && (v ?? '').trim().isEmpty
        ? t('Required', 'Obvezno') : null,
    );
  }

  Widget _faq() {
    final entries = [
      [t('What is art.kubus?', 'Kaj je art.kubus?'),
       t('An open art map for exploring artworks, exhibitions and cultural spaces.',
         'Odprt zemljevid za raziskovanje umetniških del, razstav in kulturnih prostorov.')],
      [t('Can I browse without signing in?', 'Lahko brskam brez prijave?'),
       t('Yes. Public discovery works without an account. Content-changing actions require sign-in.',
         'Da. Javno vsebino lahko raziskujete brez računa. Spreminjanje vsebine zahteva prijavo.')],
      [t('Do I need a wallet?', 'Ali potrebujem denarnico?'),
       t('No wallet is needed to browse the public art map.',
         'Za brskanje po javnem zemljevidu ne potrebujete denarnice.')],
      [t('How do I report an issue?', 'Kako prijavim težavo?'),
       t('Use Report a bug and describe the steps to reproduce. Track your report under My requests.',
         'Odprite Prijava napake in opišite korake ponovitve. Spremljajte jo v Mojih zahtevkih.')],
      [t('Where are support replies?', 'Kje so odgovori podpore?'),
       t('Open My requests and select a ticket to read and respond.',
         'Odprite Moji zahtevki in izberite zahtevek za branje ali odgovor.')],
    ];
    return _panel(Column(children: [
      for (var i = 0; i < entries.length; i++) ...[
        ExpansionTile(key: Key('faq_' + i.toString()),
          tilePadding: EdgeInsets.zero,
          title: Text(entries[i][0]),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: KubusSpacing.md),
              child: Align(alignment: Alignment.centerLeft, child: Text(entries[i][1])),
            ),
          ]),
        if (i != entries.length - 1) const Divider(height: 1),
      ],
    ]));
  }

  Widget _form() {
    final bug = _section == SupportSection.bug;
    return _panel(Form(key: _formKey, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(bug ? t('Report a bug', 'Prijava napake') :
          t('Contact support', 'Kontaktirajte podporo'),
          style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: KubusSpacing.md),
        _field(_subject, t('Subject', 'Zadeva'), required: true),
        _field(_email, t('Reply email (optional)', 'E-naslov za odgovor (neobvezno)'),
          keyboardType: TextInputType.emailAddress),
        _field(_message, bug ? t('What happened?', 'Kaj se je zgodilo?') :
          t('Message', 'Sporočilo'), required: true, rows: 4),
        if (bug) ...[
          _field(_steps, t('Steps to reproduce', 'Koraki za ponovitev'), required: true, rows: 3),
          _field(_expected, t('Expected behavior', 'Pričakovano delovanje'), required: true, rows: 2),
          _field(_actual, t('Actual behavior', 'Dejansko delovanje'), required: true, rows: 2),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _includePlatform,
            onChanged: (v) => setState(() => _includePlatform = v ?? false),
            title: Text(t('Include device platform', 'Vključi platformo naprave')),
            subtitle: Text(t(
              'Optional. No logs, credentials or personal data are collected.',
              'Neobvezno. Brez dnevnikov, poverilnic ali osebnih podatkov.')),
          ),
        ],
        const SizedBox(height: KubusSpacing.md),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.send_outlined),
          label: Text(_busy ? t('Sending…', 'Pošiljanje…') :
            t('Submit request', 'Pošlji zahtevek')),
        ),
      ],
    )));
  }

  String _date(Object? value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return d == null ? '' : d.day.toString() + '.' +
      d.month.toString() + '.' + d.year.toString();
  }

  Widget _requests() {
    if (_ticket != null) return _details();
    return _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(t('My requests', 'Moji zahtevki'),
          style: Theme.of(context).textTheme.titleLarge)),
        IconButton(onPressed: _loading ? null : _loadTickets,
          tooltip: t('Refresh', 'Osveži'), icon: const Icon(Icons.refresh)),
      ]),
      if (_loading) const LinearProgressIndicator(),
      if (!_loading && _tickets.isEmpty)
        Padding(padding: const EdgeInsets.all(KubusSpacing.lg),
          child: Text(t('No requests yet.', 'Zahtevkov še ni.'))),
      for (final item in _tickets) ...[
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(item['kind'] == 'bug' ?
            Icons.bug_report_outlined : Icons.support_agent_outlined),
          title: Text(item['subject']?.toString() ?? ''),
          subtitle: Text((item['status']?.toString() ?? 'open') +
            ' · ' + _date(item['updated_at'])),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(item['id'].toString()),
        ),
      ],
    ]));
  }

  Widget _details() {
    final ticket = _ticket!;
    final replies = ticket['replies'] as List<dynamic>? ?? [];
    return _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _ticket = null),
          icon: const Icon(Icons.arrow_back),
          label: Text(t('All requests', 'Vsi zahtevki')))),
      Text(ticket['subject']?.toString() ?? '',
        style: Theme.of(context).textTheme.titleLarge),
      Text((ticket['status']?.toString() ?? '') + ' · ' + _date(ticket['created_at'])),
      const SizedBox(height: KubusSpacing.lg),
      Text(ticket['message']?.toString() ?? ''),
      for (final raw in replies) ...[
        const Divider(height: 32),
        Text(raw is Map && raw['sender_type'] == 'admin'
          ? t('Support team', 'Ekipa podpore') : t('You', 'Vi'),
          style: Theme.of(context).textTheme.labelLarge),
        Text(raw is Map ? (raw['message']?.toString() ?? '') : ''),
      ],
      if (ticket['status'] != 'closed') ...[
        const Divider(height: 32),
        TextField(controller: _reply, maxLines: 3, maxLength: 5000,
          decoration: InputDecoration(labelText: t('Reply', 'Odgovor'))),
        FilledButton(onPressed: _busy ? null : _sendReply,
          child: Text(t('Send reply', 'Pošlji odgovor'))),
      ],
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final labels = [
      t('FAQ', 'Pogosta vprašanja'),
      t('Contact support', 'Kontakt s podporo'),
      t('Report a bug', 'Prijava napake'),
      t('My requests', 'Moji zahtevki'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(t('Help & support', 'Pomoč in podpora'))),
      body: SafeArea(child: Align(alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(padding: const EdgeInsets.all(KubusSpacing.lg), children: [
            Text(t('Help & support', 'Pomoč in podpora'),
              style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: KubusSpacing.md),
            Wrap(spacing: KubusSpacing.sm, runSpacing: KubusSpacing.sm, children: [
              for (var i = 0; i < SupportSection.values.length; i++)
                ChoiceChip(
                  selected: _section == SupportSection.values[i],
                  label: Text(labels[i]),
                  onSelected: (_) => _go(SupportSection.values[i])),
            ]),
            const SizedBox(height: KubusSpacing.lg),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: KubusSpacing.sm),
            ],
            if (_section == SupportSection.faq) _faq(),
            if (_section == SupportSection.contact || _section == SupportSection.bug) _form(),
            if (_section == SupportSection.requests) _requests(),
          ])))),
    );
  }
}
