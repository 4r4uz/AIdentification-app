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
      throw new Error('Sesión requerida.');
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
      throw new Error('Solo administradores pueden modificar usuarios.');
    }

    const body = await req.json();
    const userId = body.user_id?.toString();
    if (!userId) throw new Error('El ID del usuario es obligatorio.');
    const username = typeof body.username === 'string'
      ? body.username.trim()
      : undefined;
    if (username !== undefined && !username) {
      throw new Error('El nombre de usuario no puede estar vacío.');
    }

    const attributes: Record<string, unknown> = {};
    if (body.email?.toString().trim()) {
      attributes.email = body.email.toString().trim();
    }
    if (body.password?.toString()) {
      attributes.password = body.password.toString();
    }
    if (typeof body.is_active === 'boolean') {
      if (!body.is_active && userId === callerAuth.user.id) {
        throw new Error('No puedes desactivar tu propia cuenta administrativa.');
      }
      attributes.ban_duration = body.is_active ? 'none' : '876000h';
    }
    if (Object.keys(attributes).length === 0 && username === undefined) {
      throw new Error('No hay cambios para guardar.');
    }

    if (Object.keys(attributes).length > 0) {
      const { error: authError } =
        await adminClient.auth.admin.updateUserById(userId, attributes);
      if (authError) throw authError;
    }

    const profileUpdates: Record<string, unknown> = {};
    if (username !== undefined) profileUpdates.username = username;
    if (typeof body.is_active === 'boolean') {
      profileUpdates.is_active = body.is_active;
    }

    if (Object.keys(profileUpdates).length > 0) {
      const { error: profileErrorUpdate } = await adminClient
        .from('profiles')
        .update(profileUpdates)
        .eq('id', userId);
      if (profileErrorUpdate) throw profileErrorUpdate;
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
