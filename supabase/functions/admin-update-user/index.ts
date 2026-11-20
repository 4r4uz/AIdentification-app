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
    const username = body.username?.toString().trim();
    if (!userId) throw new Error('El ID del usuario es obligatorio.');
    if (!username) throw new Error('El nombre de usuario es obligatorio.');

    const attributes: Record<string, unknown> = {};
    if (body.email?.toString().trim()) {
      attributes.email = body.email.toString().trim();
    }
    if (body.password?.toString()) {
      attributes.password = body.password.toString();
    }

    if (Object.keys(attributes).length > 0) {
      const { error: authError } =
        await adminClient.auth.admin.updateUserById(userId, attributes);
      if (authError) throw authError;
    }

    const { error: profileErrorUpdate } = await adminClient
      .from('profiles')
      .update({ username })
      .eq('id', userId);
    if (profileErrorUpdate) throw profileErrorUpdate;

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
