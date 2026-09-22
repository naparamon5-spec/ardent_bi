import 'dart:math';

/// Canned responses so the UI can be browsed without a backend ("demo mode").
/// Shapes match the real API exactly, so screens render as they would live.
/// This is presentation-only sample data — nothing here reaches a server.
class DemoData {
  static final _rng = Random(7);

  static const _brands = [
    'Fortinet', 'Cisco', 'HPE Aruba', 'Palo Alto', 'Juniper',
    'Ubiquiti', 'Dell', 'Microsoft', 'VMware', 'Veeam',
    'Sophos', 'NetApp',
  ];
  static const _salesmen = [
    'ELIZA-T', 'JACQUIE-A', 'ROWENA-T', 'SHEILLA-Y', 'JOSE-G',
    'MARIA-A', 'ANN-A2', 'PEDRO-S', 'LUIS-M', 'GINA-R',
  ];
  static const _customers = [
    'Globe Telecom', 'PLDT Enterprise', 'BPI', 'Meralco', 'SM Retail',
    'Ayala Land', 'San Miguel Corp', 'Jollibee Foods', 'Aboitiz', 'DOST',
  ];
  static const _pgroups = ['Networking', 'Security', 'Wireless', 'Servers', 'Storage', 'Software'];
  static const _pmanagers = ['Team Alpha', 'Team Bravo', 'Team Charlie', 'Unassigned'];
  static const _warehouses = ['Main DC', 'Cebu Hub', 'Davao Hub', 'Transit'];

  static double _val(double base, double spread) => base + _rng.nextDouble() * spread;

  static Map<String, dynamic> _agg(double sales) {
    final gp = sales * (0.14 + _rng.nextDouble() * 0.12);
    final invoices = (sales / 380000).round() + 3;
    return {
      'sales': sales,
      'cost': sales - gp,
      'grossProfit': gp,
      'qty': (sales / 45000).round() + 20,
      'lines': (sales / 120000).round() + 5,
      'invoices': invoices,
      'customers': (sales / 900000).round() + 2,
      'skus': (sales / 200000).round() + 8,
      'gmPercent': sales != 0 ? gp / sales * 100 : 0,
      'avgInvoice': invoices == 0 ? 0.0 : sales / invoices,
    };
  }

  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// Trend points for a grain, every measure key on each point so the measure
  /// picker can re-read the same series without another shape.
  static List<Map<String, dynamic>> _seriesPoints(String grain) {
    final now = DateTime.now();
    switch (grain) {
      case 'day':
        final out = <Map<String, dynamic>>[];
        for (var i = 13; i >= 0; i--) {
          final d = now.subtract(Duration(days: i));
          out.add({
            'label': '${d.day.toString().padLeft(2, '0')} ${_monthNames[d.month - 1]}',
            ..._agg(_val(2.6e5, 3.4e5)),
          });
        }
        return out;
      case 'quarter':
        final q = (now.month - 1) ~/ 3 + 1;
        return [for (var i = 1; i <= q; i++) {'label': 'Q$i ${now.year}', ..._agg(_val(2.0e7, 1.6e7))}];
      case 'year':
        return [
          for (var y = now.year - 3; y <= now.year; y++) {'label': '$y', ..._agg(_val(7.5e7, 3.5e7))},
        ];
      default:
        return [
          for (var i = 1; i <= now.month; i++) {'label': '${_monthNames[i - 1]} ${now.year}', ..._agg(_val(6e6, 8e6))},
        ];
    }
  }

  static List<Map<String, dynamic>> _breakdownRows(List<String> names, {double base = 8e6}) {
    final rows = names
        .map((n) => {'name': n, ..._agg(_val(base, base * 2.5))})
        .toList()
      ..sort((a, b) => (b['sales'] as double).compareTo(a['sales'] as double));
    return rows;
  }

