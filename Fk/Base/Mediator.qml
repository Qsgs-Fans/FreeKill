pragma Singleton
import QtQuick

Item {
  id: root

  signal commandGot(variant sender, string command, variant data)

  Connections {
    target: Backend
    function onNotifyUI(command, data) {
      root.notify(null, command, data);
    }
  }

  function notify(sender, command, data) {
    commandGot(sender, command, data);
  }
}
