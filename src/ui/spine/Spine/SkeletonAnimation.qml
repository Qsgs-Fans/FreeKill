/******************************************************************************
 * Spine Runtimes Software License
 * Version 2.1
 *
 * Copyright (c) 2013, Esoteric Software
 * All rights reserved.
 *
 * You are granted a perpetual, non-exclusive, non-sublicensable and
 * non-transferable license to install, execute and perform the Spine Runtimes
 * Software (the "Software") solely for internal use. Without the written
 * permission of Esoteric Software (typically granted by licensing Spine), you
 * may not (a) modify, translate, adapt or otherwise create derivative works,
 * improvements of the Software or develop new applications using the Software
 * or (b) remove, delete, alter or obscure any trademarks or any copyright,
 * trademark, patent or other intellectual property or proprietary rights
 * notices on or in the Software, including any copy thereof. Redistributions
 * in binary or source form must include this license and terms.
 *
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

import QtQuick 2.0
import Spine 1.0

Item{
    id: root
    property bool debugTracer: false

    property alias skeletonDataFile: skeleton.skeletonDataFile
    property alias atlasFile: skeleton.atlasFile
    property alias skeletonScale: skeleton.scale
    property alias skin: skeleton.skin
    property alias timeScale: skeleton.timeScale
    property alias premultipliedAlapha: skeleton.premultipliedAlapha
    property alias debugSlots: skeleton.debugSlots
    property alias debugBones: skeleton.debugBones
    property alias sourceSize: skeleton.sourceSize
    property alias spineVersion: skeleton.spineVersion
    property alias detectedVersion: skeleton.detectedVersion

    signal start(int trackIndex)
    signal end(int trackIndex)
    signal complete(int trackIndex, int loopCount)
    signal event(int trackIndex, SpineEvent event)

    function setToSetupPose(){
        skeleton.setToSetupPose();
    }
    function setBonesToSetupPose(){
        skeleton.setBonesToSetupPose();
    }
    function setSlotsToSetupPose(){
        skeleton.setSlotsToSetupPose();
    }
    function setAttachment(slotName, attachmentName){
        skeleton.setAttachment(slotName, attachmentName);
    }
    function setMix(fromAnimation, toAnimation, duration){
        skeleton.setMix(fromAnimation, toAnimation, duration);
    }
    function setAnimation (trackIndex, name, loop){
        skeleton.setAnimation(trackIndex, name, loop);
    }
    function addAnimation (trackIndex, name, loop, delay){
        skeleton.addAnimation(trackIndex, name, loop, delay === null?0:delay);
    }
    function isPlaying(trackIndex){
        return skeleton.isPlaying(trackIndex === null?0:trackIndex);
    }
    function clearTracks(){
        skeleton.clearTracks();
    }
    function clearTrack(trackIndex){
        skeleton.clearTrack(trackIndex===null?0:trackIndex);
    }

    SkeletonAnimationFbo{
        id: skeleton

        property int ticks: 0
        NumberAnimation on ticks{
            from: 0; to: 100;
            loops: Animation.Infinite
            running: true
        }

        onTicksChanged: {
            skeleton.updateSkeletonAnimation();
        }

        onSkeletonStart: function(trackIndex){
            root.start(trackIndex);
        }
        onSkeletonEnd: function(trackIndex){
            root.end(trackIndex);
        }
        onSkeletonComplete: function(trackIndex, loopCount){
            root.complete(trackIndex, loopCount);
        }
        onSkeletonEvent: function(trackIndex, event){
            root.event(trackIndex, event);
        }
    }

    Rectangle{
        visible: root.debugTracer
        anchors.centerIn: parent
        width: 8; height:8
        color: "#60ff0000"
    }

    Rectangle{
        visible: root.debugTracer
        anchors.fill: skeleton
        color:"transparent"
        border.width: 1
        border.color: "black"
    }
}
