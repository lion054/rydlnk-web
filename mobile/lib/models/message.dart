/// A single chat message on a trip's group thread.
class Message {
  Message({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        tripId: j['trip_id'] as String,
        senderId: j['sender_id'] as String,
        body: j['body'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  bool isMine(String? myId) => senderId == myId;
}
