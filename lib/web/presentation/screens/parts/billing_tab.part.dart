part of '../admin_dashboard_screen.dart';

enum _BillingSection { subscriptions, payments, events }

class _BillingTab extends StatefulWidget {
  final AdminService adminService;

  const _BillingTab({required this.adminService});

  @override
  State<_BillingTab> createState() => _BillingTabState();
}

class _BillingTabState extends State<_BillingTab> {
  static const int _pageSize = 25;

  final TextEditingController _searchController = TextEditingController();
  late Future<BillingAdminPage> _pageFuture;
  _BillingSection _section = _BillingSection.subscriptions;
  String _status = 'all';
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageFuture = _loadPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<BillingAdminPage> _loadPage() {
    return widget.adminService.getBillingAdminPage(
      section: _section.name,
      page: _page,
      status: _status,
      search: _searchController.text.trim(),
    );
  }

  void _reload({bool resetPage = false}) {
    if (resetPage) _page = 0;
    setState(() => _pageFuture = _loadPage());
  }

  void _changeSection(_BillingSection section) {
    setState(() {
      _section = section;
      _status = 'all';
      _page = 0;
      _pageFuture = _loadPage();
    });
  }

  void _changePage(int offset) {
    setState(() {
      _page += offset;
      _pageFuture = _loadPage();
    });
  }

