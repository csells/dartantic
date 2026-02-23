import 'package:flutter_test/flutter_test.dart';
import 'package:dartantic_chat/src/helpers/paste_helper/paste_extensions.dart';

void main() {
  test('getExtensionFromMime returns expected extensions', () {
    expect(getExtensionFromMime('image/png'), 'png');
    expect(getExtensionFromMime('image/jpeg'), 'jpg');
    expect(getExtensionFromMime('application/pdf'), 'pdf');
    expect(getExtensionFromMime('application/octet-stream'), 'so');
  });
}
