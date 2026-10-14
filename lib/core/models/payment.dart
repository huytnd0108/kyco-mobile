/// `GET /v1/payment/methods`: `{methods: string[], methodInfo?: [{method, label, sandbox}]}`.
/// `methodInfo` is additive (older backends omit it) so every field is guarded.
class PaymentMethodsInfo {
  const PaymentMethodsInfo({required this.methods, this.sandbox = const {}});

  /// Method codes the server accepts, in server order (`cash`, `momo`, ...).
  final List<String> methods;

  /// Methods the server marks as test-mode (`methodInfo[].sandbox`).
  final Set<String> sandbox;

  /// Used when the list cannot be loaded: the long-standing set WITHOUT
  /// zalopay, so ZaloPay only ever shows when the server lists it.
  static const fallback = PaymentMethodsInfo(methods: ['cash', 'momo', 'vnpay']);

  bool isSandbox(String? method) => sandbox.contains((method ?? '').toLowerCase());

  factory PaymentMethodsInfo.fromJson(Map<String, dynamic> j) {
    final raw = j['methods'];
    final methods = <String>[
      if (raw is List)
        for (final m in raw)
          if (m is String && m.trim().isNotEmpty) m.trim().toLowerCase(),
    ];
    final info = j['methodInfo'];
    final sandbox = <String>{
      if (info is List)
        for (final i in info)
          if (i is Map && i['sandbox'] == true && i['method'] is String) (i['method'] as String).toLowerCase(),
    };
    return PaymentMethodsInfo(methods: methods.toSet().toList(), sandbox: sandbox);
  }
}
