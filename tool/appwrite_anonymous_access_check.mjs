import { expectedCounts } from './appwrite_migration_audit.mjs';

// Deliberately sends no API key, JWT or session cookie.
try {
  const results=[];
  for (const table of Object.keys(expectedCounts)) {
    const response=await fetch(`https://fra.cloud.appwrite.io/v1/tablesdb/public/tables/${table}/rows`,{
      headers:{'X-Appwrite-Project':'6ac5fccb0004756daef1'},signal:AbortSignal.timeout(30000),
    });
    if (response.ok) {
      const page=await response.json();
      if (page.total!==0 || !Array.isArray(page.rows) || page.rows.length!==0) {
        throw new Error('Anonymous access returned data');
      }
    } else if (![401,403,404].includes(response.status)) {
      throw new Error('Unexpected anonymous access response');
    }
    results.push({table,status:response.status,anonymousDataVisible:false});
  }
  console.log(JSON.stringify(results));
} catch {
  console.error('Anonymous access check failed; response bodies are not logged.');
  process.exitCode=1;
}
