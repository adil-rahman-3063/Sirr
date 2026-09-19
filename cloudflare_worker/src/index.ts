import { Coordinates, CalculationMethod, CalculationParameters, PrayerTimes } from 'adhan';
import { sendWebPush, PushSubscription, VapidKeys, PushPayload } from './webpush';

export interface Env {
  DB: D1Database;
  VAPID_PUBLIC_KEY: string;
  VAPID_PRIVATE_KEY: string;
  VAPID_SUBJECT: string;
}

interface SubscriptionRow {
  id: string;
  endpoint: string;
  p256dh: string;
  auth: string;
  lat: number;
  lng: number;
  location_key: string;
  timezone: string;
  city?: string;
  method: number;
  fajr: number;
  dhuhr: number;
  asr: number;
  maghrib: number;
  isha: number;
  last_prayer?: string;
  created_at: number;
  updated_at: number;
}

interface DailyPrayerTimesRow {
  location_key: string;
  date_str: string;
  lat: number;
  lng: number;
  method: number;
  timezone: string;
  fajr: string;
  sunrise: string;
  dhuhr: string;
  asr: string;
  maghrib: string;
  isha: string;
  created_at: number;
}

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...CORS_HEADERS,
    },
  });
}

// Generate location key by rounding coordinates to 2 decimal places (~1.1 km accuracy)
export function getLocationKey(lat: number, lng: number, method: number): string {
  return `${lat.toFixed(2)},${lng.toFixed(2)},${method}`;
}

// Helper: Clean time string "05:14 (IST)" -> "05:14"
function sanitizeTime(timeStr: string): string {
  if (!timeStr) return '';
  return timeStr.split(' ')[0].trim();
}

// Get current date formatted in target timezone (YYYY-MM-DD)
function getDateInTimezone(date: Date, timezone: string): { dateStr: string; dateApiStr: string; currentTimeStr: string } {
  try {
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    const dateStr = formatter.format(date); // YYYY-MM-DD

    const [year, month, day] = dateStr.split('-');
    const dateApiStr = `${day}-${month}-${year}`; // DD-MM-YYYY for Aladhan API

    const timeFormatter = new Intl.DateTimeFormat('en-GB', {
      timeZone: timezone,
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    });
    const currentTimeStr = timeFormatter.format(date); // HH:mm

    return { dateStr, dateApiStr, currentTimeStr };
  } catch {
    // Fallback to UTC
    const dateStr = date.toISOString().slice(0, 10);
    const [year, month, day] = dateStr.split('-');
    const dateApiStr = `${day}-${month}-${year}`;
    const hours = String(date.getUTCHours()).padStart(2, '0');
    const minutes = String(date.getUTCMinutes()).padStart(2, '0');
    return { dateStr, dateApiStr, currentTimeStr: `${hours}:${minutes}` };
  }
}

// Fallback astronomical calculation using adhan library
function calculateFallbackPrayerTimes(lat: number, lng: number, method: number, date: Date, timezone: string) {
  const coordinates = new Coordinates(lat, lng);
  let params = CalculationMethod.Egyptian();
  if (method === 1) params = CalculationMethod.MuslimWorldLeague();
  else if (method === 2) params = CalculationMethod.NorthAmerica();
  else if (method === 4) params = CalculationMethod.UmmAlQura();
  else if (method === 5) params = CalculationMethod.Dubai();
  else if (method === 7) params = CalculationMethod.Kuwait();
  else if (method === 8) params = CalculationMethod.Qatar();
  else if (method === 9 || method === 11) params = CalculationMethod.Singapore();
  else if (method === 13) params = CalculationMethod.Turkey();
  else if (method === 15) params = CalculationMethod.MoonsightingCommittee();
  else if (method === 16) params = CalculationMethod.Karachi();
  else if (method === 20) params = CalculationMethod.Tehran();

  const pt = new PrayerTimes(coordinates, date, params);
  const formatTime = (d?: Date) => {
    if (!d) return '00:00';
    const f = new Intl.DateTimeFormat('en-GB', { timeZone: timezone, hour: '2-digit', minute: '2-digit', hour12: false });
    return f.format(d);
  };

  return {
    fajr: formatTime(pt.fajr),
    sunrise: formatTime(pt.sunrise),
    dhuhr: formatTime(pt.dhuhr),
    asr: formatTime(pt.asr),
    maghrib: formatTime(pt.maghrib),
    isha: formatTime(pt.isha),
  };
}

