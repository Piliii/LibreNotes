import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:librenotes/image_prep.dart';

void main() {
  test('big photos shrink to 2048px and lose their EXIF (GPS)', () async {
    final photo = img.Image(width: 3000, height: 1500);
    photo.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(48, 1);
    photo.exif.imageIfd['Model'] = img.IfdValueAscii('SecretCam');
    final raw = img.encodeJpg(photo);
    expect(img.decodeJpg(raw)!.exif.isEmpty, isFalse, reason: 'fixture has EXIF');

    final out = await prepareImage(raw);
    expect(out.ext, 'jpg');
    final back = img.decodeJpg(out.bytes)!;
    expect(back.width, 2048);
    expect(back.height, 1024);
    expect(back.exif.gpsIfd.isEmpty, isTrue);
    expect(back.exif.imageIfd['Model'], isNull);
  });

  test('transparent images stay PNG; small ones keep their size', () async {
    final logo = img.Image(width: 40, height: 20, numChannels: 4);
    final out = await prepareImage(img.encodePng(logo));
    expect(out.ext, 'png');
    expect(img.decodePng(out.bytes)!.width, 40);
  });

  test('GIFs pass through untouched (animation survives)', () async {
    final gif = img.encodeGif(img.Image(width: 4, height: 4));
    final out = await prepareImage(gif);
    expect(out.ext, 'gif');
    expect(out.bytes, gif);
  });

  test('non-images are refused', () async {
    await expectLater(prepareImage(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<ImagePrepException>()));
  });

  test('a corrupt file with an image header is refused, not crashed on',
      () async {
    final fake = Uint8List.fromList(
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ...List.filled(64, 7)]);
    await expectLater(prepareImage(fake), throwsA(isA<ImagePrepException>()));
  });
}
