import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type BillingSection = 'subscriptions' | 'payments' | 'events';

const tableBySection: Record<BillingSection, string> = {
  subscriptions: 'billing_subscriptions',
  payments: 'billing_payments',
  events: 'billing_webhook_events',
};

class RequestError extends Error {
  readonly status: number;

  constructor(
    message: string,
    status: number,
  ) {
    super(message);
    this.status = status;
  }
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function getCount(query: PromiseLike<{
  count: number | null;
  error: { message: string } | null;
}>): Promise<number> {
  const { count, error } = await query;
  if (error) throw new Error(error.message);
  return count ?? 0;
}

async function getMetrics(adminClient: ReturnType<typeof createClient>) {
  const [
    activeSubscriptions,
    trialingSubscriptions,
    pastDueSubscriptions,
    paidPayments,
    failedPayments,
    pendingEvents,
  ] = await Promise.all([
    getCount(
      adminClient
        .from('billing_subscriptions')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'active'),
    ),
    getCount(
      adminClient
        .from('billing_subscriptions')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'trialing'),
    ),
    getCount(
      adminClient
        .from('billing_subscriptions')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'past_due'),
    ),
    getCount(
      adminClient
        .from('billing_payments')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'paid'),
    ),
    getCount(
      adminClient
        .from('billing_payments')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'failed'),
    ),
    getCount(
      adminClient
        .from('billing_webhook_events')
        .select('id', { count: 'exact', head: true })
        .is('processed_at', null),
    ),
  ]);

  return {
    active_subscriptions: activeSubscriptions + trialingSubscriptions,
    past_due_subscriptions: pastDueSubscriptions,
    paid_payments: paidPayments,
    failed_payments: failedPayments,
    pending_events: pendingEvents,
  };
}

async function findMatchingIds(
  adminClient: ReturnType<typeof createClient>,
  section: BillingSection,
  search: string,
): Promise<string[]> {
  if (!search) return [];

  const table = tableBySection[section];
  const columns = {
    subscriptions: ['provider_subscription_id', 'plan_code', 'provider'],
    payments: ['provider_payment_id', 'provider', 'status', 'currency'],
    events: ['provider_event_id', 'event_type', 'provider', 'processing_error'],
  }[section];
  const pattern = `%${search.replace(/[\\%_]/g, '\\$&')}%`;
  const matchingIds = new Set<string>();

  const columnResults = await Promise.all(
    columns.map((column) =>
      adminClient
        .from(table)
        .select('id')
        .ilike(column, pattern)
        .limit(500),
    ),
  );
  for (const result of columnResults) {
    if (result.error) throw new Error(result.error.message);
    for (const row of result.data ?? []) {
      matchingIds.add(String(row.id));
    }
  }

  if (section !== 'events') {
    const userIds = new Set<string>();
    if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(search)) {
      userIds.add(search);
    }

    const profileResult = await adminClient
      .from('profiles')
      .select('id')
      .ilike('username', pattern)
      .limit(500);
    if (profileResult.error) throw new Error(profileResult.error.message);
    for (const profile of profileResult.data ?? []) {
      userIds.add(String(profile.id));
    }

    if (userIds.size > 0) {
      const userResult = await adminClient
        .from(table)
        .select('id')
        .in('user_id', [...userIds])
        .limit(500);
      if (userResult.error) throw new Error(userResult.error.message);
      for (const row of userResult.data ?? []) {
        matchingIds.add(String(row.id));
      }
    }
  }

  return [...matchingIds];
}

