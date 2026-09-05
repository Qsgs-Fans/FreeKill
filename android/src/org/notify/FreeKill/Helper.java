// SPDX-License-Identifier: GPL-3.0-or-later

package org.notify.FreeKill;

import java.util.*;
import android.provider.Settings;
import android.app.Activity;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.media.MediaPlayer;
import android.media.MediaPlayer.OnCompletionListener;

import androidx.annotation.NonNull;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

public class Helper {
  private static Activity m_activity = null;

  public static void SetActivity(Activity activity) {
    m_activity = activity;
  }

  public static void InitView() {
    Activity activity = m_activity;

    // create app-specific dir on external storage
    activity.getExternalFilesDir("");

    activity.runOnUiThread(new Runnable() {
      @Override
      public void run() {
        Window window = activity.getWindow();
        View decorView = window.getDecorView();

        // by ChatGPT

        // ========= 1. CUTOUT 刘海区设置 =========
        WindowManager.LayoutParams lp = window.getAttributes();
        lp.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        window.setAttributes(lp);

        // ========= 2. 让内容延伸到全屏 =========
        WindowCompat.setDecorFitsSystemWindows(window, false);

        // ========= 3. 使用 WindowInsetsController =========
        WindowInsetsControllerCompat controller =
                WindowCompat.getInsetsController(window, decorView);

        if (controller != null) {
          controller.setSystemBarsBehavior(
                  WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);

          controller.hide(WindowInsetsCompat.Type.statusBars()
                  | WindowInsetsCompat.Type.navigationBars());
        }

        // 保持屏幕常亮
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
      }
    });
  }

  public static String GetSerial() {
    Activity activity = m_activity;
    return Settings.Secure.getString(
      activity.getContentResolver(),
      Settings.Secure.ANDROID_ID
    );
  }

  @NonNull
  public static String GetLocaleCode() {
    return java.util.Locale.getDefault().toString();
  }

  // MediaPlayer 实例池：有限个常驻复用，既允许并发/连播（不掐断旧音频），
  // 又避免每音效新建导致文件句柄无限泄漏。
  static final int SOUND_POOL_SIZE = 8;
  static MediaPlayer[] sPlayers = new MediaPlayer[SOUND_POOL_SIZE];
  static int sNext = 0;

  public static void PlaySound(String path, float vol) {
    // 找一个空闲槽（未创建 或 不在播放）；全忙时轮转覆盖最旧那个
    int slot = -1;
    for (int i = 0; i < SOUND_POOL_SIZE; i++) {
      int s = (sNext + i) % SOUND_POOL_SIZE;
      MediaPlayer p = sPlayers[s];
      if (p == null || !p.isPlaying()) {
        slot = s;
        break;
      }
    }
    if (slot < 0) slot = sNext;
    sNext = (slot + 1) % SOUND_POOL_SIZE;

    MediaPlayer player = sPlayers[slot];
    if (player == null) {
      player = new MediaPlayer();
      // 播完仅 reset 以便复用（不 release，释放交给池）
      player.setOnCompletionListener(new OnCompletionListener() {
        @Override
        public void onCompletion(MediaPlayer p) {
          try {
            p.reset();
          } catch (Exception ignored) {
          }
        }
      });
      sPlayers[slot] = player;
    }

    try {
      player.reset();
      player.setDataSource(path);
      player.setVolume(vol, vol);
      player.prepare();
      player.start();
    } catch (Exception e) {
      e.printStackTrace();
      try {
        player.reset();
      } catch (Exception ignored) {
      }
    }
  }
}
