import 'inbox_response.dart';

class ReplyTo {
  int? id;
  int? senderId;
  String? text;
  dynamic file;
  String? mediaType;
  Receiver? sender;

  ReplyTo({
    this.id,
    this.senderId,
    this.text,
    this.file,
    this.mediaType,
    this.sender,
  });

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

  ReplyTo.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    senderId = json['sender_id'];
    text = json['text'];
    file = json['file'];
    mediaType = json['media_type'];
    sender = json['sender'] != null ? Receiver.fromJson(json['sender']) : null;
  }

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
