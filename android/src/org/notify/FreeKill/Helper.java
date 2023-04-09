// SPDX-License-Identifier: GPL-3.0-or-later

package org.notify.FreeKill;

import android.app.Activity;
import android.view.View;
import android.view.WindowManager;
import org.qtproject.qt.android.QtNative;

public class Helper {
  public static void InitView() {
    Activity activity = QtNative.activity();

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
}
