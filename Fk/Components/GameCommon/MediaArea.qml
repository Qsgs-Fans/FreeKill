import QtQuick
import QtMultimedia

Item {
  id: root
  property string source: ""
  property bool hasDeputy: false //是否使用dual这个功能还是相信后人智慧吧
  property int fillMode: Image.PreserveAspectCrop
  property bool pause: true

  Loader {
    id: imgLoader
    anchors.fill: parent
    sourceComponent: {
      if (root.source.endsWith(".gif")) {
        return animated;
      } else if (root.source.endsWith(".mp4" || root.source.endsWith(".avi") || root.source.endsWith(".mov") || root.source.endsWith(".mkv"))) {
        return videoImg;
      } else {
        return staticImg;
      }
    }
  }

  Component {
    id: staticImg
    Image {
      anchors.fill: parent
      fillMode: root.fillMode
      source: root.source
    }
  }

  Component {
    id: animated
    AnimatedImage {
      anchors.fill: parent
      fillMode: root.fillMode
      source: root.source
      playing: true
    }
  }

  Component {
    id: videoImg
    Video {
      anchors.fill: parent
      source: root.source
      loops: MediaPlayer.Infinite
      fillMode: root.fillMode
      muted: true

      // 媒体时长就绪后跳到第一帧并暂停，只显示封面帧
      onDurationChanged: {
        if (duration > 0 && root.pause) {
          seek(0);
          pause();
        } else {
          play();
        }
      }
    }
  }
}
