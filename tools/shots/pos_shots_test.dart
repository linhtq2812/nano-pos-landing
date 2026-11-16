// Counter-app screenshots for the landing page, rendered by `flutter test`
// (no device, no build): the real SaleScreen / ReportScreen over an in-memory
// database, with the app's real fonts. Copied into nano_pos_flutter/test/ by
// tools/shots/pos.sh and removed afterwards; it is NOT part of that repo.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nano_pos_flutter/data/db/bank_account_dao.dart';
import 'package:nano_pos_flutter/data/db/customer_dao.dart';
import 'package:nano_pos_flutter/data/db/expense_dao.dart';
import 'package:nano_pos_flutter/data/db/order_payment_dao.dart';
import 'package:nano_pos_flutter/data/db/order_refund_dao.dart';
import 'package:nano_pos_flutter/data/db/product_dao.dart';
import 'package:nano_pos_flutter/data/db/product_unit_dao.dart';
import 'package:nano_pos_flutter/data/db/product_variant_dao.dart';
import 'package:nano_pos_flutter/data/db/sale_order_dao.dart';
import 'package:nano_pos_flutter/data/db/stock_movement_dao.dart';
import 'package:nano_pos_flutter/data/models/catalog_entry.dart';
import 'package:nano_pos_flutter/data/repository/pos_repository.dart';
import 'package:nano_pos_flutter/l10n/app_localizations.dart';
import 'package:nano_pos_flutter/providers/pos_provider.dart';
import 'package:nano_pos_flutter/theme/app_theme.dart';
import 'package:nano_pos_flutter/ui/screens/report_screen.dart';
import 'package:nano_pos_flutter/ui/screens/sale_screen.dart';

import 'support/app_fonts.dart';
import 'support/catalog_fixture.dart';
import 'support/pos_provider_harness.dart';
import 'support/shop_session_scope.dart';
import 'support/test_ids.dart';

const _out = String.fromEnvironment('SHOTS_OUT', defaultValue: '/tmp/pos-shots');
const _iconFont = String.fromEnvironment('MATERIAL_ICONS');

// Same demo catalog as tools/demo/seed.sql (name, unit, price).
const _products = [
  ('Mì Hảo Hảo tôm chua cay', 'Gói', 5000.0),
  ('Coca-Cola lon 320ml', 'Lon', 10000.0),
  ('Sữa tươi Vinamilk 180ml', 'Hộp', 8000.0),
  ('Nước suối Lavie 500ml', 'Chai', 6000.0),
  ('Bánh Oreo 133g', 'Gói', 21000.0),
  ('Trà xanh Không Độ 455ml', 'Chai', 10000.0),
  ('Dầu ăn Neptune 1L', 'Chai', 62000.0),
  ('Nước mắm Nam Ngư 750ml', 'Chai', 42000.0),
  ('Bột giặt Omo 800g', 'Túi', 49000.0),
  ('Gạo ST25 túi 5kg', 'Túi', 185000.0),
];

Future<void> _loadIconFont() async {
  if (_iconFont.isEmpty) return;
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File(_iconFont).readAsBytesSync())));
  await loader.load();
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.pumpAndSettle();
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('counter app landing shots', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late PosProvider provider;
    await tester.runAsync(() async {
      await loadAppFonts();
      await _loadIconFont();
      SharedPreferences.setMockInitialValues({});
      final h = await newPosHarness();
      addTearDown(h.db.close);
      provider = h.provider;
      for (final (i, (name, unit, price)) in _products.indexed) {
        await seedProduct(h.repo, uuid: 'p-$i', name: name, price: price, baseUnitName: unit, stockQuantity: 120);
      }
      await provider.reloadCatalog();
      // A receiving account (fictional) so VietQR is offered; the harness has no table for it.
      await h.db.execute('''CREATE TABLE IF NOT EXISTS shop_bank_accounts (id TEXT PRIMARY KEY,
        bankCode TEXT NOT NULL, accountNo TEXT NOT NULL, accountName TEXT NOT NULL,
        isDefault INTEGER NOT NULL DEFAULT 0, deletedAt INTEGER NOT NULL DEFAULT 0,
        lastUpdated INTEGER NOT NULL DEFAULT 0)''');
      await h.db.insert('shop_bank_accounts', {
        'id': 'bank-1', 'bankCode': 'VCB', 'accountNo': '1023456789',
        'accountName': 'TAP HOA HOA MAI', 'isDefault': 1,
      });
      // The shared harness leaves BankAccountDao unwired on purpose; this shot needs it,
      // so build the same repository plus that DAO over the harness database.
      final db = h.db;
      provider = PosProvider(
        shopId: kTestShopId,
        shopRole: 'owner',
        settingsRepository: h.settings,
        repository: PosRepository(ProductDao(db), SaleOrderDao(db), CustomerDao(db),
            variantDao: ProductVariantDao(db), unitDao: ProductUnitDao(db),
            stockMovementDao: StockMovementDao(db), expenseDao: ExpenseDao(db),
            orderPaymentDao: OrderPaymentDao(db), orderRefundDao: OrderRefundDao(db),
            bankAccountDao: BankAccountDao(db), database: db),
        isOnline: () => true,
        operatorSessionReady: () => true,
        hasSupabaseSession: () => false,
        isSessionActive: () => false,
      );
      await provider.initialized;
      await provider.reloadCatalog();

      // Today's sales, through the real checkout path.
      final sellables = [for (final p in provider.catalog) Sellable(variant: p.defaultVariant)];
      for (var o = 0; o < 26; o++) {
        for (var l = 0; l <= o % 3; l++) {
          provider.addToCart(sellables[(o * 3 + l * 5) % sellables.length]);
        }
        // checkout() stores a draft for the invoice dialog; completeSale() is what the
        // dialog's confirm button runs.
        await provider.checkout(o % 3 == 1 ? 'bank_transfer' : 'cash');
        await provider.completeSale(provider.lastSaleOrder!, paymentRecon: 'confirmed');
      }
      if (provider.cartItemCount != 0) throw StateError('checkout left ${provider.cartItemCount} items in the cart');
      // A live order on the counter for the sale-screen shot.
      provider.addToCart(sellables[0]);
      provider.addToCart(sellables[0]);
      provider.addToCart(sellables[1]);
      provider.addToCart(sellables[2]);
      provider.addToCart(sellables[4]);
    });

    var key = GlobalKey();
    Widget host(Widget body) => RepaintBoundary(
          key: key = GlobalKey(),
          child: ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp(
              key: UniqueKey(),
              debugShowCheckedModeBanner: false,
              locale: const Locale('vi'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light(),
              home: Scaffold(body: SafeArea(child: body)),
            ),
          ),
        );

    await tester.pumpWidget(host(const SaleScreen()));
    await _shot(tester, key, 'pos-sale');

    final viewCart = find.textContaining('Xem giỏ');
    if (viewCart.evaluate().isNotEmpty) {
      await tester.tap(viewCart.first);
      await tester.pumpAndSettle();
      final vietQr = find.text('VIETQR');
      if (vietQr.evaluate().isNotEmpty) await tester.tap(vietQr.first);
      await _shot(tester, key, 'pos-cart');
    }

    late Widget report;
    await tester.runAsync(() async => report = await withShopSession(host(const ReportScreen())));
    await tester.pumpWidget(report);
    await _shot(tester, key, 'pos-report');
  });
}
