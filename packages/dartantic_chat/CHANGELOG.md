## 0.3.1

- Updated dependencies to current compatible releases, including
  `dartantic_ai` ^3.4.2 and `dartantic_interface` ^4.0.1.
- Split drag-and-drop handling into conditional native, web, and fallback
  implementations so web and WASM builds avoid native extension imports while
  preserving native drag-and-drop support.

## 0.3.0

- Requires `dartantic_interface` ^4.0.0 and `dartantic_ai` ^3.3.0 (stack aligned
  with `dartantic_interface` 4.0.0 and `ModelKind.video`). See those packages’
  changelogs if you switch exhaustively on `ModelKind`.

## 0.2.0

- Thanks for @DeTuksa for another great chat feature: drag 'n' drop!
  - Added drag-and-drop file attachment support on desktop and web platforms
  - Added `FileDropOverlayStyle` for customizing the drop zone visual feedback

- And another great @DeTuksa chat feature: custom commands!

## 0.1.0

- Initial fork from the Flutter AI Toolkit. Very minimal testing.
