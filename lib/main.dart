import 'package:flutter/material.dart';

import 'app.dart';
import 'engine/transfer_engine.dart';

void main() {
  runApp(const IsekaiDropApp(engine: Phase1EngineStub()));
}
