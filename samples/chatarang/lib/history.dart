import 'package:dartantic_interface/dartantic_interface.dart';

class HistoryEntry {
  HistoryEntry({required this.message, required this.modelName});
  final ChatMessage message;
  final String modelName;
}
