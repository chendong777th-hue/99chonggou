package vip.ninechat.pro.logging

/** No-op replacement for project-owned android.util.Log calls. */
object SilentLog {
    fun d(tag: String, message: String): Int = 0
    fun i(tag: String, message: String): Int = 0
    fun w(tag: String, message: String): Int = 0
    fun e(tag: String, message: String): Int = 0
}
