import 'dart:math';

/// Canned responses so the UI can be browsed without a backend. Shapes match
/// the API so screens render as they would live. Presentation-only sample data.
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
    return {
      'sales': sales,
      'grossProfit': gp,
      'qty': (sales / 45000).round() + 20,
      'lines': (sales / 120000).round() + 5,
      'invoices': (sales / 380000).round() + 3,
      'customers': (sales / 900000).round() + 2,
      'skus': (sales / 200000).round() + 8,
      'gmPercent': sales != 0 ? gp / sales * 100 : 0,
    };
  }

  static List<Map<String, dynamic>> _breakdownRows(List<String> names, {double base = 8e6}) {
    final rows = names.map((n) => {'name': n, ..._agg(_val(base, base * 2.5))}).toList()
      ..sort((a, b) => (b['sales'] as double).compareTo(a['sales'] as double));
    return rows;
  }

  static dynamic resolve(String path, Object? body) {
    if (path.startsWith('/api/auth/login')) {
      return {'token': 'demo-token', 'user': {'id': 0, 'username': 'demo', 'name': 'Demo User', 'role': 'admin'}};
    }
    if (path.startsWith('/api/auth/me')) {
      return {
        'user': {'id': 0, 'username': 'demo', 'name': 'Demo User', 'role': 'admin'},
        'access': {'enforced': false, 'deny': false, 'level': 'executive'},
      };
    }
    if (path.startsWith('/api/auth/logout')) return {'ok': true};

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
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'];
      final points = months.map((m) {
        final s = _val(6e6, 8e6);
        final a = _agg(s);
        return {'label': m, 'sales': s, 'grossProfit': a['grossProfit'], 'qty': a['qty']};
      }).toList();
      return {'grain': 'month', 'points': points};
    }
    if (path == '/api/sales/breakdown') {
      final dim = _bodyStr(body, 'dimension', 'brand');
      return {'dimension': dim, 'rows': _breakdownRows(_namesFor(dim)), 'coverage': 92.0};
    }
    if (path == '/api/sales/movers') {
      final rows = _brands.take(8).map((n) => {'name': n, 'delta': _val(-9e6, 18e6)}).toList()
        ..sort((a, b) => (b['delta'] as double).abs().compareTo((a['delta'] as double).abs()));
      return {'rows': rows, 'priorHasData': true, 'window': {'current': {'min': '2026-01-01'}}};
    }
    if (path == '/api/sales/pareto') {
      final rows = _customers.map((n) => {'name': n, 'sales': _val(4e6, 12e6)}).toList()
        ..sort((a, b) => (b['sales'] as double).compareTo(a['sales'] as double));
      double cum = 0;
      final total = rows.fold<double>(0, (s, r) => s + (r['sales'] as double));
      final withCum = rows.map((r) {
        cum += r['sales'] as double;
        return {...r, 'cumulative': total == 0 ? 0 : cum / total * 100};
      }).toList();
      return {'rows': withCum, 'total': total};
    }
    if (path == '/api/sales/pivot') {
      final rows = _brands.take(6).map((brand) {
        return {'row': brand, ..._quarterCols()};
      }).toList();
      return {
        'rows': rows,
        'rowKey': 'brand',
        'colKey': 'quarter',
        'columns': ['Q1 2026', 'Q2 2026', 'Q3 2026'],
      };
    }
    if (path == '/api/sales/insights') {
      return {
        'insights': [
          {'title': 'Fortinet grew 42% year on year', 'body': 'Driven by three new Globe Telecom orders.', 'severity': 'good'},
          {'title': 'Palo Alto softening in Q3', 'body': 'Down 12% vs Q2; watch for enterprise renewals.', 'severity': 'warning'},
          {'title': 'JACQUIE-A leads the team', 'body': 'Booked ₱18.2M this quarter, up 24%.', 'severity': 'good'},
        ]
      };
    }
    if (path == '/api/sales/detail') {
      final rows = List.generate(25, (i) {
        final s = _val(120000, 900000);
        final gp = s * (0.1 + _rng.nextDouble() * 0.2);
        return {
          'date': '2026-0${1 + i % 9}-${(1 + i % 27).toString().padLeft(2, '0')}',
          'invoice': 'INV-${10240 + i}',
          'customer': _customers[i % _customers.length],
          'brand': _brands[i % _brands.length],
          'salesman': _salesmen[i % _salesmen.length],
          'sales': s, 'grossProfit': gp, 'gmPercent': gp / s * 100, 'qty': 1 + i % 12,
        };
      });
      return {'rows': rows, 'total': 4821, 'page': 1, 'pageSize': 25};
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
        'value': total, 'skus': 1440, 'ageing': ageing,
        'over90Value': over90, 'over90Share': total == 0 ? 0 : over90 / total * 100,
        'slowMovingShare': total == 0 ? 0 : slow / total * 100,
        'deadStock': {'skus': 186, 'value': _val(4e6, 6e6)},
      };
    }
    if (path == '/api/inventory/breakdown') {
      final dim = _bodyStr(body, 'dimension', 'brand');
      final rows = _namesFor(dim).map((n) => {'name': n, 'value': _val(2e6, 9e6), 'qty': 50 + _rng.nextInt(400)}).toList()
        ..sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
      return {'dimension': dim, 'rows': rows};
    }
    if (path.startsWith('/api/inventory/options/')) {
      final dim = path.split('/').last;
      return {'dimension': dim, 'values': _namesFor(dim)};
    }

    if (path == '/api/reorder-point/kpis') {
      const items = 1440;
      const toOrder = 312;
      return {
        'items': items, 'brands': 12, 'onHand': 48210, 'backOrder': 1820,
        'forecast': 9640, 'safetyStock': 5200, 'itemsToOrder': toOrder,
        'belowRop': 274, 'amount': _val(31e6, 14e6), 'onHandAmount': _val(97e6, 20e6),
        'itemsWithoutCost': 41,
        'toOrderShare': toOrder / items * 100, 'belowRopShare': 274 / items * 100,
      };
    }
    if (path == '/api/reorder-point/breakdown') {
      final dim = _bodyStr(body, 'dimension', 'brand');
      final rows = _namesFor(dim).map((n) => {'name': n, 'forecast': (30 + _rng.nextInt(900)).toDouble(), 'amount': _val(1e6, 6e6), 'items': 10 + _rng.nextInt(120)}).toList()
        ..sort((a, b) => (b['forecast'] as double).compareTo(a['forecast'] as double));
      return {'dimension': dim, 'rows': rows};
    }
    if (path == '/api/reorder-point/detail') {
      final rows = List.generate(25, (i) {
        final toOrder = 5 + _rng.nextInt(120);
        return {
          'item': 'FORPRD${1000 + i}',
          'itemDescription': '${_brands[i % _brands.length]} module ${100 + i}',
          'brand': _brands[i % _brands.length],
          'onHand': _rng.nextInt(60), 'backOrder': _rng.nextInt(10),
          'rop': 20 + _rng.nextInt(40), 'forecast': toOrder,
          'orderAmount': _val(50000, 400000),
        };
      });
      return {'rows': rows, 'total': 312, 'page': 1, 'pageSize': 25};
    }
    if (path.startsWith('/api/reorder-point/options/')) {
      final dim = path.split('/').last;
      return {'dimension': dim, 'values': _namesFor(dim)};
    }

    if (path == '/api/sales/comparison') {
      final mode = _bodyStr(body, 'mode', 'yoy');
      final labels = mode == 'yoy'
          ? ['2023', '2024', '2025', '2026']
          : mode == 'qoq'
              ? ['Q2 2025', 'Q3 2025', 'Q4 2025', 'Q1 2026', 'Q2 2026']
              : ['May', 'Jun', 'Jul', 'Aug', 'Sep'];
      double prevSales = _val(60e6, 20e6);
      final rows = labels.map((l) {
        final s = prevSales * (0.9 + _rng.nextDouble() * 0.4);
        final prior = prevSales;
        prevSales = s;
        final cur = _agg(s);
        final pr = _agg(prior);
        double? g(double c, double p) => p == 0 ? null : (c - p) / p.abs() * 100;
        return {
          'periodKey': l, 'label': l, 'current': cur, 'prior': pr,
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

  static Map<String, dynamic> _quarterCols() {
    return {
      'Q1 2026': _val(3e6, 8e6),
      'Q2 2026': _val(3e6, 8e6),
      'Q3 2026': _val(3e6, 8e6),
    };
  }

  static List<String> _namesFor(String dim) {
    switch (dim) {
      case 'salesman': return List.of(_salesmen);
      case 'customer': return List.of(_customers);
      case 'productGroup': return List.of(_pgroups);
      case 'productManager': return List.of(_pmanagers);
      case 'salesGroup': return const ['North', 'South', 'Metro', 'Visayas', 'Mindanao'];
      case 'warehouse': return List.of(_warehouses);
      case 'type': return const ['Freight', 'Handling', 'Installation', 'Customs', 'Insurance', 'Storage'];
      default: return List.of(_brands);
    }
  }

  static String _bodyStr(Object? body, String key, String fallback) {
    if (body is Map && body[key] != null) return body[key].toString();
    return fallback;
  }
}
