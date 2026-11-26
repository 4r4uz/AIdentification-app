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
      throw new Error('Solo administradores pueden crear usuarios.');
    }

    const body = await req.json();
    const email = body.email?.toString().trim();
    const password = body.password?.toString();
    const username = body.username?.toString().trim();

    if (!email) throw new Error('El correo es obligatorio.');
    if (!password || password.length < 6) {
      throw new Error('La contraseña debe tener al menos 6 caracteres.');
    }
    if (!username) throw new Error('El nombre de usuario es obligatorio.');

    const { data, error } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { username },
    });
    if (error || !data.user) throw error ?? new Error('No se pudo crear el usuario.');

    const { error: profileErrorCreate } = await adminClient
      .from('profiles')
      .upsert({
        id: data.user.id,
        username,
        role: 'user',
        is_active: true,
      });
    if (profileErrorCreate) throw profileErrorCreate;

    return new Response(
      JSON.stringify({ success: true, id: data.user.id }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
