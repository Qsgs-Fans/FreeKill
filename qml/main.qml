import QtQuick 2.0
import QtQuick.Controls 2.0
import QtQuick.Window 2.0

Window
{
    visible: true
    width: 300
    height: 240

    Column {
        TextField {
            text: "127.0.0.1"
        }
        TextField {
            text: "player"
        }
        Button {
            text: "Join Server"
        }
        TextField {
            text: "9527"
        }
        Button {
            text: "Start Server"
        }
    }
}
