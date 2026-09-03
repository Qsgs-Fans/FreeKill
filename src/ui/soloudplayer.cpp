// SPDX-License-Identifier: GPL-3.0-or-later

#include "soloudplayer.h"

#ifdef FK_WITH_SOLOUD

#include <QFileInfo>
#include <QHash>
#include <QStringList>

#include <soloud.h>
#include <soloud_wav.h>

namespace {

SoLoud::Soloud gSoloud;
bool gInited = false;
bool gReady = false;

// 已加载音频缓存（内存中保留解码数据），上限内 FIFO 淘汰
QHash<QString, SoLoud::Wav *> gCache;
QStringList gOrder;
constexpr int kMaxCache = 64;

void evictOldest() {
  while (gOrder.size() >= kMaxCache) {
    const QString oldest = gOrder.takeFirst();
    auto *wav = gCache.take(oldest);
    delete wav;
  }
}

} // namespace

namespace SoloudPlayer {

bool init() {
  if (gInited)
    return gReady;
  gInited = true;
  if (gSoloud.init() != SoLoud::SO_NO_ERROR) {
    gReady = false;
    return false;
  }
  gReady = true;
  return true;
}

void playFile(const QString &path, float volume) {
  if (!init())
    return;

  SoLoud::Wav *wav = gCache.value(path);
  if (!wav) {
    // dr_mp3 / dr_wav / dr_flac 自动按扩展名/内容解码
    auto *w = new SoLoud::Wav;
    if (w->load(path.toUtf8().constData()) != SoLoud::SO_NO_ERROR) {
      delete w;
      return;
    }
    evictOldest();
    gCache.insert(path, w);
    gOrder.append(path);
    wav = w;
  }

  // play 对同一 Wav 可并发创建多条音轨（短音效重叠播放）
  gSoloud.play(*wav, volume);
}

void setVolume(float volume) {
  if (gReady)
    gSoloud.setGlobalVolume(volume);
}

void stopAll() {
  if (gReady)
    gSoloud.stopAll();
}

void shutdown() {
  if (!gInited)
    return;
  // 先停掉所有在放的声音，再释放已解码缓存，最后关闭音频后端
  if (gReady)
    gSoloud.stopAll();
  for (auto it = gCache.begin(); it != gCache.end(); ++it)
    delete it.value();
  gCache.clear();
  gOrder.clear();
  if (gReady)
    gSoloud.deinit();
  gInited = false;
  gReady = false;
}

} // namespace SoloudPlayer

#else // !FK_WITH_SOLOUD —— 桩实现（FK_SERVER_ONLY / Android 等无 SoLoud 平台）

namespace SoloudPlayer {

bool init() { return false; }
void playFile(const QString &, float) {}
void setVolume(float) {}
void stopAll() {}
void shutdown() {}

} // namespace SoloudPlayer

#endif
