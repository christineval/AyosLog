abstract interface class ReceiptStore {
  Future<String?> retain(String? pickedPath);
}
