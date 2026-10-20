/// A personal access token for the WabWay MCP server (wabway-server `/mcp`).
/// Only the prefix is ever readable — the full token is shown once on create.
class AiAccessToken {
  const AiAccessToken({
    required this.id,
    required this.name,
    required this.prefix,
    required this.createdAt,
    this.lastUsedAt,
    this.canWrite = false,
  });

  final String id;
  final String name;
  final String prefix;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  /// True when the assistant may add and edit trip items, not just read them.
  final bool canWrite;
}
