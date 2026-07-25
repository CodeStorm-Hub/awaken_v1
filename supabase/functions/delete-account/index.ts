import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Store/app-policy account-deletion requirement (Google Play User Data
// policy + Apple Guideline 5.1.1): self-service in-app deletion of the
// account AND its data, not just deactivation. Runs server-side with the
// service-role key -- that key can never ship in the client app -- so this
// is a dedicated Edge Function, not a client-callable RPC.
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Client bound to the *caller's* JWT -- only used to resolve who is
  // making this request, never to perform the deletion. This is what
  // stops one user from deleting another user's account: the id to delete
  // always comes from the verified JWT, never from the request body.
  const callerClient = createClient(supabaseUrl, serviceRoleKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData?.user) {
    return new Response(JSON.stringify({ error: "Invalid session" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const userId = userData.user.id;

  // Admin client for the actual deletion work.
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  // Explicit cascade, not relied on FK ON DELETE behavior -- delete
  // dependent rows before the profile/auth user so this works regardless
  // of how each FK was defined. Order matters: children before parents.
  const tables = ["sessions", "runs", "territories", "user_stats", "alarms"];
  for (const table of tables) {
    const { error } = await adminClient.from(table).delete().eq("user_id", userId);
    if (error) {
      return new Response(JSON.stringify({ error: `Failed deleting ${table}: ${error.message}` }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  // P0 fix: `profiles.squad_id`, `squad_reports.squad_id`,
  // `squad_reports.reporter_id`, and `squad_reports.reported_user_id` are
  // all `ON DELETE NO ACTION` foreign keys (confirmed live against the
  // deployed schema) -- deleting a squad this user owns while another
  // member's `profiles.squad_id` still points at it, or deleting this
  // user's profile while any `squad_reports` row references them (as
  // reporter, target, or via a squad they own), throws a real FK
  // violation and aborts deletion entirely. Every dependent row must be
  // cleared first, in the order below.

  // 1. Reports this user filed or was the target of, in ANY squad --
  //    must go before deleting their profile.
  const { error: ownReportsError } = await adminClient
    .from("squad_reports")
    .delete()
    .or(`reporter_id.eq.${userId},reported_user_id.eq.${userId}`);
  if (ownReportsError) {
    return new Response(
      JSON.stringify({ error: `Failed deleting this user's squad reports: ${ownReportsError.message}` }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // 2. Squads this user owns.
  const { data: ownedSquads, error: ownedSquadsFetchError } = await adminClient
    .from("squads")
    .select("id")
    .eq("owner_id", userId);
  if (ownedSquadsFetchError) {
    return new Response(
      JSON.stringify({ error: `Failed listing owned squads: ${ownedSquadsFetchError.message}` }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
  const ownedSquadIds = (ownedSquads ?? []).map((s: { id: string }) => s.id);

  if (ownedSquadIds.length > 0) {
    // 2a. Reports filed by/against other members within a squad this user
    //     owns -- otherwise deleting the squad itself would FK-violate on
    //     squad_reports.squad_id.
    const { error: squadReportsError } = await adminClient
      .from("squad_reports")
      .delete()
      .in("squad_id", ownedSquadIds);
    if (squadReportsError) {
      return new Response(
        JSON.stringify({ error: `Failed deleting reports for owned squads: ${squadReportsError.message}` }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    // 2b. Detach every member from a squad this user owns before deleting
    //     it (matches "leave squad" semantics -- members lose the squad,
    //     they aren't deleted themselves).
    const { error: detachMembersError } = await adminClient
      .from("profiles")
      .update({ squad_id: null })
      .in("squad_id", ownedSquadIds);
    if (detachMembersError) {
      return new Response(
        JSON.stringify({ error: `Failed detaching squad members: ${detachMembersError.message}` }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    // 2c. Now safe to delete the squads themselves.
    const { error: squadError } = await adminClient.from("squads").delete().in("id", ownedSquadIds);
    if (squadError) {
      return new Response(JSON.stringify({ error: `Failed deleting owned squads: ${squadError.message}` }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  const { error: profileError } = await adminClient.from("profiles").delete().eq("id", userId);
  if (profileError) {
    return new Response(JSON.stringify({ error: `Failed deleting profile: ${profileError.message}` }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { error: authError } = await adminClient.auth.admin.deleteUser(userId);
  if (authError) {
    return new Response(JSON.stringify({ error: `Failed deleting auth user: ${authError.message}` }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
