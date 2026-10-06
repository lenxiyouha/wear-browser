import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum DownloadStatus { running, done, failed, canceled }

class DownloadTask {
  final int id;
  final String url;
  final String fileName;
  int totalBytes;
  int receivedBytes;
  DownloadStatus status;
  final CancelToken _token = CancelToken();
  String? error;

  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    this.totalBytes = 0,
    this.receivedBytes = 0,
    this.status = DownloadStatus.running,
  });

  double? get progress {
    if (totalBytes <= 0) return null;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  String get sizeText {
    String fmt(int b) {
      if (b >= 1048576) return '${(b / 1048576).toStringAsFixed(1)} MB';
      if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
      return '$b B';
    }

    if (totalBytes > 0) return '${fmt(receivedBytes)} / ${fmt(totalBytes)}';
    return fmt(receivedBytes);
  }
}

/// 下载管理器：单例，流式写盘 + 进度 + 取消。
/// 文件保存到 `/storage/emulated/0/Android/data/<pkg>/files/Download/`（免权限）
class DownloadService extends ChangeNotifier {
  static final DownloadService instance = DownloadService._();
  DownloadService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(hours: 2),
  ));

  final List<DownloadTask> tasks = [];
  int _nextId = 1;
  Directory? _dir;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  Future<Directory> directory() async {
    if (_dir != null) return _dir!;
    final base = await getExternalStorageDirectory();
    final dir = Directory('${base?.path ?? ''}/Download');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  Future<String> directoryPath() async => (await directory()).path;

  int get activeCount =>
      tasks.where((t) => t.status == DownloadStatus.running).length;

  void _throttledNotify({bool force = false}) {
    final now = DateTime.now();
    if (force || now.difference(_lastNotify).inMilliseconds > 250) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  static String _sanitize(String name) {
    var n = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
    if (n.startsWith('.') || n.isEmpty) n = 'download_$n';
    if (n.length > 120) {
      final i = n.lastIndexOf('.');
      n = i > 0 && n.length - i < 12
          ? '${n.substring(0, 116)}${n.substring(i)}'
          : n.substring(0, 120);
    }
    return n;
  }

  Future<String> _uniquePath(Directory dir, String name) async {
    var candidate = name;
    var stem = name;
    var ext = '';
    final i = name.lastIndexOf('.');
    if (i > 0) {
      stem = name.substring(0, i);
      ext = name.substring(i);
    }
    var n = 1;
    while (await File('${dir.path}/$candidate').exists()) {
      candidate = '$stem($n)$ext';
      n++;
    }
    return '${dir.path}/$candidate';
  }

  /// 发起下载（由 WebView 的 onDownloadStartRequest 调用）
  Future<void> start({
    required String url,
    String? fileName,
    String? userAgent,
    int totalBytes = 0,
  }) async {
    final dir = await directory();
    String name;
    if (fileName != null && fileName.trim().isNotEmpty) {
      name = _sanitize(fileName.trim());
    } else {
      final path = Uri.tryParse(url)?.pathSegments ?? [];
      final last = path.isNotEmpty ? path.last : '';
      name = last.isNotEmpty
          ? _sanitize(last)
          : 'download_${DateTime.now().millisecondsSinceEpoch}';
    }
    final savePath = await _uniquePath(dir, name);

    final task = DownloadTask(
      id: _nextId++,
      url: url,
      fileName: savePath.substring(savePath.lastIndexOf('/') + 1),
      totalBytes: totalBytes,
    );
    tasks.insert(0, task);
    _throttledNotify(force: true);

    try {
      await _dio.download(
        url,
        savePath,
        cancelToken: task._token,
        deleteOnError: true,
        options: Options(headers: {
          if (userAgent != null && userAgent.isNotEmpty)
            'User-Agent': userAgent,
          'Accept': '*/*',
        }),
        onReceiveProgress: (recv, total) {
          task.receivedBytes = recv;
          if (total > 0 && task.totalBytes != total) {
            task.totalBytes = total;
          }
          _throttledNotify();
        },
      );
      task.status = DownloadStatus.done;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        task.status = DownloadStatus.canceled;
        // 删除半截文件
        try {
          final f = File(savePath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      } else {
        task.status = DownloadStatus.failed;
        task.error = e.message;
      }
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = e.toString();
    }
    _throttledNotify(force: true);
  }

  void cancel(int id) {
    final t = tasks.where((t) => t.id == id).firstOrNull;
    if (t != null && t.status == DownloadStatus.running) {
      t._token.cancel('用户取消');
      _throttledNotify(force: true);
    }
  }

  void retry(int id) {
    final t = tasks.where((t) => t.id == id).firstOrNull;
    if (t == null) return;
    final old = t;
    tasks.remove(old);
    start(url: old.url, fileName: old.fileName, totalBytes: old.totalBytes);
  }

  /// 移除任务记录；已完成的顺带删除文件
  Future<void> remove(int id) async {
    final t = tasks.where((t) => t.id == id).firstOrNull;
    if (t == null) return;
    if (t.status == DownloadStatus.running) {
      t._token.cancel('移除');
    }
    if (t.status == DownloadStatus.done) {
      try {
        final f = File('${(await directory()).path}/${t.fileName}');
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    tasks.remove(t);
    _throttledNotify(force: true);
  }

  Future<void> clearFinished() async {
    final dir = await directory();
    for (final t in tasks.toList()) {
      if (t.status == DownloadStatus.done) {
        try {
          final f = File('${dir.path}/${t.fileName}');
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      if (t.status != DownloadStatus.running) tasks.remove(t);
    }
    _throttledNotify(force: true);
  }
}
