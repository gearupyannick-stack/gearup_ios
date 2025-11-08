// lib/pages/premium_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/premium_service.dart';

/// A redesigned Premium purchase page with hero, feature cards and prominent CTA.
/// Replace `assets/premium_banner.png` with your own banner image (see suggestion below).
class PremiumPage extends StatefulWidget {
  const PremiumPage({Key? key}) : super(key: key);

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> with SingleTickerProviderStateMixin {
  static const String _productId = 'com.gearup.premium2';
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _loading = true;
  ProductDetails? _product;
  bool _processing = false;

  // small animation for "Purchased!" badge
  late final AnimationController _badgeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    _init();
    if (PremiumService.instance.isPremium) {
      _badgeCtrl.value = 1.0;
    }
  }

  Future<void> _init() async {
    _sub = _iap.purchaseStream.listen(_onPurchaseUpdated, onDone: () {
      _sub?.cancel();
    }, onError: (Object e) {
      // ignore stream errors here
    });

    final available = await _iap.isAvailable();
    setState(() {
    });

    if (!available) {
      setState(() => _loading = false);
      return;
    }

    final response = await _iap.queryProductDetails({_productId});
    if (mounted) {
      setState(() {
        _product = response.productDetails.isNotEmpty ? response.productDetails.first : null;
        _loading = false;
      });
    }
  }

  Future<void> _buy() async {
    if (_product == null) return;
    setState(() => _processing = true);
    final param = PurchaseParam(productDetails: _product!);
    await _iap.buyNonConsumable(purchaseParam: param);
    // actual state update happens in _onPurchaseUpdated
    setState(() => _processing = false);
  }

  Future<void> _restore() async {
    setState(() => _processing = true);
    await _iap.restorePurchases();
    setState(() => _processing = false);
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID == _productId) {
        if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
          await PremiumService.instance.setPremium(true);
          if (mounted) {
            // animate badge
            _badgeCtrl.forward();
            setState(() {});
          }
        }
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _badgeCtrl.dispose();
    super.dispose();
  }

  Widget _buildHero(BuildContext context) {
    // Replace the asset with your promotional banner.
    // Add a file at assets/premium_banner.png and declare it in pubspec.yaml.
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Banner image (fallback color if missing)
          SizedBox(
            height: 160,
            width: double.infinity,
            child: Image.asset(
              'assets/premium_banner.png',
              fit: BoxFit.cover,
              errorBuilder: (ctx, e, st) {
                return Container(
                  color: Colors.red.shade900,
                  alignment: Alignment.center,
                  child: const Icon(Icons.star, size: 48, color: Colors.white70),
                );
              },
            ),
          ),

          // Gradient & Title
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Title/subtitle: constrained to one line each
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'premium.title'.tr(),
                        style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'premium.unlimitedLives'.tr() + ' • ' + 'premium.noAds'.tr() + ' • ' + 'premium.unlimitedTraining'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Fixed-size badge so it never pushes the title out of bounds
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 72, maxWidth: 120),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1.05)
                        .animate(CurvedAnimation(parent: _badgeCtrl, curve: Curves.elasticOut)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade600,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, size: 16, color: Colors.black87),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              PremiumService.instance.isPremium ? 'premium.active'.tr() : 'premium.title'.tr(),
                              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: Colors.white70),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBuyArea(BuildContext context) {
    final isPremium = PremiumService.instance.isPremium;
    final priceLabel = _product?.price ?? '€2.99';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Price / CTA - big pill button
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: isPremium
              ? Container(
                  key: const ValueKey('purchased'),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text('premium.alreadyPremium'.tr(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                )
              : ElevatedButton(
                  key: const ValueKey('buy'),
                  onPressed: (_loading || _processing || _product == null) ? null : _buy,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  child: _processing
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('premium.purchaseButton'.tr(namedArgs: {'price': priceLabel})),
                ),
        ),
        const SizedBox(height: 10),
        // Restore button
        Center(
          child: TextButton(
            onPressed: _processing ? null : _restore,
            child: Text('premium.restorePurchases'.tr(), style: const TextStyle(decoration: TextDecoration.underline)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = PremiumService.instance.isPremium;

    return Scaffold(
      appBar: AppBar(
        title: Text('premium.title'.tr()),
        leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHero(context),
                  const SizedBox(height: 18),

                  // Card with features
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black, blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // status row
                        Row(
                          children: [
                            Icon(isPremium ? Icons.favorite : Icons.favorite_border, color: isPremium ? Colors.amber : Colors.white70),
                            const SizedBox(width: 8),
                            Text(isPremium ? 'premium.premiumActive'.tr() : 'premium.notPurchased'.tr(), style: theme.textTheme.titleLarge?.copyWith(fontSize: 16)),
                            const Spacer(),
                            // Small note
                            Text(isPremium ? 'premium.thankYou'.tr() : 'premium.oneTimePurchase'.tr(), style: const TextStyle(color: Colors.white54)),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Features list
                        _buildFeatureRow(Icons.favorite, 'premium.unlimitedLives'.tr(), 'premium.unlimitedLivesDesc'.tr()),
                        const SizedBox(height: 12),
                        _buildFeatureRow(Icons.block, 'premium.noAds'.tr(), 'premium.noAdsDesc'.tr()),
                        const SizedBox(height: 12),
                        _buildFeatureRow(Icons.fitness_center, 'premium.unlimitedTraining'.tr(), 'premium.unlimitedTrainingDesc'.tr()),
                        const SizedBox(height: 16),

                        // Price and CTA
                        _buildBuyArea(context),

                        // small legal / note
                        const SizedBox(height: 8),
                        Text('premium.deviceNote'.tr(), style: const TextStyle(fontSize: 12, color: Colors.white60)),
                      ],
                    ),
                  ),

                  // FAQ / Extra info
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('premium.whyUpgrade'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('premium.whyUpgradeDesc'.tr(), style: const TextStyle(fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),
                  // Developer note / product id
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Opacity(opacity: 0.65, child: Text('Product ID: $_productId', style: const TextStyle(fontSize: 12))),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}