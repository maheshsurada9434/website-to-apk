package __PACKAGE__;

import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.view.ViewGroup;
import android.webkit.WebView;

import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;

import com.getcapacitor.BridgeActivity;
import com.getcapacitor.WebViewListener;

/** Website-to-APK shell: opens downloads in the right app and (optionally) adds pull-to-refresh. */
public class MainActivity extends BridgeActivity {
    private static final boolean PULL_TO_REFRESH = __PULL__;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        final WebView web = getBridge().getWebView();
        web.setDownloadListener((url, ua, cd, mime, len) -> {
            try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url))); } catch (Exception ignored) { }
        });
        if (!PULL_TO_REFRESH) return;
        ViewGroup parent = (ViewGroup) web.getParent();
        if (parent == null) return;
        int index = parent.indexOfChild(web);
        ViewGroup.LayoutParams lp = web.getLayoutParams();
        parent.removeView(web);
        final SwipeRefreshLayout swipe = new SwipeRefreshLayout(this);
        swipe.setColorSchemeColors(Color.parseColor("__ACCENT__"));
        swipe.addView(web, new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        parent.addView(swipe, index, lp);
        swipe.setOnChildScrollUpCallback((p, child) -> web.getScrollY() > 0);
        swipe.setOnRefreshListener(web::reload);
        getBridge().addWebViewListener(new WebViewListener() {
            @Override public void onPageLoaded(WebView webView) { swipe.setRefreshing(false); }
        });
    }
}
