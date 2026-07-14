import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../helpers/toast.dart';
import '../../../networks/api_access.dart';
import '../model/chat_list_response.dart';

/// Screen for picking one or more conversations (1:1 chats and/or groups) to
/// forward a message to.
///
/// Opened from the message action menu with the source message's id and type.
/// Reuses the shared chat-list stream ([getAllChatRx]) for the selectable list;
/// confirming calls [forwardMessageRx] to fan the message out, then pops.
class ForwardPickerScreen extends StatefulWidget {
  /// Creates the picker for the given source message.
  ///
  /// [sourceMessageId] is the message being forwarded; [sourceType] is where
  /// it lives — `single` (a 1:1 chat) or `group`.
  const ForwardPickerScreen({
    super.key,
    required this.sourceMessageId,
    required this.sourceType,
  });

  /// Id of the message being forwarded.
  final int sourceMessageId;

  /// Origin of the source message: `single` or `group`.
  final String sourceType;

  @override
  State<ForwardPickerScreen> createState() => _ForwardPickerScreenState();
}

/// State for [ForwardPickerScreen]; tracks the selected recipients and drives
/// the forward call.
class _ForwardPickerScreenState extends State<ForwardPickerScreen> {
  /// Selected recipients keyed by "type-id", value is the `{type, id}` payload.
  final Map<String, Map<String, dynamic>> _selected = {};

  /// True while the forward request is in flight (disables the send button).
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Refresh the list so the picker is not empty on a cold open.
    getAllChatRx.getAllChat();
  }

  /// The recipient `{type, id}` for a chat-list [row]. A group row forwards to
  /// the group; anything else forwards to the 1:1 peer.
  Map<String, dynamic> _recipientFor(Chat row) => {
    'type': row.type == 'group' ? 'group' : 'single',
    'id': row.id,
  };

  /// Stable selection key for [row].
  String _keyFor(Chat row) => '${row.type}-${row.id}';

  /// Toggles [row]'s membership in the selection.
  void _toggle(Chat row) {
    if (row.id == null) return;
    setState(() {
      final key = _keyFor(row);
      if (_selected.containsKey(key)) {
        _selected.remove(key);
      } else {
        _selected[key] = _recipientFor(row);
      }
    });
  }

  /// Sends the forward to every selected recipient, then pops on success.
  Future<void> _send() async {
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);

    final ok = await forwardMessageRx.forwardMessage(
      messageId: widget.sourceMessageId,
      sourceType: widget.sourceType,
      recipients: _selected.values.toList(),
    );

    if (!mounted) return;
    if (ok) {
      ToastUtil.showSuccessMessage("Forwarded");
      Navigator.of(context).pop();
    } else {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forward to")),
      body: StreamBuilder(
        stream: getAllChatRx.getChatStream,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data is! ChatListResponse) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = data.data?.chats ?? [];
          if (chats.isEmpty) {
            return const Center(child: Text("No conversations to forward to"));
          }
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final row = chats[index];
              final selected = _selected.containsKey(_keyFor(row));
              return CheckboxListTile(
                value: selected,
                onChanged: (_) => _toggle(row),
                secondary: CircleAvatar(
                  radius: 20.r,
                  backgroundImage:
                      (row.avatar != null && row.avatar!.isNotEmpty)
                          ? NetworkImage(row.avatar!)
                          : null,
                  child:
                      (row.avatar == null || row.avatar!.isEmpty)
                          ? Text((row.name ?? "?").characters.first)
                          : null,
                ),
                title: Text(row.name ?? ""),
                subtitle: row.type == 'group' ? const Text("Group") : null,
              );
            },
          );
        },
      ),
      floatingActionButton:
          _selected.isEmpty
              ? null
              : FloatingActionButton.extended(
                onPressed: _sending ? null : _send,
                icon:
                    _sending
                        ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.send_rounded),
                label: Text("Send (${_selected.length})"),
              ),
    );
  }
}
