import 'package:flutter/foundation.dart';
import '../../data/share_data.dart';

class ShareHandler extends ChangeNotifier {
  ShareHandler._();
  static final instance = ShareHandler._();

  IncomingShare? get pending => null;

  Future<void> init() async {}

  void consume() {}
}
