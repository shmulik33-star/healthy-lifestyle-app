// Private service-binding target. No public workers.dev hostname or routes.
// The binding provides shared, per-Cloudflare-location approximate counters.
export default {
  async fetch(request,env) {
    const headers={'content-type':'application/json','cache-control':'no-store'};
    if(request.method!=='POST'||new URL(request.url).pathname!=='/limit') {
      return new Response('{}',{status:404,headers});
    }
    try {
      const text=await request.text();
      if(text.length>256) return new Response('{}',{status:400,headers});
      const {key}=JSON.parse(text);
      if(typeof key!=='string'||!/^[a-f0-9]{64}$/.test(key)) return new Response('{}',{status:400,headers});
      const {success}=await env.LOGIN_LIMIT.limit({key});
      return new Response(JSON.stringify({success:success===true}),{headers});
    } catch {
      return new Response('{}',{status:503,headers});
    }
  },
};
