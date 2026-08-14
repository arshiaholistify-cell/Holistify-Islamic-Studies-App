// Holistify Islamic Studies — Signup Edge Function
//
// Creates a "synthetic" Supabase Auth user (fake internal email, random
// password, admin-created with email_confirm:true) so no confirmation
// email is ever sent. Stores a bcrypt hash of the chosen PIN plus the
// synthetic credentials in is_profile_secrets (service-role only), then
// signs the synthetic account in and returns a real Supabase session so
// the browser ends up with a normal auth.uid()-backed session and every
// existing RLS policy keeps working unchanged.

import { createClient } from "npm:@supabase/supabase-js@2";
import bcrypt from "npm:bcryptjs@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { full_name, role, class_name, pin } = await req.json();

    if (!full_name || typeof full_name !== "string" || !full_name.trim())
      return jsonResponse({ error: "Please enter your name." }, 400);
    if (role !== "facilitator" && role !== "student")
      return jsonResponse({ error: "Invalid role." }, 400);
    if (!/^\d{4}$/.test(pin ?? ""))
      return jsonResponse({ error: "PIN must be exactly 4 digits." }, 400);

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { autoRefreshToken: false, persistSession: false } });

    const syntheticEmail = `${crypto.randomUUID()}@islamic-studies.internal`;
    const syntheticPassword = crypto.randomUUID() + crypto.randomUUID();

    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email: syntheticEmail,
      password: syntheticPassword,
      email_confirm: true,
      user_metadata: { full_name: full_name.trim(), role, class_name: class_name ?? "" },
    });
    if (createErr || !created.user) {
      console.error("createUser error:", createErr);
      return jsonResponse({ error: "Could not create account. Please try again." }, 500);
    }

    const pinHash = bcrypt.hashSync(pin, 10);
    const { error: secretsErr } = await admin.from("is_profile_secrets").insert({
      id: created.user.id,
      pin_hash: pinHash,
      synthetic_email: syntheticEmail,
      synthetic_password: syntheticPassword,
    });
    if (secretsErr) {
      console.error("secrets insert error:", secretsErr);
      await admin.auth.admin.deleteUser(created.user.id);
      return jsonResponse({ error: "Could not create account. Please try again." }, 500);
    }

    // Sign the new synthetic account in as a normal (anon-key) client to get a real session.
    const anon = createClient(SUPABASE_URL, ANON_KEY);
    const { data: signIn, error: signInErr } = await anon.auth.signInWithPassword({
      email: syntheticEmail,
      password: syntheticPassword,
    });
    if (signInErr || !signIn.session) {
      console.error("post-signup sign-in error:", signInErr);
      return jsonResponse({ error: "Account created, but sign-in failed. Please try logging in." }, 500);
    }

    const { data: profile } = await admin.from("is_profiles").select("*").eq("id", created.user.id).single();

    return jsonResponse({ session: signIn.session, profile });
  } catch (err) {
    console.error("is-signup error:", err);
    return jsonResponse({ error: "Unexpected error. Please try again." }, 500);
  }
});
