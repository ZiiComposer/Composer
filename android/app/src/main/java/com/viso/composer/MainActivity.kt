package com.viso.composer

import android.Manifest
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.graphics.Color
import android.os.*
import android.util.Log
import android.view.*
import android.widget.Toast
import androidx.annotation.Keep
import androidx.appcompat.app.AppCompatActivity
import com.viso.composer.databinding.ActivityMainBinding
import java.io.File
import kotlin.system.exitProcess

/**
 * next:
 *  根据时间戳调整播放速度
 *  使用OpenGL渲染
 */
class MainActivity : AppCompatActivity(), SurfaceHolder.Callback {
    private lateinit var binding: ActivityMainBinding

    private var threadDecode: Thread? = null //解码&播放线程

    private var isConnected = false
    private var isSurfaceCreated = false

    private var threadConnect: HandlerThread? = null
    private var handlerConnect: Handler? = null

    private var screenWidth = 0
    private var screenHeight = 0

    private lateinit var pathDir: String//保存图片和视频的文件夹

    private val localTest = true//使用本地sd卡里的视频做测试

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        //首次安装按home键置入后台，从桌面图标点击重新启动的问题
        if (!isTaskRoot) {
            finish()
            return
        }
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val window = window
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or View.SYSTEM_UI_FLAG_LAYOUT_STABLE or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        window.statusBarColor = Color.TRANSPARENT

