import 'inbox_response.dart';

/// Lightweight quoted-message model used when a chat message is a reply.
///
/// Carries just enough of the original message — id, author, text, media —
/// to render the quoted preview above the reply in the inbox. The standalone
/// [Receiver] type is reused from `inbox_response.dart` for the sender.
class ReplyTo {
  /// Identifier of the original message being quoted.
  int? id;

  /// Identifier of the user who authored the original message.
  int? senderId;

  /// Text body of the original message, if any.
  String? text;

  /// Media attachment of the original message; loosely typed because the
  /// API may deliver it as a URL string or `null`.
  dynamic file;

  /// Media kind of the original attachment (e.g. `image`, `video`).
  String? mediaType;

  /// Author of the original message, used to label the quoted preview.
  Receiver? sender;

  /// Creates a [ReplyTo]; every field is optional since the API may omit any.
  ReplyTo({
    this.id,
    this.senderId,
    this.text,
    this.file,
    this.mediaType,
    this.sender,
  });

  /// Returns a copy of this [ReplyTo] with the given fields overridden;
  /// any argument left null keeps the current value.
  ReplyTo copyWith({
    int? id,
    int? senderId,
    String? text,
    dynamic file,
    String? mediaType,
    Receiver? sender,
  }) => ReplyTo(
    id: id ?? this.id,
    senderId: senderId ?? this.senderId,
    text: text ?? this.text,
    file: file ?? this.file,
    mediaType: mediaType ?? this.mediaType,
    sender: sender ?? this.sender,
  );

  /// Populates this [ReplyTo] from a decoded JSON [json] map, mapping the
  /// API's snake_case keys onto the model fields.
  ReplyTo.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    senderId = json['sender_id'];
    text = json['text'];
    file = json['file'];
    mediaType = json['media_type'];
    sender = json['sender'] != null ? Receiver.fromJson(json['sender']) : null;
  }

  /// Serializes this [ReplyTo] back to a snake_case JSON map for the API.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['sender_id'] = senderId;
    data['text'] = text;
    data['file'] = file;
    data['media_type'] = mediaType;
    if (sender != null) {
      data['sender'] = sender!.toJson();
    }
    return data;
  }
}
