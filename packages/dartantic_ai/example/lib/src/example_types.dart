import 'package:chrono_dart/chrono_dart.dart' show Chrono;
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:freezed_annotation/freezed_annotation.dart' show Freezed;
import 'package:json_annotation/json_annotation.dart';

part 'example_types.g.dart';

@Freezed()
@JsonSerializable(createJsonSchema: true)
class TownAndCountry {
  const TownAndCountry({required this.town, required this.country});

  factory TownAndCountry.fromJson(Map<String, dynamic> json) =>
      _$TownAndCountryFromJson(json);

  final String town;
  final String country;

  static const schemaMap = _$TownAndCountryJsonSchema;
}

class TimeAndTemperature {
  const TimeAndTemperature({required this.time, required this.temperature});

  factory TimeAndTemperature.fromJson(Map<String, dynamic> json) =>
      TimeAndTemperature(
        time: Chrono.parseDate(json['time']) ?? DateTime(1970, 1, 1),
        temperature: (json['temperature'] as num).toDouble(),
      );

  static final schema = Schema.fromMap({
    'type': 'object',
    'properties': {
      'time': {'type': 'string'},
      'temperature': {'type': 'number'},
    },
    'required': ['time', 'temperature'],
  });

  final DateTime time;
  final double temperature;
}