async function getPage(
  adminClient: ReturnType<typeof createClient>,
  section: BillingSection,
  status: string,
  search: string,
  page: number,
  pageSize: number,
) {
  const table = tableBySection[section];
  const matchingIds = await findMatchingIds(adminClient, section, search);

  if (search && matchingIds.length === 0) {
    return { items: [], total_count: 0 };
  }

  let query = adminClient.from(table).select('*', { count: 'exact' });
  if (search) query = query.in('id', matchingIds);

  if (section === 'events') {
    if (status === 'processed') query = query.not('processed_at', 'is', null);
    if (status === 'pending') {
      query = query.is('processed_at', null).is('processing_error', null);
    }
    if (status === 'failed') {
      query = query.not('processing_error', 'is', null);
    }
  } else if (status !== 'all') {
    query = query.eq('status', status);
  }

  const orderColumn = section === 'subscriptions'
    ? 'created_at'
    : section === 'payments'
    ? 'created_at'
    : 'received_at';
  const from = page * pageSize;
  const { data, error, count } = await query
    .order(orderColumn, { ascending: false })
    .range(from, from + pageSize - 1);
  if (error) throw new Error(error.message);

  const items = (data ?? []) as Array<Record<string, unknown>>;
  if (section !== 'events') {
    const userIds = [...new Set(
      items
        .map((item) => item.user_id)
        .filter((userId): userId is string => typeof userId === 'string'),
    )];
    if (userIds.length > 0) {
      const profilesResult = await adminClient
        .from('profiles')
        .select('id, username')
        .in('id', userIds);
      if (profilesResult.error) throw new Error(profilesResult.error.message);
      const usernames = new Map(
        (profilesResult.data ?? []).map((profile) => [
          String(profile.id),
          profile.username,
        ]),
      );
      for (const item of items) {
        item.username = usernames.get(String(item.user_id)) ?? null;
      }
    }
  }

  return { items, total_count: count ?? items.length };
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Método no permitido.' }, 405);
  }

  try {
    const authorization = request.headers.get('Authorization') ?? '';
    if (!authorization.startsWith('Bearer ')) {
      throw new RequestError('Sesión requerida.', 401);
    }
    const token = authorization.slice('Bearer '.length);
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      throw new Error('Falta configuración de Supabase en la función.');
    }

    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: callerAuth, error: callerAuthError } =
      await callerClient.auth.getUser(token);
    if (callerAuthError || !callerAuth.user) {
      throw new RequestError('Sesión administrativa inválida.', 401);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: callerProfile, error: profileError } = await adminClient
      .from('profiles')
      .select('role')
      .eq('id', callerAuth.user.id)
      .maybeSingle();
    if (profileError) throw new Error(profileError.message);
    if (callerProfile?.role !== 'admin') {
      throw new RequestError('Solo administradores pueden consultar pagos.', 403);
    }

    let body: Record<string, unknown>;
    try {
      body = await request.json();
    } catch {
      throw new RequestError('El cuerpo de la solicitud no es válido.', 400);
    }

    const section = body.section;
    if (
      section !== 'subscriptions' &&
      section !== 'payments' &&
      section !== 'events'
    ) {
      throw new RequestError('La sección solicitada no es válida.', 400);
    }

    const rawPage = typeof body.page === 'number' ? body.page : Number.NaN;
    const rawPageSize = typeof body.page_size === 'number'
      ? body.page_size
      : Number.NaN;
    const page = Number.isInteger(rawPage) && rawPage >= 0 ? rawPage : 0;
    const pageSize = Number.isInteger(rawPageSize)
      ? Math.min(Math.max(rawPageSize, 1), 100)
      : 25;
    const status = typeof body.status === 'string' ? body.status : 'all';
    const allowedStatuses = {
      subscriptions: [
        'all', 'active', 'trialing', 'past_due', 'canceled', 'unpaid',
        'expired', 'incomplete',
      ],
      payments: [
        'all', 'paid', 'pending', 'failed', 'refunded', 'partially_refunded',
        'disputed',
      ],
      events: ['all', 'pending', 'processed', 'failed'],
    } satisfies Record<BillingSection, string[]>;
    if (!allowedStatuses[section].includes(status)) {
      throw new RequestError('El filtro de estado no es válido.', 400);
    }
    const search = typeof body.search === 'string'
      ? body.search.trim().slice(0, 100)
      : '';

    const [metrics, result] = await Promise.all([
      getMetrics(adminClient),
      getPage(adminClient, section, status, search, page, pageSize),
    ]);

    return jsonResponse({
      metrics,
      items: result.items,
      total_count: result.total_count,
      page,
      page_size: pageSize,
    });
  } catch (error) {
    if (error instanceof RequestError) {
      return jsonResponse({ error: error.message }, error.status);
    }
    console.error('[admin-billing] No se pudo consultar la facturación:', error);
    const message = error instanceof Error
      ? error.message
      : 'Error interno al consultar la facturación.';
    return jsonResponse({ error: message }, 500);
  }
});
