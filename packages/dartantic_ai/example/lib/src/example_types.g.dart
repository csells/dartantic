// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'example_types.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TownAndCountry _$TownAndCountryFromJson(Map<String, dynamic> json) =>
    TownAndCountry(
      town: json['town'] as String,
      country: json['country'] as String,
    );

Map<String, dynamic> _$TownAndCountryToJson(TownAndCountry instance) =>
    <String, dynamic>{'town': instance.town, 'country': instance.country};

const _$TownAndCountryJsonSchema = {
  r'$schema': 'https://json-schema.org/draft/2020-12/schema',
  'type': 'object',
  'properties': {
    'town': {'type': 'string'},
    'country': {'type': 'string'},
  },
  'required': ['town', 'country'],
};
