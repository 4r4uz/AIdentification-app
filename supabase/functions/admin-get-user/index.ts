// @ts-nocheck
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authorization = req.headers.get('Authorization');
    if (!authorization) {
      return new Response(JSON.stringify({ error: 'Sesión requerida.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const token = authorization.replace('Bearer ', '');
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: callerAuth, error: callerAuthError } =
      await callerClient.auth.getUser(token);
    if (callerAuthError || !callerAuth.user) {
      throw new Error('Sesión administrativa inválida.');
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);
    const { data: callerProfile, error: profileError } = await adminClient
      .from('profiles')
      .select('role')
      .eq('id', callerAuth.user.id)
      .maybeSingle();
    if (profileError || callerProfile?.role !== 'admin') {
      throw new Error('Solo administradores pueden consultar usuarios.');
    }

    const body = await req.json();
    const userId = body.user_id?.toString();
    if (!userId) {
      throw new Error('El ID del usuario es obligatorio.');
    }

    const { data: targetUser, error: targetError } =
      await adminClient.auth.admin.getUserById(userId);
    if (targetError || !targetUser.user) {
      throw new Error('No se encontró el usuario.');
    }

    const { data: targetProfile } = await adminClient
      .from('profiles')
      .select('role, username, avatar_url, is_active, created_at')
      .eq('id', userId)
      .maybeSingle();

    return new Response(
      JSON.stringify({
        id: targetUser.user.id,
        email: targetUser.user.email ?? '',
        role: targetProfile?.role ?? 'user',
        username: targetProfile?.username ?? '',
        avatar_url: targetProfile?.avatar_url ?? null,
        is_active: targetProfile?.is_active !== false,
        created_at: targetProfile?.created_at ?? targetUser.user.created_at,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
