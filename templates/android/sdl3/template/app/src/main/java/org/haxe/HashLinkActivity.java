package org.haxe;

import org.libsdl.app.SDLActivity;
import android.content.Context;
import android.content.res.AssetManager;
import android.os.Bundle;
import android.util.Log;

public class HashLinkActivity extends SDLActivity {
    private static HashLinkActivity instance;
    public static native int startHL();
    public native static void initAssets(AssetManager assetManager, String strDir);

    @Override
    protected String getMainFunction() {
        return "main";
    }

    @Override
    protected String[] getLibraries() {
        return new String[]{
            "SDL3",
            "NexusForge"
        };
    }

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        instance = this;
        initAssets(getAssets(), "");
    }

    public static HashLinkActivity getContext() {
        return instance;
    }
}
