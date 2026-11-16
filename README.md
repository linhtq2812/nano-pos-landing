# nano-pos-landing

Trang giới thiệu NanoPOS: một file `index.html` tĩnh (CSS/JS nằm trong file), không có bước build.

- Thiết kế: `nano-pos-doc/docs/specs/2026-11-16-landing-page-design.md`
- Plan: `nano-pos-doc/docs/plans/2026-11-16-landing-page.md`

## Chạy thử

```bash
bash tests/serve.sh          # http://127.0.0.1:4173
```

## Điền liên hệ và link store

Mọi số điện thoại, Zalo, email, link store, link điều khoản nằm trong khối `window.SITE` ở đầu thẻ `<script>` trong `index.html`.
Ô nào để trống thì nút tương ứng tự ẩn; nút store hiện "Sắp có trên …" và không bấm được.

## Chữ hai ngôn ngữ

Phần tử có `data-i18n="khoá"` lấy chữ từ `window.I18N.vi` / `window.I18N.en`. Thêm khoá thì thêm ở **cả hai** từ điển (test `i18n parity` canh).
Thêm `data-i18n-html` khi chữ có thẻ HTML.

## Test

Dùng Playwright đã cài trong `../nano-pos-web` (repo này không có `package.json`):

```bash
bash tests/run.sh
```

`tests/run.sh` tạo symlink `node_modules` (đã gitignore) trỏ sang `nano-pos-web/node_modules`. Đặt `NANO_POS_WEB` nếu repo web nằm chỗ khác.

## Deploy

Chép nguyên thư mục (bỏ `tests/`, `tools/`) lên bất kỳ host tĩnh nào: GitHub Pages, Cloudflare Pages, Nginx.

## Ảnh giao diện (`assets/shots/`)

Ảnh là giao diện thật trên dữ liệu demo "Tạp hoá Hoa Mai", **chỉ dựng trên Supabase local**:

1. `bash tools/demo/seed.sh`: tạo tài khoản `demo-owner@nanopos.local` / `demo-landing-2026` và shop demo, 75 ngày bán hàng (gọi lại an toàn; `DEMO_RESET=1` để sinh lại đơn). Script từ chối chạy nếu API không phải `http://127.0.0.1:54321`.
2. `bash tools/shots/web.sh`: Nano Admin (chạy `nano-pos-web` ở cổng 3100 với `NEXT_PUBLIC_SUPABASE_*` ép về local, Playwright chụp 1440×900).
3. `python3 tools/shots/manager.py`: Nano Manager, lấy từ ảnh golden của `nano-pos-manager`.
4. `bash tools/shots/pos.sh`: app quầy, dựng bằng `flutter test` (không build, không thiết bị); file test chép tạm vào `nano_pos_flutter/test/` rồi tự xoá.
5. `node tools/shots/render.mjs tools/shots/og.html assets/og.png 1200 630`: ảnh chia sẻ.

Mỗi lúc chạy một bước: các bước đều nặng (dev server, Flutter).
