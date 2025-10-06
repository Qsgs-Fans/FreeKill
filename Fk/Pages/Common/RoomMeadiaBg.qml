import QtQuick
import QtMultimedia

Item {
  id: mediaViewer
  property url source: ""
  property int fillMode: Image.PreserveAspectFit

  anchors.fill: parent

  Image {
    id: imageItem
    anchors.fill: parent
    visible: mediaViewer.source.match(/\.(jpe?g|png)$/i)
    source: mediaViewer.source
    fillMode: mediaViewer.fillMode
  }

  AnimatedImage {
    id: gifItem
    anchors.fill: parent
    visible: mediaViewer.source.match(/\.gif$/i)
    source: mediaViewer.source
    fillMode: mediaViewer.fillMode
    playing: true
  }

  Video {
    id: videoItem
    anchors.fill: parent
    visible: mediaViewer.source.match(/\.(mp4|avi|mov|mkv)$/i)
    source: mediaViewer.source
    loops: MediaPlayer.Infinite
    fillMode: mediaViewer.fillMode
    muted: true

    Component.onCompleted: play()
  }
}
