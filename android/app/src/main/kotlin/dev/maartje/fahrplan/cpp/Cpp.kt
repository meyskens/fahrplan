package dev.maartje.fahrplan.cpp

object Cpp {

    init {
        System.loadLibrary("lc3")
    }

    fun init() {}

    @JvmStatic
    external fun decodeLC3(lc3Data: ByteArray?): ByteArray?
    @JvmStatic
    external fun rnNoise(st:Long, input: FloatArray):FloatArray
    @JvmStatic
    external fun createRNNoiseState():Long
    @JvmStatic
    external fun destroyRNNoiseState(st:Long)
}