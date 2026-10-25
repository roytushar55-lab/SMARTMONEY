// Downloads every object in one Supabase Storage bucket into a local folder,
// keeping the object paths, so `az storage blob upload-batch` can push them
// to Azure unchanged (same paths => same URLs after the prefix rewrite).
//
//   SUPABASE_URL=https://<ref>.supabase.co SUPABASE_SERVICE_ROLE_KEY=... \
//     node copy-supabase-media.mjs <bucket> <destination folder>
//
// No dependencies; Node 18+ (built-in fetch). Re-runnable: existing files
// of the same size are skipped.

import { mkdir, stat, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

const [bucket, destination] = process.argv.slice(2);
const baseUrl = (process.env.SUPABASE_URL ?? "").replace(/\/+$/, "");
const key = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

if (!bucket || !destination || !baseUrl || !key) {
  console.error("usage: SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node copy-supabase-media.mjs <bucket> <dest>");
  process.exit(2);
}

const headers = { apikey: key, Authorization: `Bearer ${key}` };

async function listPrefix(prefix) {
  const found = [];
  let offset = 0;
  const limit = 1000;
  for (;;) {
    const response = await fetch(`${baseUrl}/storage/v1/object/list/${encodeURIComponent(bucket)}`, {
      method: "POST",
      headers: { ...headers, "content-type": "application/json" },
      body: JSON.stringify({ prefix, limit, offset, sortBy: { column: "name", order: "asc" } }),
    });
    if (!response.ok) {
      throw new Error(`list ${bucket}/${prefix} failed: ${response.status} ${await response.text()}`);
    }
    const items = await response.json();
    for (const item of items) {
      const path = prefix ? `${prefix}/${item.name}` : item.name;
      // Folders come back without an id; files have one.
      if (item.id) {
        found.push({ path, size: item.metadata?.size ?? -1 });
      } else {
        found.push(...(await listPrefix(path)));
      }
    }
    if (items.length < limit) return found;
    offset += limit;
  }
}

async function download(object) {
  const target = join(destination, ...object.path.split("/"));
  try {
    const existing = await stat(target);
    if (object.size >= 0 && existing.size === object.size) return "skipped";
  } catch {
    // not downloaded yet
  }
  const encodedPath = object.path.split("/").map(encodeURIComponent).join("/");
  const response = await fetch(`${baseUrl}/storage/v1/object/${encodeURIComponent(bucket)}/${encodedPath}`, { headers });
  if (!response.ok) {
    throw new Error(`download ${object.path} failed: ${response.status} ${await response.text()}`);
  }
  await mkdir(dirname(target), { recursive: true });
  await writeFile(target, Buffer.from(await response.arrayBuffer()));
  return "downloaded";
}

const objects = await listPrefix("");
console.log(`${bucket}: ${objects.length} objects`);
let downloaded = 0;
let skipped = 0;
for (const object of objects) {
  const result = await download(object);
  if (result === "downloaded") downloaded += 1; else skipped += 1;
}
console.log(`${bucket}: ${downloaded} downloaded, ${skipped} already present`);