  /// Resolve an endpoint to a canned response. Returns null when unknown.
  static dynamic resolve(String path, Object? body) {
    if (path.startsWith('/api/auth/login')) {
      return {
        'token': 'demo-token',
        'user': {'id': 0, 'username': 'demo', 'name': 'Demo User', 'role': 'admin'},
      };
    }
    if (path.startsWith('/api/auth/me')) {
      return {
        'user': {'id': 0, 'username': 'demo', 'name': 'Demo User', 'role': 'admin'},
        'access': {'enforced': false, 'deny': false, 'level': 'executive'},
      };
    }
    if (path.startsWith('/api/auth/logout')) return {'ok': true};

    if (path == '/api/sales/meta') {
      return {
        'dimensions': const [
          {'key': 'brand', 'label': 'Brand'},
          {'key': 'className', 'label': 'Class'},
          {'key': 'productGroup', 'label': 'Product Group'},
          {'key': 'productManager', 'label': 'Product Manager'},
          {'key': 'category', 'label': 'Category'},
          {'key': 'businessUnit', 'label': 'Business Unit'},
          {'key': 'salesGroup', 'label': 'Sales Group'},
          {'key': 'salesman', 'label': 'Salesman'},
          {'key': 'customer', 'label': 'Customer'},
          {'key': 'customerGroup', 'label': 'Customer Group'},
          {'key': 'transactionType', 'label': 'Transaction Type'},
          {'key': 'item', 'label': 'Item'},
        ],
        'measures': const [
          {'key': 'sales', 'label': 'Net Sales', 'format': 'currency'},
          {'key': 'cost', 'label': 'Cost', 'format': 'currency'},
          {'key': 'grossProfit', 'label': 'Gross Profit', 'format': 'currency'},
          {'key': 'qty', 'label': 'Quantity', 'format': 'number'},
          {'key': 'invoices', 'label': 'Invoices', 'format': 'number'},
          {'key': 'customers', 'label': 'Active Customers', 'format': 'number'},
          {'key': 'lines', 'label': 'Transaction Lines', 'format': 'number'},
        ],
        'grains': const ['day', 'month', 'quarter', 'year'],
      };
    }

    if (path == '/api/sales/kpis') {
      final cur = _agg(_val(84e6, 22e6));
      return {
        'current': cur,
        'delta': {
          'sales': _val(-6, 26),
          'grossProfit': _val(-4, 22),
          'gmPercent': _val(-1.5, 3),
          'invoices': _val(-8, 20),
          'customers': _val(-3, 12),
          'qty': _val(-5, 18),
        },
      };
    }

    if (path == '/api/sales/timeseries') {
      final grain = _bodyStr(body, 'grain', 'month');
      final measure = _bodyStr(body, 'measure', 'sales');
      return {'grain': grain, 'measure': measure, 'points': _seriesPoints(grain)};
    }

    if (path == '/api/sales/breakdown') {
      final dim = _bodyStr(body, 'dimension', 'brand');
      final names = _namesFor(dim);
      return {
        'dimension': dim,
        'rows': _breakdownRows(names),
        'coverage': 92.0,
      };
    }

    if (path == '/api/sales/movers') {
      final rows = _brands
          .take(8)
          .map((n) => {'name': n, 'delta': _val(-9e6, 18e6)})
          .toList()
        ..sort((a, b) => (b['delta'] as double).abs().compareTo((a['delta'] as double).abs()));
      return {'rows': rows, 'priorHasData': true, 'window': {'current': {'min': '2026-01-01'}}};
    }

    if (path == '/api/sales/insights') {
      return {
        'insights': [
          {
            'id': 'latest-change',
            'severity': 'good',
            'title': 'Net sales up 12.4% on the prior period',
            'detail': 'Nine brands contributed; Fortinet and Cisco account for most of the gain.',
            'metrics': {'delta': 12.4},
          },
          {
            'id': 'trend',
            'severity': 'good',
            'title': 'Third straight month of growth',
            'detail': 'Net sales have risen every month since June — the longest run this year.',
            'metrics': {'months': 3},
          },
          {
            'id': 'outlier',
            'severity': 'serious',
            'title': 'Ubiquiti gross margin slipped to 6.1%',
            'detail': 'Well below the 18.4% company average. Worth checking discounting on recent invoices.',
            'metrics': {'gmPercent': 6.1},
          },
          {
            'id': 'half-shift',
            'severity': 'good',
            'title': 'Second half of the window ahead by 35.4%',
            'detail': 'Comparing the two halves of the selected range isolates a genuine level shift from period-to-period noise.',
            'metrics': {'shift': 35.4},
          },
          {
            'id': 'forecast',
            'severity': 'info',
            'title': 'Next three periods projected',
            'detail': 'Holt linear exponential smoothing on the visible series, with a ±1σ band from the fit residuals.',
            'metrics': {},
          },
          {
            'id': 'leader',
            'severity': 'info',
            'title': 'Fortinet leads with 22.8% of the total',
            'detail': 'Brand "Fortinet" contributes ₱41.2 M of ₱180.6 M.',
            'metrics': {'share': 22.8},
          },
          {
            'id': 'concentration',
            'severity': 'warning',
            'title': '3 of 12 brands drive 80% of the total',
            'detail': 'That is heavy concentration — the top 25% carries four fifths of the business, so losing one of them hurts disproportionately.',
            'metrics': {'members': 3, 'concentration': 25.0},
          },
          {
            'id': 'margin-spread',
            'severity': 'serious',
            'title': 'Margin ranges from 4.2% (Ubiquiti) to 27.6% (Cisco)',
            'detail': 'Revenue and profit are not moving together across brands — a revenue-only view would hide it.',
            'metrics': {'low': 4.2, 'high': 27.6},
          },
          {
            'id': 'negatives',
            'severity': 'serious',
            'title': '1 brand with a negative total',
            'detail': 'Net credit memos or reversals exceed sales for: Meraki.',
            'metrics': {'count': 1},
          },
          {
            'id': 'range',
            'severity': 'info',
            'title': 'Comparing Jan–Sep 2026 with the same months of 2025',
            'detail': 'The prior year is trimmed to the elapsed months so the read is like-for-like.',
            'metrics': {},
          },
        ],
      };
    }

    if (path == '/api/sales/pivot') {
      const cols = ['Q1', 'Q2', 'Q3'];
      final rowDim = _bodyStr(body, 'rows', 'brand');
      final rows = _namesFor(rowDim).map((n) {
        final values = [
          for (var q = 0; q < cols.length; q++)
            _rng.nextDouble() < 0.25 ? 0.0 : _val(1.6e6, 5.4e6),
        ];
        final total = values.fold<double>(0, (a, b) => a + b);
        return {'name': n, 'values': values, 'total': total};
      }).toList()
        ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
      final columnTotals = [
        for (var q = 0; q < cols.length; q++)
          rows.fold<double>(0, (a, r) => a + (r['values'] as List<double>)[q]),
      ];
      return {
        'measure': _bodyStr(body, 'measure', 'sales'),
        'rowDimension': rowDim,
        'colDimension': 'quarter',
        'columns': cols,
        'rows': rows,
        'columnTotals': columnTotals,
        'grandTotal': columnTotals.fold<double>(0, (a, b) => a + b),
      };
    }

    if (path == '/api/sales/pareto') {
      final dim = _bodyStr(body, 'dimension', 'customer');
      final measure = _bodyStr(body, 'measure', 'sales');
      final ranked = _namesFor(dim)
          .map((n) => {'name': n, 'v': _val(1e6, 9e6)})
          .toList()
        ..sort((a, b) => (b['v'] as double).compareTo(a['v'] as double));
      // Real rankings are top-heavy; dampen each step so the curve reads like one.
      for (var i = 0; i < ranked.length; i++) {
        ranked[i]['v'] = (ranked[i]['v'] as double) / (1 + i * 0.9);
      }
      final total = ranked.fold<double>(0, (a, r) => a + (r['v'] as double));
      var cum = 0.0;
      final counts = {'A': 0, 'B': 0, 'C': 0};
      final values = {'A': 0.0, 'B': 0.0, 'C': 0.0};
      final rows = ranked.map((r) {
        final v = r['v'] as double;
        cum += v;
        final share = cum / total * 100;
        final cls = share <= 80 ? 'A' : (share <= 95 ? 'B' : 'C');
        counts[cls] = counts[cls]! + 1;
        values[cls] = values[cls]! + v;
        return {'name': r['name'], measure: v, 'cumulative': share};
      }).toList();
      return {
        'dimension': dim,
        'measure': measure,
        'rows': rows,
        'classes': [
          for (final c in const ['A', 'B', 'C'])
            {'class': c, 'count': counts[c], 'share': values[c]! / total * 100, 'value': values[c]},
        ],
      };
    }

    if (path == '/api/sales/detail') {
      final page = (body is Map && body['page'] is num) ? (body['page'] as num).toInt() : 1;
      final sortBy = _bodyStr(body, 'sortBy', 'date');
      final sortDir = _bodyStr(body, 'sortDir', 'desc');
      final rng = Random(7 + page * 31);
      final rows = List.generate(25, (i) {
        final s = 120000 + rng.nextDouble() * 900000;
        final gp = s * (0.1 + rng.nextDouble() * 0.2);
        final brand = _brands[i % _brands.length];
        return {
          'date': '2026-0${1 + i % 9}-${(1 + i % 27).toString().padLeft(2, '0')}',
          'invoice': '${159700 + i + (page - 1) * 25}',
          'customer': _customers[i % _customers.length],
          'brand': brand,
          'salesman': _salesmen[i % _salesmen.length],
          'item': '${brand.substring(0, 3).toUpperCase()}PRD${1000 + i}',
          'sales': s,
          'grossProfit': gp,
          'gmPercent': gp / s * 100,
          'qty': 1 + i % 12,
        };
      });
      rows.sort((a, b) {
        final av = a[sortBy];
        final bv = b[sortBy];
        final c = av is num && bv is num
            ? av.compareTo(bv)
            : '$av'.compareTo('$bv');
        return sortDir == 'asc' ? c : -c;
      });
      return {'rows': rows, 'total': 4821, 'page': page, 'pageSize': 25};
    }

    if (path == '/api/sales/export') {
      const cols = ['date', 'invoice', 'customer', 'salesman', 'brand', 'item', 'qty', 'sales', 'grossProfit', 'gmPercent'];
      final detail = resolve('/api/sales/detail', {'page': 1, 'sortBy': 'date', 'sortDir': 'desc'}) as Map;
      final lines = <String>[cols.join(',')];
      for (final r in (detail['rows'] as List).cast<Map>()) {
        lines.add(cols.map((c) {
          final v = r[c];
          final s = v is num ? v.toStringAsFixed(2) : '${v ?? ''}';
          return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
        }).join(','));
      }
      return lines.join('\n');
    }

    if (path.startsWith('/api/sales/options/')) {
      final dim = path.split('/').last;
      return {'dimension': dim, 'values': _namesFor(dim)};
    }

    if (path == '/api/inventory/kpis') {
      const ageLabels = ['0–30', '31–60', '61–90', '91–120', '121–180', '181–365', '365+'];
      final ageing = List.generate(ageLabels.length, (i) {
        return {'label': ageLabels[i], 'days': (i + 1) * 30, 'value': _val(3e6, 12e6) / (i + 1)};
      });
      final total = ageing.fold<double>(0, (s, b) => s + (b['value'] as double));
      final over90 = ageing.skip(3).fold<double>(0, (s, b) => s + (b['value'] as double));
      final slow = ageing.skip(5).fold<double>(0, (s, b) => s + (b['value'] as double));
      return {
        'value': total,
        'skus': 1440,
        'ageing': ageing,
        'over90Value': over90,
        'over90Share': total == 0 ? 0 : over90 / total * 100,
        'slowMovingShare': total == 0 ? 0 : slow / total * 100,
        'deadStock': {'skus': 186, 'value': _val(4e6, 6e6)},
      };
    }

    if (path == '/api/inventory/breakdown') {
      final dim = _bodyStr(body, 'dimension', 'brand');
      final names = _namesFor(dim);
      final rows = names
          .map((n) => {'name': n, 'value': _val(2e6, 9e6), 'qty': 50 + _rng.nextInt(400)})
          .toList()
        ..sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
      return {'dimension': dim, 'rows': rows};
    }

    if (path.startsWith('/api/inventory/options/')) {
      final dim = path.split('/').last;
      return {'dimension': dim, 'values': _namesFor(dim)};
    }

    // ── Re-Order Point ────────────────────────────────────────────────
    if (path == '/api/reorder-point/kpis') {
      const items = 1440;
      const toOrder = 312;
      return {
        'items': items,
        'brands': 12,
        'onHand': 48210,
        'backOrder': 1820,
        'forecast': 9640,
        'safetyStock': 5200,
        'itemsToOrder': toOrder,
        'belowRop': 274,
        'amount': _val(31e6, 14e6),
        'onHandAmount': _val(97e6, 20e6),
        'itemsWithoutCost': 41,
        'toOrderShare': toOrder / items * 100,
        'belowRopShare': 274 / items * 100,
      };
    }
    if (path == '/api/reorder-point/breakdown') {
      final dim = _bodyStr(body, 'dimension', 'brand');
      final names = _namesFor(dim);
      final rows = names
          .map((n) => {'name': n, 'forecast': (30 + _rng.nextInt(900)).toDouble(), 'amount': _val(1e6, 6e6), 'items': 10 + _rng.nextInt(120)})
          .toList()
        ..sort((a, b) => (b['forecast'] as double).compareTo(a['forecast'] as double));
      return {'dimension': dim, 'rows': rows};
    }
    if (path == '/api/reorder-point/detail') {
      final rows = List.generate(25, (i) {
        final toOrder = 5 + _rng.nextInt(120);
        return {
          'item': 'FORPRD${(1000 + i).toString()}',
          'itemDescription': '${_brands[i % _brands.length]} module ${100 + i}',
          'brand': _brands[i % _brands.length],
          'onHand': _rng.nextInt(60),
          'backOrder': _rng.nextInt(10),
          'rop': 20 + _rng.nextInt(40),
          'forecast': toOrder,
          'orderAmount': _val(50000, 400000),
        };
      });
      return {'rows': rows, 'total': 312, 'page': 1, 'pageSize': 25};
    }
    if (path.startsWith('/api/reorder-point/options/')) {
      final dim = path.split('/').last;
      return {'dimension': dim, 'values': _namesFor(dim)};
    }

    // ── Accrued Incidentals ───────────────────────────────────────────
    if (path == '/api/accrued/kpis') {
      final amount = _val(6e6, 4e6);
      final joAmount = amount / (0.06 + _rng.nextDouble() * 0.04);
      final jobOrders = 480 + _rng.nextInt(200);
      return {
        'amount': amount,
        'lines': 2400 + _rng.nextInt(600),
        'jobOrders': jobOrders,
        'joAmount': joAmount,
        'incidentalRate': amount / joAmount * 100,
        'avgPerJobOrder': amount / jobOrders,
        'currency': 'PHP',
      };
    }
    if (path == '/api/accrued/timeseries') {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'];
      final points = months.map((m) {
        final amount = _val(4e5, 5e5);
        return {'label': m, 'amount': amount, 'rate': 4 + _rng.nextDouble() * 6, 'lines': 200 + _rng.nextInt(120)};
      }).toList();
      return {'points': points};
    }
    if (path == '/api/accrued/breakdown') {
      final dim = _bodyStr(body, 'dimension', 'brand');
      final names = _namesFor(dim);
      final rows = names
          .map((n) => {'name': n, 'amount': _val(2e5, 1.2e6), 'lines': 20 + _rng.nextInt(200)})
          .toList()
        ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
      return {'dimension': dim, 'rows': rows};
    }
    if (path.startsWith('/api/accrued/options/')) {
      final dim = path.split('/').last;
      return {'dimension': dim, 'values': _namesFor(dim)};
    }

    // ── Period comparison (Period reports) ────────────────────────────
    if (path == '/api/sales/comparison') {
      final mode = _bodyStr(body, 'mode', 'yoy');
      if (mode == 'mom') {
        final now = DateTime.now();
        final months = [for (var i = 0; i < 14; i++) _val(6e6, 8e6)];
        double? g(double? c, double? p) =>
            (c == null || p == null || p == 0) ? null : (c - p) / p.abs() * 100;
        final rows = <Map<String, dynamic>>[];
        for (var i = 1; i < months.length; i++) {
          final back = months.length - 1 - i;
          final d = DateTime(now.year, now.month - back, 1);
          final p = DateTime(now.year, now.month - back - 1, 1);
          final cur = _agg(months[i]);
          final pr = _agg(months[i - 1]);
          rows.add({
            'periodKey': '${d.year}-${d.month.toString().padLeft(2, '0')}',
            'label': '${_monthNames[d.month - 1]} ${d.year}',
            'comparedTo': '${p.year}-${p.month.toString().padLeft(2, '0')}',
            'partial': i == months.length - 1,
            'current': cur,
            'prior': pr,
            'growth': {
              'sales': g(months[i], months[i - 1]),
              'grossProfit': g(cur['grossProfit'] as double, pr['grossProfit'] as double),
              'gmPercent': (cur['gmPercent'] as double) - (pr['gmPercent'] as double),
            },
          });
        }
        return {'mode': mode, 'rows': rows, 'summary': null};
      }
      final labels = mode == 'yoy'
          ? ['2023', '2024', '2025', '2026']
          : ['Q2 2025', 'Q3 2025', 'Q4 2025', 'Q1 2026', 'Q2 2026'];
      double prevSales = _val(60e6, 20e6);
      final rows = labels.map((l) {
        final s = prevSales * (0.9 + _rng.nextDouble() * 0.4);
        final prior = prevSales;
        prevSales = s;
        final cur = _agg(s);
        final pr = _agg(prior);
        double? g(double c, double p) => p == 0 ? null : (c - p) / p.abs() * 100;
        return {
          'periodKey': l,
          'label': l,
          'current': cur,
          'prior': pr,
          'growth': {
            'sales': g(s, prior),
            'grossProfit': g(cur['grossProfit'] as double, pr['grossProfit'] as double),
          },
        };
      }).toList();
      return {'mode': mode, 'rows': rows, 'summary': null};
    }

    return {};
  }

  static List<String> _namesFor(String dim) {
    switch (dim) {
      case 'salesman':
        return List.of(_salesmen);
      case 'customer':
        return List.of(_customers);
      case 'productGroup':
        return List.of(_pgroups);
      case 'productManager':
        return List.of(_pmanagers);
      case 'salesGroup':
        return const ['North', 'South', 'Metro', 'Visayas', 'Mindanao'];
      case 'warehouse':
        return List.of(_warehouses);
      case 'type':
        return const ['Freight', 'Handling', 'Installation', 'Customs', 'Insurance', 'Storage'];
      default:
        return List.of(_brands);
    }
  }

  static String _bodyStr(Object? body, String key, String fallback) {
    if (body is Map && body[key] != null) return body[key].toString();
    return fallback;
  }
}
