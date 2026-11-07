package com.voyager.voyager.feature.phone

import android.telecom.Call
import android.telecom.InCallService

class VoyagerInCallService : InCallService() {
    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        CallStateBus.add(call)
    }

    override fun onCallRemoved(call: Call) {
        CallStateBus.remove(call)
        super.onCallRemoved(call)
    }

    override fun onDestroy() {
        CallStateBus.clear()
        super.onDestroy()
    }
}
