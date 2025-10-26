// SPDX-License-Identifier: GPL-3.0-or-later

package org.notify.FreeKill;

import java.util.*;
import android.provider.Settings;
import android.app.Activity;
import android.view.View;
import android.view.WindowManager;
import android.media.MediaPlayer;
import android.media.MediaPlayer.OnCompletionListener;

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
        View decorView = activity.getWindow().getDecorView();
        int uiOpt = View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION |
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY |
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
                View.SYSTEM_UI_FLAG_FULLSCREEN;
        decorView.setSystemUiVisibility(uiOpt);

        // FullScreen
        WindowManager.LayoutParams lp = activity.getWindow().getAttributes();
        lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        activity.getWindow().setAttributes(lp);

        // keep screen on
        activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        decorView.setOnSystemUiVisibilityChangeListener
        (new View.OnSystemUiVisibilityChangeListener() {
          @Override
          public void onSystemUiVisibilityChange(int visibility) {
            // Hide navigation bar when enter fullscreen again
            if ((visibility & View.SYSTEM_UI_FLAG_FULLSCREEN) == 0) {
              decorView.setSystemUiVisibility(uiOpt);
            }
          }
        });
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
