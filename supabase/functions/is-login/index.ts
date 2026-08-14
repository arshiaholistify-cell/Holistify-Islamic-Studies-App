// Holistify Islamic Studies — Login Edge Function
//
// Matches full_name + role (+ optional class_name) against is_profiles,
// then checks the given PIN against the bcrypt hash in is_profile_secrets
// (service-role only). On match, signs the profile's synthetic auth
// account in and returns a real Supabase session, so the browser ends up
// with a normal auth.uid()-backed session and every existing RLS policy
// keeps working unchanged.

import { createClient } from "npm:@supabase/supabase-js@2";
import bcrypt from "npm:bcryptjs@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { full_name, pin, role, class_name } = await req.json();

    if (!full_name || typeof full_name !== "string" || !full_name.trim())
      return jsonResponse({ error: "Please enter your name." }, 400);
    if (!/^\d{4}$/.test(pin ?? ""))
      return jsonResponse({ error: "Please enter your 4-digit PIN." }, 400);
    if (role !== "facilitator" && role !== "student")
      return jsonResponse({ error: "Invalid role." }, 400);

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { autoRefreshToken: false, persistSession: false } });

    let query = admin
      .from("is_profiles")
      .select("id, full_name, role, class_name, is_active")
      .eq("role", role)
      .ilike("full_name", full_name.trim());
    if (class_name) query = query.eq("class_name", class_name);

    const { data: candidates, error: candErr } = await query;
    if (candErr) {
      console.error("candidate lookup error:", candErr);
      return jsonResponse({ error: "Login failed. Please try again." }, 500);
    }
    if (!candidates || candidates.length === 0)
      return jsonResponse({ error: "Incorrect name, role, or PIN." }, 401);

    const ids = candidates.map((c) => c.id);
    const { data: secrets, error: secErr } = await admin
      .from("is_profile_secrets")
      .select("id, pin_hash, synthetic_email, synthetic_password")
      .in("id", ids);
    if (secErr) {
      console.error("secrets lookup error:", secErr);
      return jsonResponse({ error: "Login failed. Please try again." }, 500);
    }

    const match = (secrets ?? []).find((s) => bcrypt.compareSync(pin, s.pin_hash));
    if (!match) return jsonResponse({ error: "Incorrect name, role, or PIN." }, 401);

    const anon = createClient(SUPABASE_URL, ANON_KEY);
    const { data: signIn, error: signInErr } = await anon.auth.signInWithPassword({
      email: match.synthetic_email,
      password: match.synthetic_password,
    });
    if (signInErr || !signIn.session) {
      console.error("sign-in error:", signInErr);
      return jsonResponse({ error: "Login failed. Please try again." }, 500);
    }

    const profile = candidates.find((c) => c.id === match.id);
    return jsonResponse({ session: signIn.session, profile });
  } catch (err) {
    console.error("is-login error:", err);
    return jsonResponse({ error: "Unexpected error. Please try again." }, 500);
  }
});