        configUI()
        init()
        //请求存储权限
        val permissions = arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            requestPermissions(permissions, 66)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        disconnect()
        stopPlay()
    }

    private fun configUI() {
        binding.apply {
            surface.holder.addCallback(this@MainActivity)
            etIp.setAntiShakeListener {
                InputDialog.show(supportFragmentManager, InputDialog.TAG_IP) { res ->
                    etIp.text = res
                }
            }
            etPort.setAntiShakeListener {
                InputDialog.show(supportFragmentManager, InputDialog.TAG_PORT) { res ->
                    etPort.text = res
                }
            }
            etFps.setAntiShakeListener {
                InputDialog.show(supportFragmentManager, InputDialog.TAG_FPS) { res ->
                    etFps.text = res
                    val fps = try {
                        res.toInt()
                    } catch (e: Exception) {
                        0
                    }
                    if (fps < 0 || fps > 120) {
                        Toast.makeText(this@MainActivity, "请输入合理帧率(0-120)", Toast.LENGTH_SHORT).show()
                    } else {
                        if (fps == 0) {
                            etFps.text = "实时"
                        }
                        limitFps(fps)
                    }
                }
            }
            tvPlay.setAntiShakeListener {
                if (tvPlay.isSelected) {
                    disconnect()
                    stopPlay()
//                    binding.root.postDelayed({
//                        handlerConnect?.removeCallbacksAndMessages(null)
//                        handlerConnect = null
//                        threadConnect?.quitSafely()
//                        threadConnect = null
//                    }, 500)
                    isConnected = false
                    tvPlay.text = "播放"
                    finish()
                    exitProcess(0)
                } else {
//                    if (!isConnected) {
                    val ip = etIp.text.toString()
                    val port = etPort.text.toString().toInt()
                    // TODO: 2021/11/27 线程管理
                    threadConnect = HandlerThread("connect");
                    threadConnect!!.start();
                    handlerConnect = Handler(threadConnect!!.looper)
                    handlerConnect!!.post {
                        if (localTest) {
                            parseData()
                        } else {
                            connect(ip, port)
                        }
                    }
                    isConnected = true
//                    }
                    tryStartDecode()
                    tvPlay.text = "退出"
                }
                tvPlay.isSelected = !tvPlay.isSelected
            }
            tvOrientation.setAntiShakeListener {
                requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                llController.visibility = View.GONE
                llOrientation.visibility = View.GONE
            }
            root.viewTreeObserver.addOnGlobalLayoutListener(object : ViewTreeObserver.OnGlobalLayoutListener {
                override fun onGlobalLayout() {
                    root.viewTreeObserver.removeOnGlobalLayoutListener(this)
                    screenWidth = root.width
                    screenHeight = root.height
                    resizeSurface(screenWidth, screenHeight)
                }
            })
            tvSaveVideo.setAntiShakeListener {
                if (tvSaveVideo.isSelected) {
                    val h264FilePath = stopSaveVideo()
                    tvSaveVideo.text = "保存视频"
                    if (!File(h264FilePath).exists()) {
                        Toast.makeText(this@MainActivity, "视频文件不存在", Toast.LENGTH_SHORT).show()
                    } else {
                        Thread {
                            val code = h246ToMp4(h264FilePath, h264FilePath.replace(".h264", ".mp4"))
                            binding.root.post {
                                if (code == 0) {
                                    Toast.makeText(this@MainActivity, "MP4视频保存成功:$pathDir", Toast.LENGTH_LONG).show()
                                } else {
                                    Toast.makeText(this@MainActivity, "MP4保存失败", Toast.LENGTH_SHORT).show()
                                }
                            }
                        }.start()
                    }
                } else {
                    checkPathDir()
                    val videoFilePath = "$pathDir${File.separator}${System.currentTimeMillis()}.h264"
                    saveVideo(videoFilePath)
                    tvSaveVideo.text = "停止保存"
                }
                tvSaveVideo.isSelected = !tvSaveVideo.isSelected
            }
            tvSaveImg.setAntiShakeListener {
                checkPathDir()
                val imgFilePath = "$pathDir${File.separator}${System.currentTimeMillis()}.jpg"
                captureImg(imgFilePath)
            }
        }
    }

    override fun onBackPressed() {
        if (binding.llController.visibility == View.VISIBLE) {
            exit()
        } else {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            binding.llController.visibility = View.VISIBLE
            binding.llOrientation.visibility = View.VISIBLE
        }
    }

    external fun init()

    external fun writePacket(byteArray: ByteArray, size: Int, bKeyFrame: Boolean)

    //连接推流服务器
    external fun connect(ip: String, port: Int)

    //释放连接
    external fun disconnect()

    //开始解码播放
    external fun startPlay(mSurface: Surface)

    //停止解码播放
    external fun stopPlay()

    //重置一下数据
    external fun postResume()

    external fun captureImg(path: String)
    external fun saveVideo(path: String)
    external fun stopSaveVideo(): String
    external fun limitFps(fps: Int)
    external fun h246ToMp4(h264Path: String, mp4Path: String): Int

    private fun tryStartDecode() {
        if (isConnected && isSurfaceCreated) {
            threadDecode?.start()
        }
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        Log.d("MainActivity", "surfaceCreated: ")
        isSurfaceCreated = true
        threadDecode = Thread({
            startPlay(binding.surface.holder.surface)
        }, "decode")
        tryStartDecode()
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        Log.d("MainActivity", "surfaceDestroyed: ")
        isSurfaceCreated = false
        stopPlay()
        threadDecode = null
    }

    override fun onResume() {
        super.onResume()
        postResume()
    }

    private var originSysUiVisibility = 0
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (newConfig.orientation == Configuration.ORIENTATION_LANDSCAPE) {
            originSysUiVisibility = window.decorView.systemUiVisibility
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            resizeSurface(screenHeight, screenWidth)
        } else {
            window.decorView.systemUiVisibility = originSysUiVisibility
            resizeSurface(screenWidth, screenHeight)
        }
    }

    private fun resizeSurface(width: Int, height: Int) {
        if (width == 0 || height == 0) return
        val lp = binding.surface.layoutParams
        if (width / height >= 1280f / 720f) {
            lp.height = height
            lp.width = height * 1280 / 720;
        } else {
            lp.width = width
            lp.height = width * 720 / 1280
        }
        binding.surface.layoutParams = lp
    }

    private val path: String = File(Environment.getExternalStorageDirectory(), "record2.h264").absolutePath
    private var startIndex: Int = 0

    private var cnt = 0
    fun parseData() {
        Thread {
            val bytes = MediaCodecPlayer.getBytes(path)
            Log.d(MediaCodecPlayer.TAG, "play: ${bytes.size}")

            while (true) {
                var nextFrameStart = MediaCodecPlayer.findByFrame(bytes, startIndex + 3, bytes.size)
                //送多帧
                /* if (nextFrameStart > 0) {
                     nextFrameStart = MediaCodecPlayer.findByFrame(bytes, nextFrameStart + 3, bytes.size)
                 }
                 if (nextFrameStart > 0) {
                     nextFrameStart = MediaCodecPlayer.findByFrame(bytes, nextFrameStart + 3, bytes.size)
                 }*/
                val length = if (nextFrameStart < 0) bytes.size - startIndex else nextFrameStart - startIndex
                cnt++
                Log.d(MediaCodecPlayer.TAG, "$cnt  nextFrameStart: $nextFrameStart $length")
                val temp = ByteArray(length)
                temp.forEachIndexed { index, _ ->
                    temp[index] = bytes[startIndex + index]
                }
                writePacket(temp, length, true)
                //流结束了
                if (nextFrameStart < 0) {
                    break
                }
                startIndex = nextFrameStart
                Thread.sleep(16)
            }
        }.start()
    }

    private var lastPressBackTime = 0L

    private fun exit() {
        if ((System.currentTimeMillis() - lastPressBackTime) > 2000) {
            Toast.makeText(this, "再按一次退出程序", Toast.LENGTH_SHORT).show()
            lastPressBackTime = System.currentTimeMillis()
        } else {
            finish()
            exitProcess(0)
        }
    }

    /**
     * jni调用
     */
    @Keep
    fun saveImgFinish(code: Int) {
        binding.root.post {
            if (code == 0) {
                Toast.makeText(this, "图片保存成功:$pathDir", Toast.LENGTH_LONG).show()
            } else {
                Toast.makeText(this, "截图失败", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun checkPathDir() {
        if (!this::pathDir.isInitialized) {
            val external = Environment.getExternalStorageDirectory()
            if (external == null) {
                pathDir = (getExternalFilesDir(null) ?: filesDir).path
            } else {
                pathDir = "${external.path}${File.separator}composer"
                val dst = File(pathDir)
                if (!dst.exists()) {
                    dst.mkdirs()
                }
            }
        }
    }
}