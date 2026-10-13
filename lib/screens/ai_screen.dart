import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state/auth_state.dart';
import '../theme.dart';

/// Endpoint the assistant posts to. Expected contract:
///   request  { "messages": [{ "role": "user"|"assistant", "content": "..." }] }
///   response { "reply": "..." }
const aiChatPath = '/api/ai/chat';

/// Opens the assistant with a circular reveal growing out of [origin] (the
/// center nav button), so it feels like the orb expands into the screen.
void openAiAssistant(BuildContext context, Offset origin) {
  Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, _, _) => const AiScreen(),
    transitionsBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      final size = MediaQuery.sizeOf(ctx);
      final maxR = math.sqrt(size.width * size.width + size.height * size.height);
      return AnimatedBuilder(
        animation: curved,
        builder: (_, _) => ClipPath(
          clipper: _CircleReveal(origin, 28 + (maxR - 28) * curved.value),
          child: Opacity(opacity: (curved.value * 2).clamp(0, 1), child: child),
        ),
      );
    },
  ));
}

class _CircleReveal extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  _CircleReveal(this.center, this.radius);
  @override
  Path getClip(Size size) => Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  @override
  bool shouldReclip(_CircleReveal old) => old.radius != radius || old.center != center;
}

class _Msg {
  final String role;
  final String content;
  final bool error;
  const _Msg(this.role, this.content, {this.error = false});
}

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Msg>[];
  bool _thinking = false;

  static const _suggestions = [
    'How are sales this month vs last month?',
    'Which items are below reorder point?',
    'Top 5 customers by revenue',
    'Summarize inventory health',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _thinking) return;
    _input.clear();
    setState(() {
      _messages.add(_Msg('user', text));
      _thinking = true;
    });
    _toBottom();
    try {
      final api = context.read<AuthState>().client;
      final res = await api.post(aiChatPath, {
        'messages': [
          for (final m in _messages.where((m) => !m.error)) {'role': m.role, 'content': m.content},
        ],
      });
      final reply = (res is Map ? res['reply'] : null)?.toString();
      _add(_Msg('assistant', reply?.isNotEmpty == true ? reply! : 'I didn\'t get an answer back.'));
    } on ApiException catch (e) {
      _add(_Msg(
        'assistant',
        e.status == 404 ? 'The AI service isn\'t connected yet. Once the server enables $aiChatPath, I\'ll answer here.' : e.message,
        error: true,
      ));
    } catch (e) {
      _add(_Msg('assistant', 'Something went wrong: $e', error: true));
    }
  }

  void _add(_Msg m) {
    if (!mounted) return;
    setState(() {
      _messages.add(m);
      _thinking = false;
    });
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return Scaffold(
      backgroundColor: t.plane,
      appBar: AppBar(
        backgroundColor: t.plane,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: t.textPrimary, size: 30),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const AiOrb(size: 26, animate: false),
          const SizedBox(width: 10),
          Text('Ardent AI', style: TextStyle(fontWeight: FontWeight.w700, color: t.textPrimary)),
        ]),
        centerTitle: true,
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: t.textSecondary),
              tooltip: 'New chat',
              onPressed: () => setState(() => _messages.clear()),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _messages.isEmpty ? _welcome(t) : _chat(t),
            ),
          ),
          _composer(t),
        ]),
      ),
    );
  }

  Widget _welcome(BiTokens t) => ListView(
        key: const ValueKey('welcome'),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        children: [
          const Center(child: AiOrb(size: 96)),
          const SizedBox(height: 24),
          Text('How can I help?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: t.textPrimary)),
          const SizedBox(height: 6),
          Text('Ask about sales, inventory, or anything in your BI data.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: t.textMuted)),
          const SizedBox(height: 28),
          for (var i = 0; i < _suggestions.length; i++)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 350 + i * 90),
              curve: Curves.easeOutCubic,
              builder: (_, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _send(_suggestions[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(children: [
                        Icon(Icons.auto_awesome_outlined, size: 18, color: t.brand),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_suggestions[i], style: TextStyle(color: t.textPrimary, fontSize: 14))),
                        Icon(Icons.north_east_rounded, size: 16, color: t.textMuted),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );

  Widget _chat(BiTokens t) => ListView.builder(
        key: const ValueKey('chat'),
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: _messages.length + (_thinking ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _messages.length) return const _Typing();
          final m = _messages[i];
          final mine = m.role == 'user';
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(
              scale: 0.9 + 0.1 * v,
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Opacity(opacity: v.clamp(0, 1), child: child),
            ),
            child: Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
                decoration: BoxDecoration(
                  color: mine ? t.brand : (m.error ? t.brandSoft : t.surface),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 18),
                  ),
                ),
                child: SelectableText(m.content,
                    style: TextStyle(color: mine ? t.brandInk : t.textPrimary, fontSize: 14, height: 1.4)),
              ),
            ),
          );
        },
      );

  Widget _composer(BiTokens t) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Container(
          padding: const EdgeInsets.only(left: 16, right: 6),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: t.gridline),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: TextStyle(color: t.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ask Ardent AI…',
                  hintStyle: TextStyle(color: t.textMuted),
                  // Override the app-wide outlined field style; the pill is the border.
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _input,
              builder: (_, v, _) {
                final ready = v.text.trim().isNotEmpty && !_thinking;
                return AnimatedScale(
                  scale: ready ? 1 : 0.85,
                  duration: const Duration(milliseconds: 160),
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: ready ? t.brand : t.gridline,
                      foregroundColor: t.brandInk,
                    ),
                    onPressed: ready ? _send : null,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                );
              },
            ),
          ]),
        ),
      );
}

class _Typing extends StatefulWidget {
  const _Typing();
  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(18)),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.textMuted.withValues(
                      alpha: 0.35 + 0.65 * (0.5 + 0.5 * math.sin((_c.value - i * 0.18) * 2 * math.pi))),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Gradient orb with a slowly rotating sheen and breathing glow — the AI mark
/// used on the nav button and inside the assistant.
class AiOrb extends StatefulWidget {
  final double size;
  final bool animate;
  const AiOrb({super.key, required this.size, this.animate = true});
  @override
  State<AiOrb> createState() => _AiOrbState();
}

class _AiOrbState extends State<AiOrb> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final pulse = 0.5 + 0.5 * math.sin(_c.value * 2 * math.pi);
        return Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              transform: GradientRotation(_c.value * 2 * math.pi),
              colors: const [Color(0xFFE90408), Color(0xFFFF7A45), Color(0xFF8B5CF6), Color(0xFFE90408)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE90408).withValues(alpha: widget.animate ? 0.25 + 0.25 * pulse : 0.2),
                blurRadius: s * (0.25 + 0.2 * pulse),
                spreadRadius: s * 0.02,
              ),
            ],
          ),
          // Chat bubble with a spark inside — reads as "ask the assistant".
          child: Stack(alignment: Alignment.center, children: [
            Icon(Icons.chat_bubble_rounded, color: Colors.white, size: s * 0.5),
            Padding(
              padding: EdgeInsets.only(bottom: s * 0.04),
              child: Icon(Icons.auto_awesome, color: const Color(0xFFE90408), size: s * 0.24),
            ),
          ]),
        );
      },
    );
  }
}
