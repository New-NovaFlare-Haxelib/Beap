#include <jni.h>
#include <android/asset_manager_jni.h>
#include <android/asset_manager.h>
#include <android/log.h>
#include <stdlib.h>
#include <string.h>
#include <hl.h>
#include "_std/String.h"

#define LOG_TAG "HL_JNI"
#define LOG_ERR(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOG_INFO(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

extern int main(int argc, char *argv[]);

static AAssetManager *g_assetMgr = NULL;
static int g_lastReadSize = 0;

static char* convertJString(JNIEnv *env, jstring src) {
    if (src == NULL) return NULL;

    jclass strClass = (*env)->FindClass(env, "java/lang/String");
    jstring encoding = (*env)->NewStringUTF(env, "UTF-8");
    jmethodID getBytes = (*env)->GetMethodID(env, strClass, "getBytes", "(Ljava/lang/String;)[B");

    jbyteArray byteArr = (jbyteArray)(*env)->CallObjectMethod(env, src, getBytes, encoding);
    (*env)->DeleteLocalRef(env, encoding);

    jsize length = (*env)->GetArrayLength(env, byteArr);
    if (length <= 0) {
        (*env)->DeleteLocalRef(env, byteArr);
        return NULL;
    }

    jbyte *raw = (*env)->GetByteArrayElements(env, byteArr, NULL);
    char *result = (char *)malloc(length + 1);
    memcpy(result, raw, length);
    result[length] = '\0';

    (*env)->ReleaseByteArrayElements(env, byteArr, raw, JNI_ABORT);
    (*env)->DeleteLocalRef(env, byteArr);

    return result;
}

JNIEXPORT jint JNICALL
Java_org_haxe_HashLinkActivity_startHL(JNIEnv *env, jclass cls) {
    LOG_INFO("Starting HashLink main");
    return main(0, NULL);
}

JNIEXPORT void JNICALL
Java_org_haxe_HashLinkActivity_initAssets(JNIEnv *env, jclass cls, jobject assetMgr, jstring dir) {
    LOG_INFO("Initializing asset manager");
    g_assetMgr = AAssetManager_fromJava(env, assetMgr);
}

JNIEXPORT jint JNICALL
Java_org_haxe_HashLinkActivity_tmpSize(JNIEnv *env, jclass cls) {
    return g_lastReadSize;
}

JNIEXPORT jbyteArray JNICALL
Java_org_haxe_HashLinkActivity_getAssetBytes(JNIEnv *env, jclass cls, String path) {
    if (g_assetMgr == NULL) {
        LOG_ERR("Asset manager not initialized");
        return NULL;
    }

    char *nativePath = hl_to_utf8(path->bytes);
    AAsset *file = AAssetManager_open(g_assetMgr, nativePath, AASSET_MODE_BUFFER);

    if (file == NULL) {
        LOG_ERR("Failed to open asset: %s", nativePath);
        return NULL;
    }

    off_t fileSize = AAsset_getLength(file);
    vbyte *buffer = (vbyte *)hl_gc_alloc_noptr(fileSize + 1);

    g_lastReadSize = AAsset_read(file, buffer, fileSize);
    AAsset_close(file);

    if (g_lastReadSize <= 0) {
        LOG_ERR("Failed to read asset: %s", nativePath);
        return NULL;
    }

    return buffer;
}