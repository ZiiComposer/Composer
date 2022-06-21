package com.viso.composer

import android.view.View

/**
 * Created by visoc on 2021/11/30.
 */
fun View.setAntiShakeListener(millisecond: Long = 500L, block: (View) -> Unit) {
    this.setOnClickListener {
        if (throttleFirst(it, millisecond)) return@setOnClickListener
        block.invoke(it)
    }
}

fun throttleFirst(target: View, millisecond: Long): Boolean {
    val curTimeStamp = System.currentTimeMillis()
    var lastClickTimeStamp: Long = 0
    val o: Any? = target.getTag(R.id.last_click_time)
    if (o == null) {
        target.setTag(R.id.last_click_time, curTimeStamp)
        return false
    }
    lastClickTimeStamp = o as Long
    val isInvalid: Boolean = curTimeStamp - lastClickTimeStamp < millisecond
    if (!isInvalid) {
        target.setTag(R.id.last_click_time, curTimeStamp)
    }
    return isInvalid
}