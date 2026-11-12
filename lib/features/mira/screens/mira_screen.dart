import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import '../../../shared/components/design_widgets.dart';
import '../../../shared/localization/strings.dart';
import '../../../shared/theme/wattwise_theme.dart';
import '../services/firebase_mira_service.dart';

class MiraScreen extends StatefulWidget {
  const MiraScreen(
      {super.key,
      required this.service,
      required this.language,
      this.unavailableReason,
      this.estimatedRate = 12,
      this.registeredPop = false});
  final FirebaseMiraService? service;
  final String language;
  final String? unavailableReason;
  final double estimatedRate;
  final bool registeredPop;
  @override
  State<MiraScreen> createState() => _MiraScreenState();
}

class _MiraScreenState extends State<MiraScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _history = <Content>[];
  final _messages = <({bool user, String text})>[];
  bool _busy = false;
  String? _failedQuestion;
  String t(String s) => translate(s, widget.language);
  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
        }
      });
  Future<void> _send([String? suggested, bool retry = false]) async {
    final question = (suggested ?? _input.text).trim(),
        service = widget.service;
    if (_busy || question.isEmpty || service == null) return;
    setState(() {
      _busy = true;
      _failedQuestion = null;
      if (!retry) _messages.add((user: true, text: question));
      _input.clear();
    });
    _scrollDown();
    try {
      final answer = await service.reply(question, List.of(_history),
          language: widget.language,
          rate: widget.estimatedRate,
          registeredPop: widget.registeredPop);
      if (!mounted) return;
      setState(() {
        _messages.add((user: false, text: answer));
        _history.addAll([
          Content.text(question),
          Content.model([TextPart(answer)])
        ]);
        if (_history.length > 20) _history.removeRange(0, _history.length - 20);
      });
    } catch (_) {
      if (mounted) setState(() => _failedQuestion = question);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollDown();
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget bubble(Widget child, {bool user = false}) => Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
          widthFactor: user ? 0.83 : 0.92,
          child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: user ? green : Theme.of(context).colorScheme.surface,
                  border: user
                      ? null
                      : Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(user ? 18 : 4),
                      bottomRight: Radius.circular(user ? 4 : 18))),
              child: DefaultTextStyle.merge(
                  style: TextStyle(
                      color: user
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      height: 1.5),
                  child: child))));
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18)),
              child: const DesignIcon('17_8_imgMiraIcon')),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Mira',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary)),
                Text(t('Your energy assistant'),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant))
              ]))
        ]),
        const SizedBox(height: 16),
        Expanded(
            child: ListView(controller: _scroll, children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 18, top: 8),
              child: Text(t('Today'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11))),
          bubble(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Hi! I’m Mira.'),
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Text(t(
                'Let’s make your energy use smarter. Ask me about your bill or ways to save.'))
          ])),
          if (widget.service == null)
            bubble(Text(widget.unavailableReason ??
                'Mira is unavailable. Please check Firebase setup.')),
          for (final message in _messages)
            bubble(SelectableText(message.text), user: message.user),
          if (_busy)
            bubble(const Row(children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Mira is thinking…')
            ])),
          if (_failedQuestion != null)
            bubble(
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                  'Could not reach Mira. Check your connection, then retry.'),
              TextButton(
                  onPressed: () => _send(_failedQuestion, true),
                  child: const Text('Retry'))
            ])),
        ])),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final suggestion in ['Explain my bill', 'Appliance tips'])
                Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: OutlinedButton(
                        onPressed: _busy || widget.service == null
                            ? null
                            : () => _send(t(suggestion)),
                        style: OutlinedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.surface,
                            side: BorderSide(
                                color: Theme.of(context).dividerColor)),
                        child: Text(t(suggestion),
                            style: const TextStyle(fontSize: 12))))
            ])),
        const SizedBox(height: 8),
        Container(
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(28)),
            padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                  child: TextField(
                      controller: _input,
                      enabled: !_busy && widget.service != null,
                      maxLength: 4000,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                          hintText: t('Ask Mira anything...'),
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12)),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send())),
              IconButton.filled(
                  onPressed:
                      _busy || widget.service == null ? null : () => _send(),
                  style: IconButton.styleFrom(
                      backgroundColor: green, foregroundColor: Colors.white),
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: t('Send'))
            ])),
        const SizedBox(height: 5),
        Text(t('Internet required. Mira uses your appliances and reviewed bill.'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 9,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]));
}
