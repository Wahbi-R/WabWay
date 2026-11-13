package ca.wabble.wabway

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Trail mode's Bluetooth beacon: fits a legacy advert, only the trip can read it. */
class TrailBeaconTest {
    private val trip = "8f2c1a7e-3b4d-4e5f-9a10-112233445566"
    private val now = 1_763_000_000_000L
    private val fix = TrailBeacon.Fix(43.6532109, -79.3831843, 7, now - 25_000)

    @Test fun roundTrip() {
        val bytes = TrailBeacon.encode(trip, TrailBeacon.Packet(2, 2, false, fix), now)
        // + 2 company id + 2 AD header + 3 flags = 29 ≤ 31 bytes.
        assertEquals(22, bytes.size)
        val p = TrailBeacon.decode(trip, bytes, now + 1500)!!
        assertEquals(2, p.subject)
        assertEquals(2, p.sender)
        assertFalse(p.relayed)
        assertEquals(fix.lat, p.fix!!.lat, 1e-6)
        assertEquals(fix.lng, p.fix!!.lng, 1e-6)
        assertEquals(7, p.fix!!.accuracyM)
    }

    @Test fun onlyThisTripCanReadIt() {
        val bytes = TrailBeacon.encode(trip, TrailBeacon.Packet(2, 2, false, fix), now)
        assertNull(TrailBeacon.decode("another-trip", bytes, now))
        assertNull(TrailBeacon.decode(trip, ByteArray(22) { 0x57 }, now))
    }

    @Test fun tagRotates() {
        val bytes = TrailBeacon.encode(trip, TrailBeacon.Packet(2, 2, false, fix), now)
        assertNotNull(TrailBeacon.decode(trip, bytes, now + 9 * 60_000))
        assertNull(TrailBeacon.decode(trip, bytes, now + 25 * 60_000))
        val again = TrailBeacon.encode(trip, TrailBeacon.Packet(2, 2, false, fix), now)
        assertFalse(again.copyOfRange(6, 22).contentEquals(bytes.copyOfRange(6, 22)))
        assertArrayEquals(TrailBeacon.MAGIC, bytes.copyOfRange(0, 3))
    }

    @Test fun relayAndNoFix() {
        val relay = TrailBeacon.decode(trip, TrailBeacon.encode(trip, TrailBeacon.Packet(5, 1, true, fix), now), now)!!
        assertTrue(relay.relayed)
        assertEquals(5, relay.subject)
        assertEquals(1, relay.sender)
        val noFix = TrailBeacon.decode(trip, TrailBeacon.encode(trip, TrailBeacon.Packet(0, 0, false, null), now), now)!!
        assertNull(noFix.fix)
    }
}
