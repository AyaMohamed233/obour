# Paymob Payment Integration Guide (Egypt)

## 📋 المعلومات المطلوبة

من لوحة تحكم Paymob، احصلي على:

| المفتاح | الموقع في Dashboard |
|---------|---------------------|
| **API Key** | ✅ موجود |
| **Card Integration ID** | Dashboard → Integrations → Online Card |
| **Wallet Integration ID** | Dashboard → Integrations → Mobile Wallets |
| **Iframe ID** | Dashboard → iframes |
| **HMAC Secret** | Dashboard → Settings → HMAC |

---

## 🔧 إعداد Supabase Secrets

أضيفي هذه المفاتيح في Supabase:

**Dashboard → Project Settings → Edge Functions → Secrets**

```
PAYMOB_API_KEY=ZXlKaGJHY2lPaUpJVXpVeE1pSXNJblI1...
PAYMOB_CARD_INTEGRATION_ID=123456
PAYMOB_WALLET_INTEGRATION_ID=654321
PAYMOB_IFRAME_ID=789012
PAYMOB_HMAC_SECRET=your_hmac_secret
```

---

## 🚀 نشر Edge Function

```bash
supabase functions deploy paymob-payment
```

---

## 💳 طرق الدفع المدعومة

1. **البطاقات البنكية** - Visa, Mastercard, Meeza
2. **المحافظ الإلكترونية**:
   - فودافون كاش
   - اورانج كاش
   - اتصالات كاش
   - CIB Smart Wallet

---

## 🔗 Webhook Setup

في Paymob Dashboard:
1. اذهبي إلى **Developers → Webhooks**
2. أضيفي URL:
   ```
   https://qoqcprnrtmiswpertraw.supabase.co/functions/v1/paymob-webhook
   ```
3. اختاري Events: Transaction, Order

---

## 💻 كيفية الاستخدام

### الخطوة 1: الحصول على Token
```javascript
const authResponse = await fetch(EDGE_FUNCTION_URL, {
  method: 'POST',
  body: JSON.stringify({ action: 'auth' })
});
const { token } = await authResponse.json();
```

### الخطوة 2: إنشاء Order
```javascript
const orderResponse = await fetch(EDGE_FUNCTION_URL, {
  method: 'POST',
  body: JSON.stringify({
    action: 'create_order',
    token: token,
    amount: 500, // بالجنيه
    orderId: 'ORD-123'
  })
});
const { order_id } = await orderResponse.json();
```

### الخطوة 3: الحصول على Payment Key
```javascript
const paymentResponse = await fetch(EDGE_FUNCTION_URL, {
  method: 'POST',
  body: JSON.stringify({
    action: 'payment_key',
    token: token,
    paymobOrderId: order_id,
    amount: 500,
    paymentMethod: 'card', // أو 'wallet'
    billingData: {
      firstName: 'Aya',
      lastName: 'Mohamed',
      email: 'aya@email.com',
      phone: '01012345678',
      city: 'Cairo',
      governorate: 'Cairo'
    }
  })
});
const { payment_key, iframe_id } = await paymentResponse.json();
```

### الخطوة 4: عرض صفحة الدفع
```javascript
// للبطاقات - افتح iframe
window.location.href = `https://accept.paymob.com/api/acceptance/iframes/${iframe_id}?payment_token=${payment_key}`;

// للمحافظ - أرسل طلب مباشر
const walletResponse = await fetch(EDGE_FUNCTION_URL, {
  method: 'POST',
  body: JSON.stringify({
    action: 'wallet_pay',
    paymentKey: payment_key,
    phoneNumber: '01012345678'
  })
});
```

---

## 🧪 اختبار

استخدمي بطاقات الاختبار:
- **Success:** 2223000000000007
- **Failed:** 2223000000000023
- **CVV:** 123
- **Expiry:** أي تاريخ مستقبلي
