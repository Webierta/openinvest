import 'package:material_ui/material_ui.dart';

class UpdatingIndicator {
  static List<Widget> show() => [
    const ModalBarrier(dismissible: false, color: Colors.black54),
    Center(
      child: Transform.scale(
        scale: 2.5,
        child: CircularProgressIndicator(
          color: Colors.blueAccent,
          strokeWidth: 2,
        ),
      ),
    ),
  ];
}
