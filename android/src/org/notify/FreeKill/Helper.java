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

  static MediaPlayer mp;

  public static void PlaySound(String path, float vol) {
    // FIXME: 此法中途会被GC
    mp = new MediaPlayer();
    mp.setOnCompletionListener(new OnCompletionListener() {
      @Override
      public void onCompletion(MediaPlayer mp) {
        mp.reset();
        mp.release();
      }
    });
    try {
      mp.setDataSource(path);
      mp.setVolume(vol, vol);
      mp.prepare();
      mp.start();
    } catch (Exception e) {
      e.printStackTrace();
    }
  }
}