  List<String> get _statuses {
    switch (_section) {
      case _BillingSection.subscriptions:
        return const [
          'all',
          'active',
          'trialing',
          'past_due',
          'canceled',
          'unpaid',
          'expired',
          'incomplete',
        ];
      case _BillingSection.payments:
        return const [
          'all',
          'paid',
          'pending',
          'failed',
          'refunded',
          'partially_refunded',
          'disputed',
        ];
      case _BillingSection.events:
        return const ['all', 'pending', 'processed', 'failed'];
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'all':
        return 'Todos los estados';
      case 'active':
        return 'Activa';
      case 'trialing':
        return 'En prueba';
      case 'past_due':
        return 'Pago pendiente';
      case 'canceled':
        return 'Cancelada';
      case 'unpaid':
        return 'Impaga';
      case 'expired':
        return 'Vencida';
      case 'incomplete':
        return 'Incompleta';
      case 'paid':
        return 'Pagado';
      case 'pending':
        return 'Pendiente';
      case 'failed':
        return 'Fallido';
      case 'refunded':
        return 'Reembolsado';
      case 'partially_refunded':
        return 'Reembolso parcial';
      case 'disputed':
        return 'En disputa';
      case 'processed':
        return 'Procesado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(right: 10, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProviderNotice(),
            const SizedBox(height: 18),
            SegmentedButton<_BillingSection>(
              segments: const [
                ButtonSegment(
                  value: _BillingSection.subscriptions,
                  icon: Icon(Icons.autorenew_rounded),
                  label: Text('Suscripciones'),
                ),
                ButtonSegment(
                  value: _BillingSection.payments,
                  icon: Icon(Icons.payments_outlined),
                  label: Text('Pagos'),
                ),
                ButtonSegment(
                  value: _BillingSection.events,
                  icon: Icon(Icons.notifications_active_outlined),
                  label: Text('Eventos'),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (selection) =>
                  _changeSection(selection.first),
            ),
            const SizedBox(height: 18),
            FutureBuilder<BillingAdminPage>(
              future: _pageFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _buildError(snapshot.error);
                }

                final page = snapshot.data;
                if (page == null) {
                  return _buildError(
                    'No se recibió información de facturación.',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMetrics(page.metrics),
                    const SizedBox(height: 22),
                    _buildFilters(),
                    const SizedBox(height: 14),
                    if (page.items.isEmpty)
                      _buildEmptyState()
                    else
                      _buildRecordsTable(page.items),
                    _buildPagination(page.totalCount),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderNotice() {
    // TODO: Conectar checkout y portal de cliente al elegir proveedor.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.info),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Proveedor de pagos pendiente',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Este módulo es de solo lectura. Aún no crea cobros ni '
                  'permite cancelar o reembolsar suscripciones. El MRR se '
                  'habilitará cuando el esquema tenga precios de planes.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(BillingAdminMetrics metrics) {
    final stats = [
      _BillingMetric(
        label: 'Suscripciones con acceso',
        value: metrics.activeSubscriptions,
        icon: Icons.autorenew_rounded,
        color: AppColors.success,
      ),
      _BillingMetric(
        label: 'Suscripciones con pago pendiente',
        value: metrics.pastDueSubscriptions,
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
      ),
      _BillingMetric(
        label: 'Pagos aprobados',
        value: metrics.paidPayments,
        icon: Icons.receipt_long_outlined,
        color: AppColors.primary,
      ),
      _BillingMetric(
        label: 'Pagos fallidos',
        value: metrics.failedPayments,
        icon: Icons.error_outline_rounded,
        color: AppColors.error,
      ),
      _BillingMetric(
        label: 'Eventos por procesar',
        value: metrics.pendingEvents,
        icon: Icons.pending_actions_outlined,
        color: AppColors.info,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1250
            ? 5
            : constraints.maxWidth > 800
            ? 3
            : 2;
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats
              .map((metric) => SizedBox(width: width, child: metric))
              .toList(),
        );
      },
    );
  }

  Widget _buildFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final search = TextField(
          controller: _searchController,
          onSubmitted: (_) => _reload(resetPage: true),
          decoration: InputDecoration(
            hintText: _section == _BillingSection.subscriptions
                ? 'Buscar usuario, plan o ID'
                : 'Buscar registro',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Buscar',
              onPressed: () => _reload(resetPage: true),
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
        );
        final status = DropdownButtonFormField<String>(
          value: _status,
          decoration: const InputDecoration(labelText: 'Estado'),
          items: _statuses
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(_statusLabel(status)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _status = value);
            _reload(resetPage: true);
          },
        );

        if (isNarrow) {
          return Column(
            children: [
              search,
              const SizedBox(height: 10),
              status,
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _reload(resetPage: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 12),
            SizedBox(width: 220, child: status),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: () => _reload(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecordsTable(List<Map<String, dynamic>> items) {
    final columns = switch (_section) {
      _BillingSection.subscriptions => const [
        'Usuario',
        'Plan',
        'Proveedor',
        'Estado',
        'Vigencia',
        'Cancelación',
      ],
      _BillingSection.payments => const [
        'Usuario',
        'Proveedor',
        'ID de pago',
        'Importe',
        'Estado',
        'Fecha',
      ],
      _BillingSection.events => const [
        'Proveedor',
        'ID de evento',
        'Tipo',
        'Procesamiento',
        'Recibido',
      ],
    };

    return Container(
      decoration: AppTheme.cardDecoration(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columns: columns
              .map((label) => DataColumn(label: Text(label)))
              .toList(),
          rows: items
              .map(
                (item) => DataRow(
                  onSelectChanged: (_) => _showRecordDetails(item),
                  cells: _cellsFor(item),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  List<DataCell> _cellsFor(Map<String, dynamic> item) {
    switch (_section) {
      case _BillingSection.subscriptions:
        return [
          DataCell(_userCell(item)),
          DataCell(Text(_text(item['plan_code']))),
          DataCell(Text(_text(item['provider']))),
          DataCell(_statusChip(_text(item['status']))),
          DataCell(Text(_formatDate(item['current_period_end']))),
          DataCell(
            Text(item['cancel_at_period_end'] == true ? 'Al finalizar' : 'No'),
          ),
        ];
      case _BillingSection.payments:
        return [
          DataCell(_userCell(item)),
          DataCell(Text(_text(item['provider']))),
          DataCell(_textCell(item['provider_payment_id'])),
          DataCell(Text(_formatAmount(item))),
          DataCell(_statusChip(_text(item['status']))),
          DataCell(Text(_formatDate(item['paid_at'] ?? item['created_at']))),
        ];
      case _BillingSection.events:
        final processingError = _text(item['processing_error']);
        final processingStatus = processingError != '—'
            ? 'failed'
            : item['processed_at'] == null
            ? 'pending'
            : 'processed';
        return [
          DataCell(Text(_text(item['provider']))),
          DataCell(_textCell(item['provider_event_id'])),
          DataCell(Text(_text(item['event_type']))),
          DataCell(_statusChip(processingStatus)),
          DataCell(Text(_formatDate(item['received_at']))),
        ];
    }
  }

  Widget _userCell(Map<String, dynamic> item) {
    final username = _text(item['username']);
    final userId = _text(item['user_id']);
    final shortId = userId.length > 8 ? userId.substring(0, 8) : userId;

    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            username == '—' ? 'Usuario' : username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            shortId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _textCell(Object? value) {
    return SizedBox(
      width: 180,
      child: Text(_text(value), maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'active' || 'paid' || 'processed' => AppColors.success,
      'past_due' || 'pending' || 'trialing' => AppColors.warning,
      'failed' || 'unpaid' || 'disputed' => AppColors.error,
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Widget _buildPagination(int totalCount) {
    final firstItem = totalCount == 0 ? 0 : _page * _pageSize + 1;
    final lastItem = (_page + 1) * _pageSize < totalCount
        ? (_page + 1) * _pageSize
        : totalCount;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$firstItem–$lastItem de $totalCount',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          IconButton(
            tooltip: 'Página anterior',
            onPressed: _page > 0 ? () => _changePage(-1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Página siguiente',
            onPressed: lastItem < totalCount ? () => _changePage(1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 18),
      decoration: AppTheme.cardDecoration(),
      child: const Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 36,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 12),
          Text(
            'No hay registros para mostrar.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No se pudo cargar la información de facturación.',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            error?.toString() ?? 'Error desconocido.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _reload(),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRecordDetails(Map<String, dynamic> item) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Detalle del registro',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: item.entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 160,
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SelectableText(
                              _text(entry.value),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _formatAmount(Map<String, dynamic> item) {
    final amount = _text(item['amount_minor']);
    final currency = _text(item['currency']);
    return amount == '—' ? amount : '$amount $currency (u.m.)';
  }

  String _formatDate(Object? value) {
    if (value == null) return '—';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }

  String _text(Object? value) {
    if (value == null) return '—';
    final text = value.toString().trim();
    return text.isEmpty ? '—' : text;
  }
}

class _BillingMetric extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _BillingMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
