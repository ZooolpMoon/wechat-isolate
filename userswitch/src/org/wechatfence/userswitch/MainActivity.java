package org.wechatfence.userswitch;

import android.app.Activity;
import android.app.AlertDialog;
import android.os.Bundle;
import android.os.Process;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.io.FileOutputStream;

/**
 * 按钮切换 Android 用户：主用户(0) <-> 微信区(10)。
 *
 * - 在主空间点：先启动一个 root watchdog（back-watcher.sh，轮询微信区的触发文件），
 *   再切到微信区；
 * - 在微信区点：不需要 root，只写一个触发文件到自己的 external files 目录，
 *   主空间的 watchdog 收到后切回主用户。
 */
public class MainActivity extends Activity {

    private static final int WECHAT_USER = 10;
    private static final String WATCHDOG = "/sdcard/Download/DSH-Go/back-watcher.sh";
    private String lastError = "";

    private int myUser() {
        return Process.myUid() / 100000;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        final int me = myUser();
        final int target = (me == 0) ? WECHAT_USER : 0;

        int pad = (int) (20 * getResources().getDisplayMetrics().density);
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(pad, pad, pad, pad);

        TextView info = new TextView(this);
        info.setTextSize(18);
        info.setText("当前用户：" + (me == 0 ? "机主 (0)" : "微信区 (" + me + ")"));

        Button btn = new Button(this);
        btn.setText(target == 0 ? "切回机主" : "切到微信区 (" + target + ")");
        btn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (target == 0) {
                    requestBack();
                } else {
                    switchToWechat();
                }
            }
        });

        box.addView(info);
        box.addView(btn);
        setContentView(box);
    }

    /** 主空间：启动 watchdog，然后切到微信区 */
    private void switchToWechat() {
        lastError = "";
        final String cmd = "sh " + WATCHDOG;
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    java.lang.Process p = Runtime.getRuntime().exec(
                            new String[]{"/debug_ramdisk/su", "-c", cmd});
                    p.waitFor();
                } catch (Exception ignored) {
                }
            }
        }).start();
        try {
            Thread.sleep(400);
        } catch (InterruptedException ignored) {
        }

        int rc = trySwitch(WECHAT_USER);
        if (rc == 0) {
            Toast.makeText(this, "切换中…", Toast.LENGTH_SHORT).show();
            finish();
        } else {
            showError("切换失败");
        }
    }

    /** 微信区：写触发文件，让主空间的 watchdog 切回来（不需要 root） */
    private void requestBack() {
        try {
            File dir = getExternalFilesDir(null);
            if (dir == null) throw new RuntimeException("external files dir is null");
            FileOutputStream out = new FileOutputStream(new File(dir, "back"));
            out.write('1');
            out.close();
            Toast.makeText(this, "已请求切回机主，1-2 秒后返回…", Toast.LENGTH_LONG).show();
            finish();
        } catch (Exception e) {
            showError("请求失败：" + e.getMessage() + "\n（可以重启手机，会自动回到主空间）");
        }
    }

    private int trySwitch(int target) {
        int rc = runSu("am switch-user " + target);
        if (rc != 0) {
            rc = runSu("setenforce 0; am switch-user " + target + "; setenforce 1");
        }
        return rc;
    }

    private int runSu(String cmd) {
        String[] candidates = {"/debug_ramdisk/su", "su", "/system/bin/su", "/system/xbin/su", "/sbin/su"};
        for (String su : candidates) {
            try {
                java.lang.Process p = Runtime.getRuntime().exec(new String[]{su, "-c", cmd});
                int rc = p.waitFor();
                lastError += su + "  exit=" + rc + "\n";
                if (rc == 0) return 0;
            } catch (Exception e) {
                lastError += su + "  ERR " + e.getClass().getSimpleName() + ": " + e.getMessage() + "\n";
            }
        }
        return -1;
    }

    private void showError(String title) {
        new AlertDialog.Builder(this)
                .setTitle(title)
                .setMessage(lastError)
                .setPositiveButton("知道了", null)
                .show();
    }
}
