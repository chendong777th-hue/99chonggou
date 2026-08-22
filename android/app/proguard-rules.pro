# Tencent native SDK classes are referenced from JNI by exact class names.
-keep class com.tencent.** { *; }
-keep class com.tencent.liteav.** { *; }
-keep class com.tencent.rtmp.** { *; }
-keep class com.tencent.trtc.** { *; }
-keep class io.trtc.** { *; }
-keep class com.tencent.cloud.tuikit.** { *; }
-keep class com.tencent.qcloud.** { *; }
-keep class com.tencent.imsdk.** { *; }
-keep class com.qq.qcloud.tencent_im_sdk_plugin.** { *; }

# Push SDKs also use reflection and manifest providers during startup.
-keep class cn.jiguang.** { *; }
-keep class com.jiguang.** { *; }
-keep class cn.jpush.** { *; }
-keep class com.jpush.** { *; }

-keep class vip.ninechat.pro.BuildConfig { *; }
-keepattributes *Annotation*,InnerClasses,EnclosingMethod,Signature
