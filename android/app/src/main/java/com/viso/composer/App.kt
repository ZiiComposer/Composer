package com.viso.composer

import android.app.Application
import com.tencent.bugly.crashreport.CrashReport

/**
 * Created by visoc on 2021/11/20.
 */
class App : Application() {
    companion object {
        var sApp: App? = null
    }

    override fun onCreate() {
        super.onCreate()
        sApp = this
        CrashReport.initCrashReport(applicationContext, "efee790f24", true)

        System.loadLibrary("composer")
        //ffmpeg
        System.loadLibrary("avdevice-57")
        System.loadLibrary("avfilter-6")
        System.loadLibrary("avformat-57")
        System.loadLibrary("avutil-55")
        System.loadLibrary("swresample-2")
        System.loadLibrary("swscale-4")
        System.loadLibrary("avcodec-57")
    }
}

