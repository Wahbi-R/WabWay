import '../../data/ai_access_data.dart';
import 'client.dart';

const _kServerUrl = String.fromEnvironment('AUDIO_SERVER_URL', defaultValue: '');

abstract final class AiAccessService {
  /// MCP endpoint AI assistants connect to, or '' if the build has no server URL.
  static String get mcpUrl {
    if (_kServerUrl.isEmpty) return '';
    final base = _kServerUrl.endsWith('/')
        ? _kServerUrl.substring(0, _kServerUrl.length - 1)
        : _kServerUrl;
    return '$base/mcp';
  }

  static AiAccessToken _fromRow(Map<String, dynamic> r) => AiAccessToken(
        id:         r['id'] as String,
        name:       r['name'] as String,
        prefix:     r['token_prefix'] as String,
        createdAt:  DateTime.parse(r['created_at'] as String).toLocal(),
        lastUsedAt: r['last_used_at'] != null
            ? DateTime.parse(r['last_used_at'] as String).toLocal()
            : null,
        canWrite:   r['can_write'] as bool? ?? false,
      );

  /// Your active (non-revoked) tokens, newest first.
  static Future<List<AiAccessToken>> load() async {
    final data = await supabase
        .from('ai_access_tokens')
        .select('id, name, token_prefix, created_at, last_used_at, can_write')
        .isFilter('revoked_at', null)
        .order('created_at', ascending: false);
    return data.map(_fromRow).toList();
  }

  /// Creates a token and returns its plaintext — the only time it's readable.
  /// [canWrite] lets the assistant add and edit, not just read.
  static Future<String> create(String name, {bool canWrite = false}) async {
    final token = await supabase.rpc(
      'create_ai_access_token',
      params: {'p_name': name, 'p_can_write': canWrite},
    );
    return token as String;
  }

  /// Revokes a token; the server stops accepting it within a minute.
  static Future<void> revoke(String id) async {
    await supabase
        .from('ai_access_tokens')
        .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
