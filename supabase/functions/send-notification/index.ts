import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const PROJECT_ID = 'wabway-wabble'
const FCM_URL = `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`

// ── OAuth2 token from service account ────────────────────────────────────────

function toBase64Url(b64: string): string {
  return b64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

async function getFcmAccessToken(): Promise<string> {
  const raw = Deno.env.get('FCM_SERVICE_ACCOUNT')
  if (!raw) throw new Error('FCM_SERVICE_ACCOUNT secret is not set')
  let sa: Record<string, string>
  try {
    sa = JSON.parse(raw)
  } catch {
    throw new Error('FCM_SERVICE_ACCOUNT is not valid JSON — re-download the service account from Firebase console and re-set the secret')
  }
  const now = Math.floor(Date.now() / 1000)
  const claim = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }

  // Build JWT header.payload using base64url (required for JWT — standard base64
  // uses + and / which get mangled as spaces in form-encoded bodies)
  const header = toBase64Url(btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' })))
  const payload = toBase64Url(btoa(JSON.stringify(claim)))
  const unsigned = `${header}.${payload}`

  // Import the private key
  const pemBody = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\n/g, '')
  const keyBytes = Uint8Array.from(atob(pemBody), c => c.charCodeAt(0))
  const privateKey = await crypto.subtle.importKey(
    'pkcs8', keyBytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false, ['sign'],
  )

  // Sign and base64url-encode the signature
  const encoder = new TextEncoder()
  const sigBytes = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', privateKey, encoder.encode(unsigned))
  const sig = toBase64Url(btoa(String.fromCharCode(...new Uint8Array(sigBytes))))
  const jwt = `${unsigned}.${sig}`

  // Exchange for access token
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${encodeURIComponent(jwt)}`,
  })
  const data = await res.json()
  if (!data.access_token) throw new Error(`OAuth failed: ${JSON.stringify(data)}`)
  return data.access_token
}

// ── Send one FCM message ──────────────────────────────────────────────────────

async function sendFcm(token: string, title: string, body: string, data: Record<string, string>, accessToken: string, highPriority = false) {
  const res = await fetch(FCM_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data,
        android: { priority: 'high' },
        // For SOS / high-priority calls, wake the device immediately on iOS too
        ...(highPriority && {
          apns: {
            headers: { 'apns-priority': '10', 'apns-push-type': 'alert' },
            payload: { aps: { sound: 'default', 'content-available': 1 } },
          },
        }),
      },
    }),
  })
  if (!res.ok) {
    const err = await res.text()
    // Token expired/unregistered — caller should delete it
    if (err.includes('UNREGISTERED') || err.includes('INVALID_ARGUMENT')) return 'invalid'
    console.error('FCM error:', err)
  }
  return 'ok'
}

// ── Handler ───────────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method !== 'POST') return new Response('method not allowed', { status: 405 })

  try {
    const { title, body, trip_id, exclude_user_id, data = {}, high_priority = false } = await req.json()
    if (!title || !body || !trip_id) {
      return new Response('missing title/body/trip_id', { status: 400 })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // Get all members of this trip
    const { data: members, error: memberErr } = await supabase
      .from('trip_members')
      .select('user_id')
      .eq('trip_id', trip_id)
    if (memberErr) return new Response(memberErr.message, { status: 500 })

    const recipientIds = members
      .map((m: { user_id: string }) => m.user_id)
      .filter((id: string) => id !== exclude_user_id)

    if (recipientIds.length === 0) return new Response(JSON.stringify({ sent: 0 }), { status: 200 })

    // Get FCM tokens for those users
    const { data: tokens, error: tokenErr } = await supabase
      .from('device_tokens')
      .select('id, token')
      .in('user_id', recipientIds)
    if (tokenErr) return new Response(tokenErr.message, { status: 500 })
    if (!tokens || tokens.length === 0) return new Response(JSON.stringify({ sent: 0 }), { status: 200 })

    const accessToken = await getFcmAccessToken()

    const results = await Promise.all(
      tokens.map(async (row: { id: string; token: string }) => {
        const result = await sendFcm(row.token, title, body, data, accessToken, high_priority)
        // Clean up stale tokens
        if (result === 'invalid') {
          await supabase.from('device_tokens').delete().eq('id', row.id)
        }
        return result
      }),
    )

    const sent = results.filter(r => r === 'ok').length
    return new Response(JSON.stringify({ sent, total: tokens.length }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('send-notification error:', message)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
