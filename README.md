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

معرّف التطبيق المطلوب على المنصات: `com.cashier.lebanon.pro`.

## التشغيل المحلي

```bash
flutter pub get
flutter run -d chrome     # Web
flutter run               # Android / iOS
```

## البناء عبر GitHub Actions

المستودع يحتوي على ملف واحد للخطوط (`‎.github/workflows/build.yml`) يبني **APK** و**Web** و**IPA** معًا:

- **Android APK** → يعمل على `ubuntu-latest`، يبني APK موقّعًا بمفتاح debug افتراضيًا (قابل للتثبيت).
- **Web** → يعمل على `ubuntu-latest`، يبني موقعًا ثابتًا ويغلّفه بملف `web-release.zip`.
- **iOS IPA** → يعمل على `macos-latest`، يبني **IPA غير موقّع** (لا يحتاج شهادات Apple) لتشغيل خط الأنابيب.

### متى يشتغل؟

| الحدث | ما الذي يحدث |
|------|--------------|
| دفع (push) على الفرع `arena/019f6a6d-my-project-build` أو `main`/`master` | تبني المنصات الثلاث وترفع الأرشيفات (Artifacts). |
| فتح Pull Request نحو `main`/`master` | نفس ما سبق (للتحقق قبل الدمج). |
| وسم (tag) يبدأ بـ `v` مثل `v1.0.0` | يبني وينشر الملفات كـ **GitHub Release**. |
| التشغيل اليدوي (workflow_dispatch) | من تبويب Actions في المستودع. |

### تنزيل المخرجات

بعد كل بناء ادخل تبويب **Actions ← آخر تشغيل ← Artifacts** لتنزيل:
- `android-apk` ← ملفات `app-*-release.apk`.
- `web` ← `web-release.zip` (افتحه على استضافة ثابتة).
- `ios-ipa` ← `CashierLebanonPro.ipa` (غير موقّع افتراضيًا).

لإصدار نسخة: انشر وسمًا `vX.Y.Z` فيُنشأ GitHub Release يحوي كل الملفات تلقائيًا.

## توقيع Android APK (للإصدار الحقيقي في المتجر)

البناء الافتراضي يوقّع بـ debug. للتوقيع بإصدار حقيقي:

1. أنشئ مفتاحًا:
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. حوّله إلى base64: `base64 -w0 upload-keystore.jks > keystore.b64`.
3. أضف هذه الأسرار (Settings ← Secrets) في المستودع:
   - `ANDROID_KEYSTORE_BASE64` (محتوى `keystore.b64`)
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS` (مثلاً `upload`)
   - `ANDROID_KEY_PASSWORD`
4. فعّل التوقيع في `android/app/build.gradle.kts` (أو أضف خطوة فك التشفير قبل `flutter build apk`):
   ```kotlin
   signingConfigs {
       create("release") {
           storeFile = file("upload-keystore.jks")
           storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
           keyAlias = System.getenv("ANDROID_KEY_ALIAS")
           keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
       }
   }
   buildTypes { release { signingConfig = signingConfigs.getByName("release") } }
   ```

## توقيع iOS IPA (للأجهزة الحقيقية / TestFlight)

الافتراضي IPA **غير موقّع**. للتوقيع بإصدار حقيقي أضف أسرار المستودع:

- `IOS_CERTIFICATE_P12_BASE64` — شهادة توزيع Apple (`.p12`) بصيغة base64.
- `IOS_CERTIFICATE_PASSWORD` — كلمة سر الـ `.p12`.
- `IOS_PROVISIONING_PROFILE_BASE64` — ملف Provisioning Profile بصيغة base64.
- `IOS_KEYCHAIN_PASSWORD` — كلمة سر مؤقتة للـ keychain في CI.

ثم استبدل خطوة بناء iOS في `build.yml` بما يلي (يُفعّل فقط عند وجود الأسرار):

```yaml
      - name: Install Apple certificate & profile
        if: ${{ env.IOS_CERTIFICATE_P12_BASE64 != '' }}
        env:
          P12: ${{ secrets.IOS_CERTIFICATE_P12_BASE64 }}
          PROFILE: ${{ secrets.IOS_PROVISIONING_PROFILE_BASE64 }}
          KEYCHAIN: ${{ secrets.IOS_KEYCHAIN_PASSWORD }}
          CERT_PWD: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}
        run: |
          echo -n "$P12" | base64 --decode > cert.p12
          echo -n "$PROFILE" | base64 --decode > profile.mobileprovision
          security create-keychain -p "$KEYCHAIN" build.keychain
          security default-keychain -s build.keychain
          security unlock-keychain -p "$KEYCHAIN" build.keychain
          security import cert.p12 -k build.keychain -P "$CERT_PWD" -T /usr/bin/codesign
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          cp profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/
      - name: Build signed IPA
        run: flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

> ينصح بإصدار حقيقي عبر **Codemagic** أو **Xcode Cloud** أو آلة macOS تملك صلاحيات حساب Apple؛ إعداد debug الحالي مخصص للاختبار فقط.

## ملاحظات

- يلزم HTTPS أو `localhost` لكي تسمح المتصفحات باستخدام الكاميرا في نسخة Web.
- بعض الإضافات (مثل مسح الباركود/الطباعة) قد لا تدعم Web بشكل كامل؛ إن فشل بناء Web بسبب إضافة، استخدم استيرادًا مشروطًا (conditional import) أو بديلًا لـ Web.
- التخزين المحلي كامل، بلا أي API أو خدمة سحابية.
