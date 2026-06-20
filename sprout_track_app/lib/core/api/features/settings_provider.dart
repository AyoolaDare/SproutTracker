import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_provider.dart';
import '../../state/sprout_state.dart';
import '../api_client.dart';

class ApiBusinessProfile {
  const ApiBusinessProfile({
    required this.businessName,
    this.businessType = 'RETAIL',
    this.email,
    this.phone,
    this.address,
    this.tin,
    this.rcNumber,
    this.currency = 'NGN',
    this.bankName,
    this.accountName,
    this.accountNumber,
  });

  final String  businessName;
  final String  businessType;
  final String? email;
  final String? phone;
  final String? address;
  final String? tin;
  final String? rcNumber;
  final String  currency;
  final String? bankName;
  final String? accountName;
  final String? accountNumber;

  factory ApiBusinessProfile.fromApi(Map<String, dynamic> j) {
    // Backend returns flat bank fields; support legacy bank_accounts list too
    final bank = j['bank_accounts'] is List
        ? (j['bank_accounts'] as List).firstOrNull as Map<String, dynamic>?
        : null;
    return ApiBusinessProfile(
      businessName:  j['business_name'] as String? ?? '',
      businessType:  j['business_type'] as String? ?? 'RETAIL',
      email:         j['email'] as String?,
      phone:         j['phone'] as String?,
      address:       j['address'] as String?,
      tin:           j['tin'] as String?,
      rcNumber:      j['rc_number'] as String?,
      currency:      j['currency'] as String? ?? 'NGN',
      bankName:      bank?['bank_name'] as String? ?? j['bank_name'] as String?,
      accountName:   bank?['account_name'] as String? ?? j['bank_account_name'] as String?,
      accountNumber: bank?['account_number'] as String? ?? j['bank_account_number'] as String?,
    );
  }

  factory ApiBusinessProfile.fromLocal(BusinessProfile p) => ApiBusinessProfile(
        businessName:  p.businessName,
        email:         p.email,
        phone:         p.phone,
        address:       p.address,
        bankName:      p.accounts.firstOrNull?.bankName,
        accountName:   p.accounts.firstOrNull?.accountName,
        accountNumber: p.accounts.firstOrNull?.accountNumber,
      );

  Map<String, dynamic> toJson() => {
        'business_name': businessName,
        'business_type': businessType,
        if (email != null)         'email': email,
        if (phone != null)         'phone': phone,
        if (address != null)       'address': address,
        if (tin != null)           'tin': tin,
        if (rcNumber != null)      'rc_number': rcNumber,
        'currency': currency,
        if (bankName != null)      'bank_name': bankName,
        if (accountName != null)   'bank_account_name': accountName,
        if (accountNumber != null) 'bank_account_number': accountNumber,
      };
}

class ApiTaxSettings {
  const ApiTaxSettings({
    this.vatRate        = 7.5,
    this.whtRateServices   = 5.0,
    this.whtRateProfessional = 10.0,
    this.citRate        = 30.0,
    this.smallCompanyCitRate = 20.0,
    this.tetfundRate    = 2.5,
    this.applyVatByDefault = true,
  });

  final double vatRate;
  final double whtRateServices;
  final double whtRateProfessional;
  final double citRate;
  final double smallCompanyCitRate;
  final double tetfundRate;
  final bool   applyVatByDefault;

  factory ApiTaxSettings.fromApi(Map<String, dynamic> j) => ApiTaxSettings(
        vatRate:               (j['vat_rate'] as num? ?? 7.5).toDouble(),
        whtRateServices:       (j['wht_rate_services'] as num? ?? 5.0).toDouble(),
        whtRateProfessional:   (j['wht_rate_professional'] as num? ?? 10.0).toDouble(),
        citRate:               (j['cit_rate'] as num? ?? 30.0).toDouble(),
        smallCompanyCitRate:   (j['small_company_cit_rate'] as num? ?? 20.0).toDouble(),
        tetfundRate:           (j['tetfund_rate'] as num? ?? 2.5).toDouble(),
        applyVatByDefault:     j['apply_vat_by_default'] as bool? ?? true,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class SettingsNotifier extends AutoDisposeAsyncNotifier<ApiBusinessProfile> {
  @override
  Future<ApiBusinessProfile> build() => _load();

  Future<ApiBusinessProfile> _load() async {
    final isDemo = ref.watch(authProvider).isDemo;
    if (isDemo) {
      return ApiBusinessProfile.fromLocal(
        ref.watch(sproutStoreProvider).businessProfile,
      );
    }
    final res = await ref.watch(apiClientProvider).get('/api/settings/business-profile');
    final raw = res.data as Map<String, dynamic>;
    return ApiBusinessProfile.fromApi(raw['data'] as Map<String, dynamic>? ?? raw);
  }

  Future<void> save(ApiBusinessProfile profile) async {
    if (ref.read(authProvider).isDemo) return;
    await ref.read(apiClientProvider).put(
      '/api/settings/business-profile',
      data: profile.toJson(),
    );
    state = AsyncData(profile);
  }
}

final settingsProvider =
    AsyncNotifierProvider.autoDispose<SettingsNotifier, ApiBusinessProfile>(
  SettingsNotifier.new,
);

final taxSettingsProvider = FutureProvider.autoDispose<ApiTaxSettings>((ref) async {
  final isDemo = ref.watch(authProvider).isDemo;
  if (isDemo) return const ApiTaxSettings();
  final res = await ref.watch(apiClientProvider).get('/api/settings/tax');
  final raw = res.data as Map<String, dynamic>;
  return ApiTaxSettings.fromApi(raw['data'] as Map<String, dynamic>? ?? raw);
});
