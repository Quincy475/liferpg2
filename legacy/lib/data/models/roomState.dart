class RoomState {
  final String background;
  final String? activeFurnitureId;

  RoomState({
    required this.background,
    this.activeFurnitureId,
  });

  factory RoomState.fromJson(Map<String, dynamic> json) {
    return RoomState(
      background: json['background'] as String,
      activeFurnitureId: json['activeFurnitureId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'background': background,
      if (activeFurnitureId != null) 'activeFurnitureId': activeFurnitureId,
    };
  }
}