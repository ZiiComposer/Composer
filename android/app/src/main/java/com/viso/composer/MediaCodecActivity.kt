package com.viso.composer

import android.Manifest
import android.os.Build
import android.os.Bundle
import android.view.SurfaceHolder
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.viso.composer.databinding.ActivityMainBinding
import kotlin.system.exitProcess

/**
 * Created by visoc on 2021/11/30.
 *
 * 使用硬解
 */
class MediaCodecActivity : AppCompatActivity(), SurfaceHolder.Callback {
    private lateinit var binding: ActivityMainBinding

    private lateinit var player: MediaCodecPlayer

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        configUI()
        //请求存储权限
        val permissions = arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            requestPermissions(permissions, 66)
        }
        Toast.makeText(this, "硬解", Toast.LENGTH_SHORT).show()

        player.decodeFile {
            binding.root.post {
                Toast.makeText(this, "数据就绪", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun configUI() {
        binding.apply {
            surface.holder.addCallback(this@MediaCodecActivity)
            tvPlay.setAntiShakeListener {
                if (tvPlay.isSelected) {
                    tvPlay.text = "播放"
                    finish()
                    exitProcess(0)
                } else {
                    val ip = etIp.text.toString()
                    val port = etPort.text.toString().toInt()
                    player.play()
                    tvPlay.text = "退出"
                }
                tvPlay.isSelected = !tvPlay.isSelected
            }
        }

        player = MediaCodecPlayer()
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        player.initCodec(holder.surface)
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        player.releaseCodec()
    }
}