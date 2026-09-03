import QtQuick
import QtMultimedia
import Spine

import Fk

import LunarLtk

pragma ComponentBehavior: Bound

Item {
  id: root
  property string general: ""
  property string skinName: ""
  property bool enabledShown: false
  readonly property bool isSkeleton: Ltk.isSkeletonSkin(general, skinName)
  readonly property string source:  {
    if (general && !skinName) return SkinBank.getGeneralPicture(general);
    return Ltk.getFullSkinPath(general, skinName);
  }
  readonly property var skelData: {
    const data = Ltk.getSkeletonSkinData(general, skinName)
    if (!data) refreshSkelSkinTimer.restart();
    return data
  }
  property bool hasDeputy: false //是否使用dual这个功能还是相信后人智慧吧
  clip: true

  Timer {
    id: refreshSkelSkinTimer
    interval: 1000
    repeat: false
    running: false

    onTriggered: {
      root.skinNameChanged() // 手动刷新一下
    }
  }

  Loader {
    id: imgLoader
    anchors.fill: parent
    sourceComponent: {
      if (root.isSkeleton) {
        if (root.skelData) return skeletonAnim;
      } else if (root.source.endsWith(".gif")) {
        return animated;
      } else if (root.source.endsWith(".mp4")) {
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
      fillMode: Image.PreserveAspectCrop
      source: root.source
      smooth: true

    }
  }

  Component {
    id: animated
    AnimatedImage {
      anchors.fill: parent
      fillMode: Image.PreserveAspectCrop
      source: root.source
      playing: true
    }
  }

  Component {
    id: videoImg
    Video {
      id: videoPlayer
      anchors.fill: parent
      source: root.source
      loops: MediaPlayer.Infinite
      fillMode: Image.PreserveAspectCrop
      muted: true

      Component.onCompleted: play()
      Component.onDestruction: {
        videoPlayer.stop();
        videoPlayer.source = "";
      }
      onSourceChanged: {
        if (source !== "") {
          play();
        }
      }
    }
  }

  Component {
    id: skeletonAnim
    Item {
      anchors.fill: parent

      Loader {
        id: bgLoader
        anchors.fill: parent
        sourceComponent: {
          if (root.skelData.staticBg) {
            return skelStaticBg
          } else if (root.skelData.atlasBgFile) {
            return skelBg
          }
        }
      }

      Component{
        id: skelStaticBg
        Image {
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          source: root.skelData.path + root.skelData.staticBg
        }
      }

      Component {
        id: skelBg
        SkeletonAnimation {
          atlasFile: root.skelData.path + root.skelData.atlasBgFile
          skeletonDataFile: root.skelData.path + root.skelData.skelBgFile
          skeletonScale: root.skelData.renderScale
          spineVersion: SpineVersion.Auto
          premultipliedAlapha: false
          x: root.width * root.skelData.bgXOffset
          y: root.height * root.skelData.bgYOffset
          scale: root.skelData.bodyScale * root.height / root.skelData.renderScale / 175

          Component.onCompleted: {
            if (root.skelData.bgShownAnim && root.enabledShown) {
              setAnimation(0, root.skelData.bgShownAnim, false);
              addAnimation(0, root.skelData.bgNormalAnim, true);
            } else {
              setAnimation(0, root.skelData.bgNormalAnim, true)
            }
          }
        }
      }

      SkeletonAnimation {
        id: skel
        atlasFile: root.skelData.path + root.skelData.atlasBodyFile
        skeletonDataFile: root.skelData.path + root.skelData.skelBodyFile
        skeletonScale: root.skelData.renderScale
        spineVersion: SpineVersion.Auto
        premultipliedAlapha: false
        x: root.width * root.skelData.bodyXOffset
        y: root.height * root.skelData.bodyYOffset
        scale: root.skelData.bodyScale * root.height / root.skelData.renderScale / 175

        Component.onCompleted: {
          if (root.skelData.bodyShownAnim && root.enabledShown) {
            setAnimation(0, root.skelData.bodyShownAnim, false);
            addAnimation(0, root.skelData.bodyNormalAnim, true);
          } else {
            setAnimation(0, root.skelData.bodyNormalAnim, true)
          }
        }
      }
    }
  }
}
