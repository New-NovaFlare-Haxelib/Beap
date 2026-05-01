#include <jni.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <android/log.h>
#include <EGL/egl.h>
#include <GLES2/gl2.h>

#include "hashlink/hl.h"

#define LOG_TAG "BeapSDL3"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Forward declarations
extern int hl_main(int argc, char **argv);

// Java VM reference
static JavaVM *g_jvm = NULL;
static JNIEnv *g_env = NULL;

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
    g_jvm = vm;
    LOGI("JNI_OnLoad called");
    return JNI_VERSION_1_6;
}

JNIEXPORT void JNICALL Java_com_novaflare_engine_MainActivity_nativeInit(JNIEnv *env, jobject thiz, jstring apkPath) {
    LOGI("nativeInit called");
    
    const char *nativePath = (*env)->GetStringUTFChars(env, apkPath, NULL);
    
    // Set up HashLink
    hl_set_apk_path(nativePath);
    
    (*env)->ReleaseStringUTFChars(env, apkPath, nativePath);
    
    // Initialize HashLink
    char *argv[] = {"beap", NULL};
    hl_main(1, argv);
}

JNIEXPORT void JNICALL Java_com_novaflare_engine_MainActivity_nativePause(JNIEnv *env, jobject thiz) {
    LOGI("nativePause called");
    hl_pause();
}

JNIEXPORT void JNICALL Java_com_novaflare_engine_MainActivity_nativeResume(JNIEnv *env, jobject thiz) {
    LOGI("nativeResume called");
    hl_resume();
}

JNIEXPORT void JNICALL Java_com_novaflare_engine_MainActivity_nativeDestroy(JNIEnv *env, jobject thiz) {
    LOGI("nativeDestroy called");
    hl_destroy();
}
