import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Lightweight disk-backed image cache — pure Dart, zero native dependencies.
///
/// Images are stored in [Directory.systemTemp]/toyshop_img_cache/<sha-key>.
/// The cache is valid for the lifetime of the OS temp directory (survives
/// app restarts, cleared by the OS on low storage).
class DiskImageCache {
  DiskImageCache._();

  static Directory? _cacheDir;

  static Future<Directory> _dir() async {
    _cacheDir ??= Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}toyshop_img_cache',
    );
    if (!await _cacheDir!.exists()) await _cacheDir!.create(recursive: true);
    return _cacheDir!;
  }

  /// Returns a stable filename from the URL (avoids special chars).
  static String _key(String url) {
    // Simple hash: replace every non-alphanum char with '_'
    return url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').substring(
          url.length > 120 ? url.length - 120 : 0,
        );
  }

  /// Returns cached bytes if present, otherwise downloads, caches, and returns.
  static Future<Uint8List?> load(String url) async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}${Platform.pathSeparator}${_key(url)}');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 15),
          );
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }
}

/// A network image widget backed by [DiskImageCache].
/// Displays a shimmer while loading and the product icon on error —
/// exactly like the old `CachedNetworkImage` widget, but with zero
/// native dependencies (no sqflite / jni / CMake required).
class DiskCachedImage extends StatefulWidget {
  const DiskCachedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  State<DiskCachedImage> createState() => _DiskCachedImageState();
}

class _DiskCachedImageState extends State<DiskCachedImage> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = DiskImageCache.load(widget.url);
  }

  @override
  void didUpdateWidget(DiskCachedImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _future = DiskImageCache.load(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return widget.placeholder ?? const SizedBox.shrink();
        }
        if (snap.data == null) {
          return widget.errorWidget ?? const SizedBox.shrink();
        }
        return Image.memory(snap.data!, fit: widget.fit);
      },
    );
  }
}