// Fetch prayer times from Aladhan API or retrieve from D1 cache
async function getOrFetchDailyPrayerTimes(
  env: Env,
  locationKey: string,
  lat: number,
  lng: number,
  method: number,
  date: Date,
  timezone: string
): Promise<DailyPrayerTimesRow | null> {
  const { dateStr, dateApiStr } = getDateInTimezone(date, timezone);

  // 1. Check local D1 cache first
  const cached = await env.DB.prepare(
    'SELECT * FROM daily_prayer_times WHERE location_key = ? AND date_str = ?'
  ).bind(locationKey, dateStr).first<DailyPrayerTimesRow>();

  if (cached) {
    return cached;
  }

  // 2. Fetch from Aladhan API
  let timings: { fajr: string; sunrise: string; dhuhr: string; asr: string; maghrib: string; isha: string } | null = null;
  let detectedTimezone = timezone;

  try {
    const apiUrl = `https://api.aladhan.com/v1/timings/${dateApiStr}?latitude=${lat}&longitude=${lng}&method=${method}`;
    const res = await fetch(apiUrl, {
      headers: { 'User-Agent': 'SirrPrayerApp/2.1 (https://sirr.pages.dev)' },
    });

    if (res.ok) {
      const json: any = await res.json();
      if (json.code === 200 && json.data && json.data.timings) {
        const raw = json.data.timings;
        timings = {
          fajr: sanitizeTime(raw.Fajr),
          sunrise: sanitizeTime(raw.Sunrise),
          dhuhr: sanitizeTime(raw.Dhuhr),
          asr: sanitizeTime(raw.Asr),
          maghrib: sanitizeTime(raw.Maghrib),
          isha: sanitizeTime(raw.Isha),
        };
        if (json.data.meta?.timezone) {
          detectedTimezone = json.data.meta.timezone;
        }
      }
    }
  } catch (err) {
    console.error(`Failed to fetch from Aladhan API for ${locationKey}:`, err);
  }

  // Fallback if API fails
  if (!timings) {
    timings = calculateFallbackPrayerTimes(lat, lng, method, date, detectedTimezone);
  }

  // 3. Save to D1 database cache
  const now = Date.now();
  await env.DB.prepare(`
    INSERT INTO daily_prayer_times (
      location_key, date_str, lat, lng, method, timezone,
      fajr, sunrise, dhuhr, asr, maghrib, isha, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(location_key, date_str) DO UPDATE SET
      fajr = excluded.fajr,
      sunrise = excluded.sunrise,
      dhuhr = excluded.dhuhr,
      asr = excluded.asr,
      maghrib = excluded.maghrib,
      isha = excluded.isha
  `).bind(
    locationKey,
    dateStr,
    lat,
    lng,
    method,
    detectedTimezone,
    timings.fajr,
    timings.sunrise,
    timings.dhuhr,
    timings.asr,
    timings.maghrib,
    timings.isha,
    now
  ).run();

  return {
    location_key: locationKey,
    date_str: dateStr,
    lat,
    lng,
    method,
    timezone: detectedTimezone,
    fajr: timings.fajr,
    sunrise: timings.sunrise,
    dhuhr: timings.dhuhr,
    asr: timings.asr,
    maghrib: timings.maghrib,
    isha: timings.isha,
    created_at: now,
  };
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const vapid: VapidKeys = {
      publicKey: env.VAPID_PUBLIC_KEY,
      privateKey: env.VAPID_PRIVATE_KEY,
      subject: env.VAPID_SUBJECT || 'mailto:admin@sirr.pages.dev',
    };

    // 0. Debug endpoint to inspect all D1 tables in browser
    if (url.pathname === '/api/debug' && request.method === 'GET') {
      try {
        const now = new Date();
        const subs = await env.DB.prepare('SELECT id, endpoint, city, timezone, lat, lng, method, fajr, dhuhr, asr, maghrib, isha, last_prayer, updated_at FROM subscriptions').all();
        
        // Auto-refresh any outdated locations in daily_prayer_times to today's date
        const existingTimes = await env.DB.prepare('SELECT * FROM daily_prayer_times').all<DailyPrayerTimesRow>();
        if (existingTimes.results && existingTimes.results.length > 0) {
          for (const row of existingTimes.results) {
            const { dateStr } = getDateInTimezone(now, row.timezone);
            if (row.date_str !== dateStr) {
              await getOrFetchDailyPrayerTimes(env, row.location_key, row.lat, row.lng, row.method, now, row.timezone);
              await env.DB.prepare('DELETE FROM daily_prayer_times WHERE location_key = ? AND date_str != ?')
                .bind(row.location_key, dateStr)
                .run();
            }
          }
        }

        const times = await env.DB.prepare('SELECT * FROM daily_prayer_times').all();
        return jsonResponse({
          status: 'ok',
          time: new Date().toISOString(),
          totalSubscriptions: subs.results?.length ?? 0,
          subscriptions: subs.results || [],
          totalCachedDays: times.results?.length ?? 0,
          dailyPrayerTimes: times.results || [],
        });
      } catch (err: unknown) {
        return jsonResponse({ status: 'error', error: String(err) }, 500);
      }
    }

    // 1. Health check & stats
    if (url.pathname === '/api/health' && request.method === 'GET') {
      try {
        const countResult = await env.DB.prepare('SELECT COUNT(*) as total FROM subscriptions').first<{ total: number }>();
        const cachedDays = await env.DB.prepare('SELECT COUNT(*) as total FROM daily_prayer_times').first<{ total: number }>();

        return jsonResponse({
          status: 'ok',
          app: 'سِرّ (Sirr) Prayer Notification Service',
          time: new Date().toISOString(),
          activeSubscriptions: countResult?.total ?? 0,
          cachedLocationDays: cachedDays?.total ?? 0,
        });
      } catch (err: unknown) {
        return jsonResponse({ status: 'error', error: String(err) }, 500);
      }
    }

    // 1b. Prayer times query & cache seeder
    if (url.pathname === '/api/prayer-times' && request.method === 'GET') {
      try {
        const lat = parseFloat(url.searchParams.get('lat') || '21.4225');
        const lng = parseFloat(url.searchParams.get('lng') || '39.8262');
        const method = parseInt(url.searchParams.get('method') || '3', 10);
        const timezone = url.searchParams.get('timezone') || 'Asia/Riyadh';
        const locationKey = getLocationKey(lat, lng, method);
        const today = new Date();
        const { dateStr } = getDateInTimezone(today, timezone);
        const todayTimes = await getOrFetchDailyPrayerTimes(env, locationKey, lat, lng, method, today, timezone);
        
        // Keep strictly only today's data for this location
        await env.DB.prepare('DELETE FROM daily_prayer_times WHERE location_key = ? AND date_str != ?')
          .bind(locationKey, dateStr)
          .run();

        return jsonResponse({
          status: 'ok',
          locationKey,
          prayerTimes: todayTimes,
        });
      } catch (err: unknown) {
        return jsonResponse({ status: 'error', error: String(err) }, 500);
      }
    }

    // 2. Subscribe or Update subscription
    if (url.pathname === '/api/subscribe' && request.method === 'POST') {
      try {
        const body = (await request.json()) as any;
        const {
          endpoint,
          keys,
          lat,
          lng,
          timezone = 'UTC',
          city = '',
          method = 3,
          fajr = 1,
          dhuhr = 1,
          asr = 1,
          maghrib = 1,
          isha = 1,
        } = body;

        if (!endpoint || !keys || !keys.p256dh || !keys.auth || lat === undefined || lng === undefined) {
          return jsonResponse({ error: 'Missing required subscription fields' }, 400);
        }

        const latNum = Number(lat);
        const lngNum = Number(lng);
        const methodNum = Number(method);
        const locationKey = getLocationKey(latNum, lngNum, methodNum);
        const safeTimezone = (timezone && typeof timezone === 'string' && timezone.trim().length > 0) ? timezone.trim() : 'UTC';
        const now = Date.now();
        const id = crypto.randomUUID();

        // Upsert subscription
        await env.DB.prepare(`
          INSERT INTO subscriptions (
            id, endpoint, p256dh, auth, lat, lng, location_key, timezone, city, method,
            fajr, dhuhr, asr, maghrib, isha, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(endpoint) DO UPDATE SET
            p256dh = excluded.p256dh,
            auth = excluded.auth,
            lat = excluded.lat,
            lng = excluded.lng,
            location_key = excluded.location_key,
            timezone = excluded.timezone,
            city = excluded.city,
            method = excluded.method,
            fajr = excluded.fajr,
            dhuhr = excluded.dhuhr,
            asr = excluded.asr,
            maghrib = excluded.maghrib,
            isha = excluded.isha,
            updated_at = excluded.updated_at
        `).bind(
          id,
          endpoint,
          keys.p256dh,
          keys.auth,
          latNum,
          lngNum,
          locationKey,
          safeTimezone,
          city,
          methodNum,
          fajr ? 1 : 0,
          dhuhr ? 1 : 0,
          asr ? 1 : 0,
          maghrib ? 1 : 0,
          isha ? 1 : 0,
          now,
          now
        ).run();

        // Ensure ONLY today's prayer times are fetched and stored
        const today = new Date();
        const { dateStr } = getDateInTimezone(today, safeTimezone);
        await getOrFetchDailyPrayerTimes(env, locationKey, latNum, lngNum, methodNum, today, safeTimezone);

        // Remove any old/extra date rows for this location
        ctx.waitUntil(
          env.DB.prepare('DELETE FROM daily_prayer_times WHERE location_key = ? AND date_str != ?')
            .bind(locationKey, dateStr)
            .run()
        );

        return jsonResponse({ ok: true, message: 'Push subscription updated successfully', locationKey });
      } catch (err: unknown) {
        return jsonResponse({ error: String(err) }, 500);
      }
    }

    // 3. Unsubscribe
    if (url.pathname === '/api/unsubscribe' && request.method === 'POST') {
      try {
        const body = (await request.json()) as any;
        const { endpoint } = body;
        if (!endpoint) {
          return jsonResponse({ error: 'Missing endpoint' }, 400);
        }

        await env.DB.prepare('DELETE FROM subscriptions WHERE endpoint = ?').bind(endpoint).run();
        return jsonResponse({ ok: true, message: 'Unsubscribed successfully' });
      } catch (err: unknown) {
        return jsonResponse({ error: String(err) }, 500);
      }
    }

    // 4. Test notification trigger
    if (url.pathname === '/api/test-push' && request.method === 'POST') {
      try {
        const body = (await request.json()) as any;
        const { endpoint, keys, title, body: textBody } = body;

        if (!endpoint || !keys || !keys.p256dh || !keys.auth) {
          return jsonResponse({ error: 'Missing push subscription' }, 400);
        }

        const subscription: PushSubscription = { endpoint, keys };
        const payload: PushPayload = {
          title: title || 'سِرّ • اختبار الإشعارات',
          body: textBody || 'Notifications are successfully configured for Sirr Prayer Times!',
          icon: 'icons/Icon-192.png',
          badge: 'icons/Icon-192.png',
          tag: 'test-notification',
          data: { url: '/' },
        };

        const result = await sendWebPush(subscription, payload, vapid);
        return jsonResponse(result);
      } catch (err: unknown) {
        return jsonResponse({ error: String(err) }, 500);
      }
    }

    return jsonResponse({ error: 'Endpoint not found' }, 404);
  },

  // Scheduled Cron Handler - runs every minute
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    const vapid: VapidKeys = {
      publicKey: env.VAPID_PUBLIC_KEY,
      privateKey: env.VAPID_PRIVATE_KEY,
      subject: env.VAPID_SUBJECT || 'mailto:admin@sirr.pages.dev',
    };

    const now = new Date();
    const todayUtc = now.toISOString().slice(0, 10);

    // Automatically purge old cached dates older than today
    ctx.waitUntil(env.DB.prepare('DELETE FROM daily_prayer_times WHERE date_str < ?').bind(todayUtc).run());

    // 1. Fetch distinct location keys that have active subscribers
    const locationsResult = await env.DB.prepare(`
      SELECT DISTINCT location_key, lat, lng, method, timezone
      FROM subscriptions 
      WHERE fajr = 1 OR dhuhr = 1 OR asr = 1 OR maghrib = 1 OR isha = 1
    `).all<{ location_key: string; lat: number; lng: number; method: number; timezone: string }>();

    const locations = locationsResult.results || [];
    if (locations.length === 0) return;

    // Cache of daily times for this cron run: Map<location_key, DailyPrayerTimesRow>
    const locationTimesMap = new Map<string, DailyPrayerTimesRow>();

    for (const loc of locations) {
      try {
        const { dateStr } = getDateInTimezone(now, loc.timezone);
        const dailyTimes = await getOrFetchDailyPrayerTimes(
          env,
          loc.location_key,
          loc.lat,
          loc.lng,
          loc.method,
          now,
          loc.timezone
        );
        if (dailyTimes) {
          locationTimesMap.set(loc.location_key, dailyTimes);
        }
        // Keep strictly only today's prayer times for this location
        await env.DB.prepare('DELETE FROM daily_prayer_times WHERE location_key = ? AND date_str != ?')
          .bind(loc.location_key, dateStr)
          .run();
      } catch (err) {
        console.error(`Error fetching daily times for ${loc.location_key}:`, err);
      }
    }

    // 2. Query subscriptions to check for matching prayer times this minute
    const subsResult = await env.DB.prepare(`
      SELECT * FROM subscriptions 
      WHERE fajr = 1 OR dhuhr = 1 OR asr = 1 OR maghrib = 1 OR isha = 1
      LIMIT 2000
    `).all<SubscriptionRow>();

    const subscriptions = subsResult.results || [];

    for (const sub of subscriptions) {
      try {
        const dailyTimes = locationTimesMap.get(sub.location_key);
        if (!dailyTimes) continue;

        const { dateStr, currentTimeStr } = getDateInTimezone(now, sub.timezone);

        const prayers = [
          { name: 'Fajr', nameAr: 'الفجر', time: dailyTimes.fajr, enabled: sub.fajr === 1 },
          { name: 'Dhuhr', nameAr: 'الظهر', time: dailyTimes.dhuhr, enabled: sub.dhuhr === 1 },
          { name: 'Asr', nameAr: 'العصر', time: dailyTimes.asr, enabled: sub.asr === 1 },
          { name: 'Maghrib', nameAr: 'المغرب', time: dailyTimes.maghrib, enabled: sub.maghrib === 1 },
          { name: 'Isha', nameAr: 'العشاء', time: dailyTimes.isha, enabled: sub.isha === 1 },
        ];

        for (const p of prayers) {
          if (!p.enabled || !p.time) continue;

          // Check if current minute in user's timezone matches prayer time "HH:mm"
          if (p.time === currentTimeStr) {
            const prayerKey = `${p.name}:${dateStr}`;

            if (sub.last_prayer !== prayerKey) {
              const payload: PushPayload = {
                title: `سِرّ • صلاة ${p.nameAr}`,
                body: `Time for ${p.name} Prayer (${p.time})${sub.city ? ` in ${sub.city}` : ''}.`,
                icon: 'icons/Icon-192.png',
                badge: 'icons/Icon-192.png',
                tag: `prayer-${p.name.toLowerCase()}`,
                data: { prayer: p.name, time: p.time, date: dateStr },
              };

              const pushSubscription: PushSubscription = {
                endpoint: sub.endpoint,
                keys: {
                  p256dh: sub.p256dh,
                  auth: sub.auth,
                },
              };

              const result = await sendWebPush(pushSubscription, payload, vapid);

              if (result.ok) {
                await env.DB.prepare('UPDATE subscriptions SET last_prayer = ? WHERE endpoint = ?')
                  .bind(prayerKey, sub.endpoint)
                  .run();
              } else if (result.status === 404 || result.status === 410) {
                // Endpoint has expired or user revoked browser permission
                await env.DB.prepare('DELETE FROM subscriptions WHERE endpoint = ?').bind(sub.endpoint).run();
              }
            }
          }
        }
      } catch (err) {
        console.error(`Error processing subscription for endpoint ${sub.endpoint}:`, err);
      }
    }
  },
};
