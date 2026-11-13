package ca.wabble.wabway

import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import kotlin.math.roundToInt

/**
 * Trail mode's Bluetooth beacon: who is where, readable only by the trip's crew.
 *
 * Sent as manufacturer data under company id 0xFFFF (the Bluetooth SIG's id
 * for testing / private use), 22 bytes:
 *
 *   [0..2]   'W' 'W' version 1          — lets the phone's chip filter for us
 *   [3..5]   trip tag                   — HMAC(trip key, 10-minute slot), so
 *                                         strangers can't follow one phone around
 *   [6..21]  one AES block (trip key):
 *            subject index, flags, lat×1e7, lng×1e7, accuracy m,
 *            fix age (10 s units), sender index, 3 random bytes
 *
 * "Subject" is whose position it is; "sender" is the phone sending it. They
 * differ when a phone relays a crew member it heard earlier, so positions hop
 * from phone to phone. The trip key comes from the trip id, which only members
 * know.
 */
object TrailBeacon {
    const val COMPANY_ID = 0xFFFF
    val MAGIC = byteArrayOf(0x57, 0x57, 0x01)
    val MAGIC_MASK = byteArrayOf(-1, -1, -1)
    const val SIZE = 22
    private const val SLOT_MS = 10 * 60 * 1000L

    private const val FLAG_TRAIL_ON = 1
    private const val FLAG_RELAYED = 2
    private const val FLAG_HAS_FIX = 4

    data class Fix(val lat: Double, val lng: Double, val accuracyM: Int, val timeMs: Long)

    data class Packet(
        val subject: Int,
        val sender: Int,
        val relayed: Boolean,
        /** Null when the subject's phone has no GPS fix yet (still "here"). */
        val fix: Fix?,
    )

    private class Keys(val aes: ByteArray, val mac: ByteArray)

    private val keyCache = HashMap<String, Keys>()
    private val random = SecureRandom()

    private fun keys(tripId: String): Keys = synchronized(keyCache) {
        keyCache.getOrPut(tripId) {
            val d = MessageDigest.getInstance("SHA-256")
            val aes = d.digest("wabway-trail-aes:$tripId".toByteArray()).copyOf(16)
            val mac = d.digest("wabway-trail-tag:$tripId".toByteArray())
            Keys(aes, mac)
        }
    }

    private fun tag(k: Keys, slot: Long): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(k.mac, "HmacSHA256"))
        return mac.doFinal("slot:$slot".toByteArray()).copyOf(3)
    }

    fun encode(tripId: String, p: Packet, nowMs: Long): ByteArray {
        val k = keys(tripId)
        val block = ByteArray(16)
        block[0] = p.subject.toByte()
        var flags = FLAG_TRAIL_ON
        if (p.relayed) flags = flags or FLAG_RELAYED
        val fix = p.fix
        if (fix != null) flags = flags or FLAG_HAS_FIX
        block[1] = flags.toByte()
        putInt(block, 2, if (fix != null) (fix.lat * 1e7).roundToInt() else 0)
        putInt(block, 6, if (fix != null) (fix.lng * 1e7).roundToInt() else 0)
        block[10] = (fix?.accuracyM ?: 0).coerceIn(0, 255).toByte()
        block[11] = (if (fix != null) ((nowMs - fix.timeMs) / 10_000L).coerceIn(0, 255) else 0).toInt().toByte()
        block[12] = p.sender.toByte()
        val nonce = ByteArray(3).also { random.nextBytes(it) }
        System.arraycopy(nonce, 0, block, 13, 3)

        val cipher = Cipher.getInstance("AES/ECB/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(k.aes, "AES"))
        val enc = cipher.doFinal(block)

        val out = ByteArray(SIZE)
        System.arraycopy(MAGIC, 0, out, 0, 3)
        System.arraycopy(tag(k, nowMs / SLOT_MS), 0, out, 3, 3)
        System.arraycopy(enc, 0, out, 6, 16)
        return out
    }

    /** Null when it isn't this trip's beacon (or isn't ours at all). */
    fun decode(tripId: String, data: ByteArray?, nowMs: Long): Packet? {
        if (data == null || data.size < SIZE) return null
        for (i in 0 until 3) if (data[i] != MAGIC[i]) return null
        val k = keys(tripId)
        val slot = nowMs / SLOT_MS
        val got = data.copyOfRange(3, 6)
        // Clocks drift and a packet can straddle a slot boundary.
        if (listOf(slot, slot - 1, slot + 1).none { tag(k, it).contentEquals(got) }) return null

        val cipher = Cipher.getInstance("AES/ECB/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(k.aes, "AES"))
        val b = cipher.doFinal(data, 6, 16)
        val flags = b[1].toInt() and 0xFF
        if (flags and FLAG_TRAIL_ON == 0) return null
        val fix = if (flags and FLAG_HAS_FIX != 0) {
            val lat = getInt(b, 2) / 1e7
            val lng = getInt(b, 6) / 1e7
            if (lat !in -90.0..90.0 || lng !in -180.0..180.0) return null
            Fix(lat, lng, b[10].toInt() and 0xFF, nowMs - (b[11].toInt() and 0xFF) * 10_000L)
        } else null
        return Packet(
            subject = b[0].toInt() and 0xFF,
            sender = b[12].toInt() and 0xFF,
            relayed = flags and FLAG_RELAYED != 0,
            fix = fix,
        )
    }

    private fun putInt(b: ByteArray, at: Int, v: Int) {
        b[at] = (v shr 24).toByte()
        b[at + 1] = (v shr 16).toByte()
        b[at + 2] = (v shr 8).toByte()
        b[at + 3] = v.toByte()
    }

    private fun getInt(b: ByteArray, at: Int): Int =
        ((b[at].toInt() and 0xFF) shl 24) or ((b[at + 1].toInt() and 0xFF) shl 16) or
            ((b[at + 2].toInt() and 0xFF) shl 8) or (b[at + 3].toInt() and 0xFF)
}
