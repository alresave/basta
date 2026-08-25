class Player {
  const Player({
    required this.id,
    required this.nickname,
    this.isHost = false,
    this.isConnected = true,
  });

  final String id;
  final String nickname;
  final bool isHost;
  final bool isConnected;

  Player copyWith({bool? isConnected}) => Player(
        id: id,
        nickname: nickname,
        isHost: isHost,
        isConnected: isConnected ?? this.isConnected,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'isHost': isHost,
        'isConnected': isConnected,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        isHost: json['isHost'] as bool? ?? false,
        isConnected: json['isConnected'] as bool? ?? true,
      );
}
