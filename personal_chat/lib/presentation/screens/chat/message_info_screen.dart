import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/message_model.dart';
import '../../../core/theme/app_theme.dart';

class MessageInfoScreen extends StatelessWidget {
  final MessageModel message;
  final String decryptedContent;

  const MessageInfoScreen({
    super.key,
    required this.message,
    required this.decryptedContent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sent = message.timestamp;
    final delivered = message.deliveredAt;
    final read = message.readAt;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Info'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Message Preview
          Container(
            width: double.infinity,
            color: isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2),
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.sentMessageColorDark : AppTheme.sentMessageColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(0),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  message.type == MessageType.image ? '📷 Image' :
                  message.type == MessageType.audio ? '🎤 Voice Message' :
                  message.type == MessageType.document ? '📄 ${message.fileName ?? 'Document'}' :
                  decryptedContent,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Status rows
          _StatusRow(
            icon: Icons.check,
            iconColor: Colors.grey,
            label: 'Sent',
            time: _formatTime(sent),
          ),
          const Divider(height: 1, indent: 72),
          _StatusRow(
            icon: Icons.done_all,
            iconColor: delivered != null ? Colors.grey : Colors.grey[300]!,
            label: 'Delivered',
            time: delivered != null ? _formatTime(delivered) : '—',
          ),
          const Divider(height: 1, indent: 72),
          _StatusRow(
            icon: Icons.done_all,
            iconColor: read != null ? Colors.blue : Colors.grey[300]!,
            label: 'Read',
            time: read != null ? _formatTime(read) : '—',
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      DateFormat('MMM d, yyyy \'at\' h:mm a').format(dt);
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String time;

  const _StatusRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Text(time, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
    );
  }
}
