# Cashier Lebanon Pro

نظام نقاط بيع لبناني سريع يعمل محليًا دون إنترنت من قاعدة Flutter واحدة لمنصات Android وiOS وWeb.

## الوظائف

- إدارة المنتجات والبحث بالاسم أو الباركود، والتعديل والحذف والمخزون.
- فاتورة تفاعلية، تعديل السعر والكمية، ومسح الباركود بالكاميرا.
- دفع مختلط بالدولار والليرة مع حساب الفروقات مباشرة.
- سجل فواتير وتفاصيل وإعادة طباعة PDF.
- نسخ احتياطي بصيغة JSON مع تحقق من هوية التطبيق عند الاستيراد.
- واجهة عربية RTL، Material 3، ووضع فاتح/داكن متجاوب.
- تخزين محلي كامل، بلا أي API أو خدمة سحابية.

## التشغيل

```bash
flutter pub get
flutter run -d chrome     # Web
flutter run               # Android / iOS
```

## البناء

```bash
flutter build web --release
flutter build appbundle --release
flutter build ipa --release
```

معرّف Android وiOS المطلوب: `com.cashier.lebanon.pro`. يلزم HTTPS أو localhost لكي تسمح المتصفحات باستخدام الكاميرا في نسخة Web.

> ملاحظة: توقيع نسخ المتاجر يحتاج مفاتيح Android وشهادة Apple الخاصة بصاحب حساب المتجر؛ إعداد debug الحالي مخصص للاختبار فقط.
