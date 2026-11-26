ALTER TABLE public.billing_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_webhook_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE
  public.billing_subscriptions,
  public.billing_payments,
  public.billing_webhook_events
FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE
  public.billing_subscriptions,
  public.billing_payments,
  public.billing_webhook_events
TO service_role;
