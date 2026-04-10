sealed class AlertType {}

class TextAlert extends AlertType {
  final String message;
  TextAlert(this.message);
}

class AudioAlert extends AlertType {
  final String fileName;
  final String base64Data;
  AudioAlert(this.fileName, this.base64Data);
}

class IncomingAlert {
  final int id = DateTime.now().millisecondsSinceEpoch;
  final AlertType type;
  final DateTime receivedAt = DateTime.now();

  IncomingAlert({required this.type});

  String get displayTitle {
    if (type is TextAlert) return 'Text Alert';
    if (type is AudioAlert) {
      return 'Audio Alert — ${(type as AudioAlert).fileName}';
    }
    return 'Alert';
  }
}
