import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';

class SeshAgent extends StatefulWidget {
  final bool enabled;

  const SeshAgent({super.key, this.enabled = true});

  @override
  State<SeshAgent> createState() => _SeshAgentState();
}

class _SeshAgentState extends State<SeshAgent>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF1B4748);

  bool _open = false;
  bool _thinking = false;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'content':
          "Hi! I'm Bizby, your BizShare assistant. How can I help you today?",
    },
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggleOpen() {
    setState(() => _open = !_open);
    if (_open) {
      _animCtrl.forward();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } else {
      _animCtrl.reverse();
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add({
        'role': 'assistant',
        'content':
            "Hi! I'm Bizby, your BizShare assistant. How can I help you today?",
      });
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _thinking) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _inputCtrl.clear();
      _thinking = true;
    });
    _scrollToBottom();

    final auth = context.read<AuthProvider>();
    try {
      final recent = _messages.length > 10
          ? _messages.sublist(_messages.length - 10)
          : List<Map<String, String>>.from(_messages);

      final res = await auth.apiService.dio.post(
        '/api/v1/agent/c/',
        data: {
          'message': text,
          'messages': recent
              .map((m) => {'role': m['role'], 'content': m['content']})
              .toList(),
        },
      );
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': res.data['message']?.toString() ?? 'No response.',
        });
      });
    } on DioException catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': e.response?.data?['error']?.toString() ??
              'Something went wrong. Please try again.',
        });
      });
    } catch (_) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Something went wrong. Please try again.',
        });
      });
    } finally {
      if (mounted) setState(() => _thinking = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    return Positioned(
      bottom: 20,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Chat window
          if (_open) _chatWindow(),
          const SizedBox(height: 10),
          // Floating button
          GestureDetector(
            onTap: _toggleOpen,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _open
                    ? const Icon(Icons.close, color: Colors.white, size: 24)
                    : const Icon(Icons.smart_toy_outlined,
                        color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatWindow() {
    return ScaleTransition(
      scale: _scaleAnim,
      alignment: Alignment.bottomRight,
      child: Container(
        width: 320,
        height: 460,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _header(),
            Expanded(child: _messageList()),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bizby',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              Text('BizShare Assistant',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _clearChat,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.refresh, color: Colors.white70, size: 18),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _toggleOpen,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, color: Colors.white70, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(10),
      itemCount: _messages.length + (_thinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (_thinking && index == _messages.length) {
          return _thinkingBubble();
        }
        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        return _messageBubble(msg['content'] ?? '', isUser);
      },
    );
  }

  Widget _messageBubble(String content, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isUser ? Colors.grey[200] : _green,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isUser ? 12 : 2),
              bottomRight: Radius.circular(isUser ? 2 : 12),
            ),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: isUser ? Colors.black87 : Colors.white,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _thinkingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _green,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
              bottomLeft: Radius.circular(2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dot(0),
              const SizedBox(width: 4),
              _dot(150),
              const SizedBox(width: 4),
              _dot(300),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (_, val, __) => Opacity(
        opacity: val,
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.white70,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              focusNode: _focusNode,
              maxLength: 500,
              maxLines: 1,
              enabled: !_thinking,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  const SizedBox.shrink(),
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Ask me anything...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: _green),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _thinking ? null : _sendMessage,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _thinking ? Colors.grey[300] : _green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
