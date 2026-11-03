import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../domain/receipt_store.dart';

class LocalReceiptStore implements ReceiptStore {
  const LocalReceiptStore({this.directory});
  final Future<Directory> Function()? directory;
  @override
  Future<String?> retain(String? pickedPath) async {
    if (pickedPath == null || pickedPath.trim().isEmpty) return null;
    final source = File(pickedPath);
    // Preserve older missing references; the viewer supplies a recovery state.
    if (!await source.exists()) return pickedPath;
    final parent =
        await (directory?.call() ?? getApplicationDocumentsDirectory());
    final root = Directory('${parent.path}${Platform.pathSeparator}receipts');
    await root.create(recursive: true);
    if (source.absolute.path.toLowerCase().startsWith(
        '${root.absolute.path.toLowerCase()}${Platform.pathSeparator}')) {
      return source.path;
    }
    final raw = pickedPath.split('.').last.toLowerCase();
    final ext = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif', 'bmp']
            .contains(raw)
        ? raw
        : 'jpg';
    return (await source.copy(
            '${root.path}${Platform.pathSeparator}${const Uuid().v4()}.$ext'))
        .path;
  }
}
