// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QString>

// SoLoud 音频播放封装：替代 Qt ffmpeg 后端播放 mp3/wav 短音效。
// 线程安全（SoLoud 内部音频线程，play 可从任意线程调用）。
namespace SoloudPlayer {

// 初始化引擎（可多次调用，幂等）；失败返回 false
bool init();

// 播放指定音频文件（mp3/wav 均可，dr_mp3 解码），并发多次调用会叠加播放
void playFile(const QString &path, float volume);

// 全局音量 0..1
void setVolume(float volume);

// 停止所有声音
void stopAll();

// 关闭音频引擎：停音 → 释放解码缓存 → 关闭后端设备。幂等，可在应用退出时调用。
void shutdown();

} // namespace SoloudPlayer
