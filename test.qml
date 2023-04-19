import QtQuick

Item {
  Component.onCompleted: {
    console.log(Qt.formatTime(new Date(0), "hh:mm:ss"))
  }
}
