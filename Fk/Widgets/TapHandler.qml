import QtQuick

TapHandler {
  id: root

  // 禁止穿透
  grabPermissions: PointerHandler.TakeOverForbidden
  acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.NoButton
  gesturePolicy: TapHandler.WithinBounds
}
