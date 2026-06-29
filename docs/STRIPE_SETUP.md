# Stripe Payment Integration Guide

## 📦 Files Created

1. **`supabase/functions/create-payment-intent/index.ts`**
   - Creates a Stripe PaymentIntent
   - Called from frontend before payment

2. **`supabase/functions/stripe-webhook/index.ts`**
   - Handles Stripe webhooks
   - Updates order payment status automatically

---

## 🚀 Deployment Steps

### Step 1: Install Supabase CLI

```bash
npm install -g supabase
```

### Step 2: Login to Supabase

```bash
supabase login
```

### Step 3: Link Your Project

```bash
cd D:\AI\store
supabase link --project-ref wtxrezufftbrvgjwxmqe
```

### Step 4: Set Environment Variables

Go to **Supabase Dashboard** → **Project Settings** → **Edge Functions**

Add these secrets:
- `STRIPE_SECRET_KEY` = Your Stripe Secret Key (sk_live_... or sk_test_...)
- `STRIPE_WEBHOOK_SECRET` = Your Webhook Signing Secret (whsec_...)

Or via CLI:
```bash
supabase secrets set STRIPE_SECRET_KEY=sk_test_your_key_here
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_your_secret_here
```

### Step 5: Deploy Functions

```bash
supabase functions deploy create-payment-intent
supabase functions deploy stripe-webhook
```

---

## 🔗 Stripe Webhook Setup

1. Go to **Stripe Dashboard** → **Developers** → **Webhooks**
2. Click **Add endpoint**
3. URL: `https://wtxrezufftbrvgjwxmqe.supabase.co/functions/v1/stripe-webhook`
4. Select events:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `charge.refunded`
5. Copy the **Signing secret** and add it to Supabase secrets

---

## 💻 Frontend Usage

```javascript
// 1. Create PaymentIntent
const response = await fetch(
  'https://wtxrezufftbrvgjwxmqe.supabase.co/functions/v1/create-payment-intent',
  {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${supabaseClient.auth.session()?.access_token}`
    },
    body: JSON.stringify({
      amount: 500, // Amount in EGP
      currency: 'egp',
      orderId: 'order-uuid',
      customerEmail: 'customer@email.com',
      customerName: 'Customer Name'
    })
  }
);

const { clientSecret } = await response.json();

// 2. Confirm payment with Stripe.js
const stripe = Stripe('pk_test_...');
const { error } = await stripe.confirmPayment({
  clientSecret,
  confirmParams: {
    return_url: 'https://yoursite.com/order-success'
  }
});
```

---

## 🔒 Security Notes

- Never expose `STRIPE_SECRET_KEY` in frontend code
- Always use Edge Functions for server-side operations
- Webhook verifies signature to prevent fraud
- All amounts are handled in smallest currency unit (piasters)

---

## 📊 Testing

1. Use Stripe test cards:
   - Success: `4242 4242 4242 4242`
   - Decline: `4000 0000 0000 0002`

2. Check Stripe Dashboard for payment events
3. Check Supabase logs for function executions
