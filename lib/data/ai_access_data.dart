/// A personal access token for the WabWay MCP server (wabway-server `/mcp`).
/// Only the prefix is ever readable — the full token is shown once on create.
class AiAccessToken {
  const AiAccessToken({
    required this.id,
    required this.name,
    required this.prefix,
    required this.createdAt,
    this.lastUsedAt,
  });

  final String id;
  final String name;
  final String prefix;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
}
