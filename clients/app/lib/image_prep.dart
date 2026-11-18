import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Largest image stored after shrinking. The server accepts a bit more to
/// leave room for the nonce and auth tag.
const maxImageBytes = 10 * 1024 * 1024;

/// Longest side, in pixels, after shrinking.
const maxImageSide = 2048;

/// An image ready to encrypt and store: its bytes and file extension.
typedef PreparedImage = ({Uint8List bytes, String ext});

/// Why [prepareImage] refused an image.
class ImagePrepException implements Exception {
  ImagePrepException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Shrinks and cleans an image before it's stored, off the UI thread.
///
/// Every image except a GIF is decoded and re-encoded, even small ones, so
/// metadata (EXIF GPS location, camera serial, PNG text) never leaves the
/// device. EXIF rotation is applied first so the picture still shows the
/// right way up. Images with transparency stay PNG, everything else becomes
/// JPEG (quality 85). GIFs are kept as they are so animations survive.
Future<PreparedImage> prepareImage(Uint8List raw) async {
  final out = await compute(_prepare, raw);
  if (out == null) {
    throw ImagePrepException("This file isn't an image LibreNotes can read.");
  }
  if (out.bytes.length > maxImageBytes) {
    throw ImagePrepException('Image is over 10 MB even after shrinking.');
  }
  return out;
}

PreparedImage? _prepare(Uint8List raw) {
  final format = img.findFormatForData(raw);
  if (format == img.ImageFormat.gif) return (bytes: raw, ext: 'gif');
  if (format == img.ImageFormat.invalid) return null;
  var image = img.decodeImage(raw);
  if (image == null) return null;
  image = img.bakeOrientation(image);
  if (image.width > maxImageSide || image.height > maxImageSide) {
    image = image.width >= image.height
        ? img.copyResize(image,
            width: maxImageSide, interpolation: img.Interpolation.average)
        : img.copyResize(image,
            height: maxImageSide, interpolation: img.Interpolation.average);
  }
  // Drop every piece of metadata the encoders would otherwise write back.
  image.exif = img.ExifData();
  image.textData = null;
  if (image.hasAlpha) {
    return (bytes: img.encodePng(image), ext: 'png');
  }
  return (bytes: img.encodeJpg(image, quality: 85), ext: 'jpg');
}
