// Holistify Islamic Studies — Claude proxy Edge Function
//
// Holds the Anthropic API key as a server-side secret so individual
// users never need their own key. Requires a valid Supabase session
// (the app's own login) so the shared key can't be called by anonymous
// visitors. Proxies the request straight through to Anthropic's
// Messages API and returns the response as-is.

import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) return jsonResponse({ error: "Please log in first." }, 401);

    const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    const { data: userData, error: userErr } = await client.auth.getUser(token);
    if (userErr || !userData.user) return jsonResponse({ error: "Please log in first." }, 401);

    if (!ANTHROPIC_API_KEY) {
      console.error("ANTHROPIC_API_KEY secret is not set on this project.");
      return jsonResponse({ error: "AI generation is not configured yet. Please contact the site administrator." }, 500);
    }

    const { system, messages, max_tokens, model } = await req.json();
    if (!Array.isArray(messages) || !messages.length)
      return jsonResponse({ error: "Missing messages." }, 400);

    const anthropicRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: model || "claude-sonnet-4-6",
        max_tokens: max_tokens || 4096,
        ...(system ? { system } : {}),
        messages,
      }),
    });

    const data = await anthropicRes.json();
    if (!anthropicRes.ok) {
      console.error("Anthropic API error:", data);
      return jsonResponse({ error: (data && data.error && data.error.message) || `API error ${anthropicRes.status}` }, anthropicRes.status);
    }
    return jsonResponse(data);
  } catch (err) {
    console.error("is-generate error:", err);
    return jsonResponse({ error: "Unexpected error. Please try again." }, 500);
  }
});
