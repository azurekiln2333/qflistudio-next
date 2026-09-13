/// 社区数据模型（与 azurekiln-qfli-server 的 JSON 契约对应）。
class CommunityUser {
  const CommunityUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.bio,
    required this.avatarColor,
    required this.points,
    required this.checkinStreak,
    required this.provider,
    this.isAdmin = false,
  });

  final int id;
  final bool isAdmin;
  final String username;
  final String nickname;
  final String bio;
  final String avatarColor;
  final int points;
  final int checkinStreak;
  final String provider;

  static CommunityUser fromJson(Map<String, dynamic> j) => CommunityUser(
        id: (j['id'] as num).toInt(),
        username: j['username'] as String? ?? '',
        nickname: j['nickname'] as String? ?? '',
        bio: j['bio'] as String? ?? '',
        avatarColor: j['avatarColor'] as String? ?? '#2196F3',
        points: (j['points'] as num?)?.toInt() ?? 0,
        checkinStreak: (j['checkinStreak'] as num?)?.toInt() ?? 0,
        provider: j['provider'] as String? ?? 'local',
        isAdmin: j['isAdmin'] as bool? ?? false,
      );
}

class Zone {
  const Zone({required this.id, required this.key, required this.name});

  final int id;
  final String key;
  final String name;

  static Zone fromJson(Map<String, dynamic> j) => Zone(
        id: (j['id'] as num).toInt(),
        key: j['key'] as String,
        name: j['name'] as String,
      );
}

class PostAuthor {
  const PostAuthor({
    required this.id,
    required this.nickname,
    required this.username,
    required this.avatarColor,
  });

  final int id;
  final String nickname;
  final String username;
  final String avatarColor;

  static PostAuthor fromJson(Map<String, dynamic> j) => PostAuthor(
        id: (j['id'] as num).toInt(),
        nickname: j['nickname'] as String? ?? '',
        username: j['username'] as String? ?? '',
        avatarColor: j['avatarColor'] as String? ?? '#2196F3',
      );
}

class Post {
  const Post({
    required this.id,
    required this.type,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.tags,
    required this.zoneId,
    required this.zoneName,
    required this.author,
    required this.likeCount,
    required this.commentCount,
    required this.liked,
    required this.createdAt,
  });

  final int id;
  final String type; // tutorial | discussion
  final String title;
  final String excerpt;
  final String content;
  final List<String> tags;
  final int zoneId;
  final String zoneName;
  final PostAuthor author;
  final int likeCount;
  final int commentCount;
  final bool liked;
  final String createdAt;

  static Post fromJson(Map<String, dynamic> j) => Post(
        id: (j['id'] as num).toInt(),
        type: j['type'] as String,
        title: j['title'] as String? ?? '',
        excerpt: j['excerpt'] as String? ?? '',
        content: j['content'] as String? ?? j['excerpt'] as String? ?? '',
        tags: [
          for (final t in (j['tags'] as List? ?? [])) t as String,
        ],
        zoneId: (j['zoneId'] as num?)?.toInt() ?? 0,
        zoneName: j['zoneName'] as String? ?? '',
        author: PostAuthor.fromJson(j['author'] as Map<String, dynamic>),
        likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
        commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
        liked: j['liked'] as bool? ?? false,
        createdAt: j['createdAt'] as String? ?? '',
      );
}

class Comment {
  const Comment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.parentId,
    required this.author,
    required this.children,
  });

  final int id;
  final String content;
  final String createdAt;
  final int? parentId;
  final PostAuthor author;
  final List<Comment> children;

  static Comment fromJson(Map<String, dynamic> j) => Comment(
        id: (j['id'] as num).toInt(),
        content: j['content'] as String? ?? '',
        createdAt: j['createdAt'] as String? ?? '',
        parentId: j['parentId'] == null
            ? null
            : (j['parentId'] as num).toInt(),
        author: PostAuthor.fromJson(j['author'] as Map<String, dynamic>),
        children: [
          for (final c in (j['children'] as List? ?? []))
            Comment.fromJson(c as Map<String, dynamic>),
        ],
      );
}

class TaskInfo {
  const TaskInfo({
    required this.key,
    required this.label,
    required this.done,
    required this.reward,
  });

  final String key;
  final String label;
  final bool done;
  final int reward;

  static TaskInfo fromJson(Map<String, dynamic> j) => TaskInfo(
        key: j['key'] as String,
        label: j['label'] as String,
        done: j['done'] as bool? ?? false,
        reward: (j['reward'] as num?)?.toInt() ?? 0,
      );
}

class TagCount {
  const TagCount({required this.tag, required this.count});

  final String tag;
  final int count;

  static TagCount fromJson(Map<String, dynamic> j) => TagCount(
        tag: j['tag'] as String,
        count: (j['count'] as num).toInt(),
      );
}
