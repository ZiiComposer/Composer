package com.viso.composer

import android.content.Context
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.Toast
import androidx.fragment.app.DialogFragment
import androidx.fragment.app.FragmentManager
import com.viso.composer.databinding.DialogInputBinding

/**
 * Created by visoc on 2021/12/2.
 */
class InputDialog : DialogFragment() {
    private lateinit var binding: DialogInputBinding
    private var confirmCallback: ((res: String) -> Unit)? = null
    private var showTag = TAG_IP

    companion object {
        const val TAG_IP = "ip"
        const val TAG_PORT = "port"
        const val TAG_FPS = "fps"

        fun show(fragmentManager: FragmentManager, tag: String, onConfirm: (res: String) -> Unit) {
            val dialog = InputDialog()
            dialog.confirmCallback = onConfirm
            dialog.showTag = tag
            dialog.show(fragmentManager, tag)
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        super.onCreateView(inflater, container, savedInstanceState)
        binding = DialogInputBinding.inflate(inflater)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.apply {
            if (showTag == TAG_PORT || showTag == TAG_FPS) {
                if (showTag == TAG_FPS) {
                    etInputPort.hint = "请输入帧率"
                }
                etInputPort.visibility = View.VISIBLE
                etInputIp.visibility = View.GONE
                etInputPort.postDelayed({
                    etInputPort.requestFocus()
                    val imm = requireActivity().getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                    imm?.showSoftInput(etInputPort, 0)
                }, 100)
            } else {
                etInputPort.visibility = View.GONE
                etInputIp.visibility = View.VISIBLE
                etInputIp.postDelayed({
                    etInputIp.requestFocus()
                    val imm = requireActivity().getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                    imm?.showSoftInput(etInputIp, 0)
                }, 100)
            }
            tvBtn.setAntiShakeListener {
                val res = if (showTag == TAG_PORT || showTag == TAG_FPS) {
                    etInputPort.text?.toString()
                } else {
                    etInputIp.text.toString()
                }
                if (res.isNullOrEmpty()) {
                    Toast.makeText(requireContext(), "不能为空", Toast.LENGTH_SHORT).show()
                    return@setAntiShakeListener
                }
                confirmCallback?.invoke(res)
                etInputIp.clearFocus()
                etInputPort.clearFocus()
                dismissAllowingStateLoss()
            }
        }
    }
}