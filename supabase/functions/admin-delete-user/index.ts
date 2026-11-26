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
    if (!authorization) throw new Error('Sesión requerida.');

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
      throw new Error('Solo administradores pueden eliminar usuarios.');
    }

    const body = await req.json();
    const userId = body.user_id?.toString();
    if (!userId) throw new Error('El ID del usuario es obligatorio.');
    if (userId === callerAuth.user.id) {
      throw new Error('No puedes eliminar tu propia cuenta administrativa.');
    }

    const relatedRows = await Promise.all([
      adminClient.from('detections').select('id', { count: 'exact', head: true }).eq('user_id', userId),
      adminClient.from('user_trivia_progress').select('user_id', { count: 'exact', head: true }).eq('user_id', userId),
      adminClient.from('user_achievements').select('user_id', { count: 'exact', head: true }).eq('user_id', userId),
      adminClient.from('trivia_attempts').select('id', { count: 'exact', head: true }).eq('user_id', userId),
      adminClient.from('billing_subscriptions').select('id', { count: 'exact', head: true }).eq('user_id', userId),
      adminClient.from('billing_payments').select('id', { count: 'exact', head: true }).eq('user_id', userId),
    ]);

    const failedCheck = relatedRows.find((result) => result.error);
    if (failedCheck?.error) throw failedCheck.error;

    if (relatedRows.some((result) => (result.count ?? 0) > 0)) {
      throw new Error(
        'Esta cuenta tiene actividad o historial de facturación asociado. '
        + 'Desactívala para conservar esos registros.',
      );
    }

    const { error: profileDeleteError } = await adminClient
      .from('profiles')
      .delete()
      .eq('id', userId);
    if (profileDeleteError) throw profileDeleteError;

    const { error: authDeleteError } =
      await adminClient.auth.admin.deleteUser(userId);
    if (authDeleteError) throw authDeleteError;

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
