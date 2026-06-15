// Coarse bucketing helpers so analytics carries size/kind metadata without ever
// emitting an exact byte count (which could fingerprint a specific file).

/// Maps a payload size in [bytes] to the catalog `size_bucket` enum.
///
/// `xs` (<256 KB), `sm` (<1 MB), `md` (<5 MB), `lg` (<20 MB), `xl` (≥20 MB).
String sizeBucket(int bytes) {
  if (bytes < 256 * 1024) return 'xs';
  if (bytes < 1024 * 1024) return 'sm';
  if (bytes < 5 * 1024 * 1024) return 'md';
  if (bytes < 20 * 1024 * 1024) return 'lg';
  return 'xl';
}

/// Maps a file [path]'s extension to the catalog `media_kind` enum
/// (`image` | `video`), or null when it is neither.
String? mediaKindFromPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return null;
  final ext = path.substring(dot + 1).toLowerCase();
  const video = {'mp4', 'mov', 'avi', 'mkv', 'webm', '3gp', 'm4v', 'mpeg'};
  const image = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif'};
  if (video.contains(ext)) return 'video';
  if (image.contains(ext)) return 'image';
  return null;
}
