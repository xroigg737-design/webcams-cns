export default {
  async fetch(request, env, ctx) {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=60'
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // Step 1: Visit WeatherCloud page to get session + CSRF
      const pageResp = await fetch('https://app.weathercloud.net/d1807591580', {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml'
        },
        redirect: 'follow'
      });

      const pageText = await pageResp.text();

      // Extract CSRF token from inline JS
      const csrfMatch = pageText.match(/WEATHERCLOUD_CSRF_TOKEN:"([^"]+)"/);
      if (!csrfMatch) throw new Error('CSRF token not found');
      const csrf = csrfMatch[1];

      // Extract session cookies
      const rawCookies = pageResp.headers.getSetCookie
        ? pageResp.headers.getSetCookie()
        : (pageResp.headers.get('set-cookie') || '').split(/,(?=\s*\w+=)/);

      const cookieStr = rawCookies
        .map(c => c.split(';')[0].trim())
        .filter(Boolean)
        .join('; ');

      // Step 2: Call weather stats API
      const apiUrl = `https://app.weathercloud.net/device/stats?code=1807591580&WEATHERCLOUD_CSRF_TOKEN=${encodeURIComponent(csrf)}`;
      const apiResp = await fetch(apiUrl, {
        headers: {
          'Cookie': cookieStr,
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': 'https://app.weathercloud.net/d1807591580',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
      });

      const raw = await apiResp.text();
      if (raw.includes('invalid')) throw new Error('API rejected request');
      const data = JSON.parse(raw);

      // Step 3: Extract wind data and convert m/s -> knots
      const MS_TO_KN = 1.94384;
      const toKn = (arr) => arr ? +(arr[1] * MS_TO_KN).toFixed(1) : null;

      const result = {
        wspd: toKn(data.wspd_current),
        wspdavg: toKn(data.wspdavg_current),
        wspdhi: toKn(data.wspdhi_current),
        wdir: data.wdir_current ? data.wdir_current[1] : null,
        wdiravg: data.wdiravg_current ? data.wdiravg_current[1] : null,
        temp: data.temp_current ? data.temp_current[1] : null,
        updated: data.last_update,
        unit: 'kn'
      };

      return new Response(JSON.stringify(result), { headers: corsHeaders });
    } catch (e) {
      return new Response(JSON.stringify({ error: e.message }), {
        status: 500, headers: corsHeaders
      });
    }
  }
};
