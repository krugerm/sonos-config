import 'package:xml/xml.dart';

/// Parsed fields from a DIDL-Lite metadata blob (track title/artist/album/art).
class TrackMetadata {
  const TrackMetadata({this.title, this.artist, this.album, this.albumArtUri});

  final String? title;
  final String? artist;
  final String? album;

  /// Album-art path exactly as the speaker reported it. May be relative
  /// (`/getaa?...`) and must be resolved against the speaker host by the caller.
  final String? albumArtUri;

  static const empty = TrackMetadata();
}

/// Parses the escaped DIDL-Lite XML that Sonos returns inside
/// `TrackMetaData` / `CurrentURIMetaData`.
///
/// Returns [TrackMetadata.empty] for empty or unparseable input rather than
/// throwing, because these blobs are frequently absent between tracks.
TrackMetadata parseDidl(String? didl) {
  if (didl == null || didl.trim().isEmpty || didl.trim() == 'NOT_IMPLEMENTED') {
    return TrackMetadata.empty;
  }
  try {
    final doc = XmlDocument.parse(didl);
    final item = doc.findAllElements('item').firstOrNull;
    if (item == null) return TrackMetadata.empty;

    String? textOf(String local) {
      final el = item
          .descendantElements
          .where((e) => e.localName == local)
          .firstOrNull;
      final value = el?.innerText.trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    return TrackMetadata(
      title: textOf('title'),
      artist: textOf('creator') ?? textOf('artist'),
      album: textOf('album'),
      albumArtUri: textOf('albumArtURI'),
    );
  } catch (_) {
    return TrackMetadata.empty;
  }
}

/// Resolves an album-art path against a speaker host into an absolute URL.
String? resolveAlbumArt(String? artPath, String host) {
  if (artPath == null || artPath.isEmpty) return null;
  if (artPath.startsWith('http')) return artPath;
  final path = artPath.startsWith('/') ? artPath : '/$artPath';
  return 'http://$host:1400$path';
}
