import 'package:xml/xml.dart';

import '../models/media_item.dart';

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

/// Parses a ContentDirectory `Browse` result (escaped DIDL-Lite) into a list of
/// [MediaItem]s — used for Sonos favorites and the play queue.
///
/// Favorites keep the *playable* URI in `<res>` and the metadata that must be
/// passed back to `SetAVTransportURI` in `<r:resMD>` (itself escaped DIDL).
List<MediaItem> parseMediaItems(String? didl, String host) {
  if (didl == null || didl.trim().isEmpty) return const [];
  try {
    final doc = XmlDocument.parse(didl);
    final items = <MediaItem>[];
    for (final el in doc.findAllElements('item')) {
      String? textOf(String local) {
        final v = el.descendantElements
            .where((e) => e.localName == local)
            .firstOrNull
            ?.innerText
            .trim();
        return (v == null || v.isEmpty) ? null : v;
      }

      final title = textOf('title') ?? 'Untitled';
      final res = textOf('res');
      // Favorites embed the real item metadata in r:resMD; fall back to the
      // item's own serialized DIDL so SetAVTransportURI still has something.
      final resMd = el.descendantElements
          .where((e) => e.localName == 'resMD')
          .firstOrNull
          ?.innerText;
      final metadata =
          (resMd != null && resMd.trim().isNotEmpty) ? resMd : _wrapItem(el);

      items.add(MediaItem(
        id: el.getAttribute('id') ?? title,
        title: title,
        subtitle: textOf('description') ??
            [textOf('creator') ?? textOf('artist'), textOf('album')]
                .where((s) => s != null && s.isNotEmpty)
                .join(' • '),
        uri: res,
        metadata: metadata,
        albumArtUri: resolveAlbumArt(textOf('albumArtURI'), host),
      ));
    }
    return items;
  } catch (_) {
    return const [];
  }
}

/// Serializes a single `<item>` back into a standalone DIDL-Lite document so it
/// can be used as `CurrentURIMetaData` when no `r:resMD` is present.
String _wrapItem(XmlElement item) {
  const header = '<DIDL-Lite '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" '
      'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" '
      'xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" '
      'xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">';
  return '$header${item.toXmlString()}</DIDL-Lite>';
}

/// Resolves an album-art path against a speaker host into an absolute URL.
String? resolveAlbumArt(String? artPath, String host) {
  if (artPath == null || artPath.isEmpty) return null;
  if (artPath.startsWith('http')) return artPath;
  final path = artPath.startsWith('/') ? artPath : '/$artPath';
  return 'http://$host:1400$path';
}
