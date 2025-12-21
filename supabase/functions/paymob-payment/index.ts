// Supabase Edge Function: paymob-payment
// This function handles Paymob payment integration for Egypt

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const PAYMOB_API_URL = 'https://accept.paymob.com/api'

Deno.serve(async (req: Request) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const PAYMOB_API_KEY = Deno.env.get('PAYMOB_API_KEY')
        const CARD_INTEGRATION_ID = Deno.env.get('PAYMOB_CARD_INTEGRATION_ID')
        const WALLET_INTEGRATION_ID = Deno.env.get('PAYMOB_WALLET_INTEGRATION_ID')
        const IFRAME_ID = Deno.env.get('PAYMOB_IFRAME_ID')

        if (!PAYMOB_API_KEY) {
            return new Response(
                JSON.stringify({ error: 'Missing PAYMOB_API_KEY in secrets' }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
            )
        }

        const { action, ...data } = await req.json()

        // Step 1: Get Auth Token
        if (action === 'auth') {
            const authResponse = await fetch(`${PAYMOB_API_URL}/auth/tokens`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ api_key: PAYMOB_API_KEY })
            })

            const authData = await authResponse.json()

            // Check if authentication failed
            if (!authResponse.ok || !authData.token) {
                return new Response(
                    JSON.stringify({
                        error: 'Paymob auth failed',
                        status: authResponse.status,
                        details: authData
                    }),
                    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
                )
            }

            return new Response(
                JSON.stringify({ token: authData.token }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Step 2: Create Order
        if (action === 'create_order') {
            const { token, amount, orderId } = data

            const orderResponse = await fetch(`${PAYMOB_API_URL}/ecommerce/orders`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    auth_token: token,
                    delivery_needed: false,
                    amount_cents: Math.round(amount * 100),
                    currency: 'EGP',
                    merchant_order_id: orderId,
                    items: []
                })
            })
            const orderData = await orderResponse.json()

            if (!orderResponse.ok || !orderData.id) {
                return new Response(
                    JSON.stringify({ error: 'Create order failed', details: orderData }),
                    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
                )
            }

            return new Response(
                JSON.stringify({ order_id: orderData.id }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Step 3: Get Payment Key
        if (action === 'payment_key') {
            const { token, paymobOrderId, amount, billingData, paymentMethod } = data
            const integrationId = paymentMethod === 'wallet' ? WALLET_INTEGRATION_ID : CARD_INTEGRATION_ID

            const paymentKeyResponse = await fetch(`${PAYMOB_API_URL}/acceptance/payment_keys`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    auth_token: token,
                    amount_cents: Math.round(amount * 100),
                    expiration: 3600,
                    order_id: paymobOrderId,
                    billing_data: {
                        apartment: 'N/A',
                        email: billingData?.email || 'test@test.com',
                        floor: 'N/A',
                        first_name: billingData?.firstName || 'Test',
                        street: 'N/A',
                        building: 'N/A',
                        phone_number: billingData?.phone || '01000000000',
                        shipping_method: 'N/A',
                        postal_code: '00000',
                        city: billingData?.city || 'Cairo',
                        country: 'EG',
                        last_name: billingData?.lastName || 'User',
                        state: 'Cairo'
                    },
                    currency: 'EGP',
                    integration_id: parseInt(integrationId || '0'),
                    lock_order_when_paid: true
                })
            })
            const paymentData = await paymentKeyResponse.json()

            if (!paymentKeyResponse.ok || !paymentData.token) {
                return new Response(
                    JSON.stringify({ error: 'Payment key failed', details: paymentData }),
                    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
                )
            }

            return new Response(
                JSON.stringify({ payment_key: paymentData.token, iframe_id: IFRAME_ID }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Wallet payment
        if (action === 'wallet_pay') {
            const { paymentKey, phoneNumber } = data
            const walletResponse = await fetch(`${PAYMOB_API_URL}/acceptance/payments/pay`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    source: { identifier: phoneNumber, subtype: 'WALLET' },
                    payment_token: paymentKey
                })
            })
            return new Response(
                JSON.stringify(await walletResponse.json()),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        return new Response(
            JSON.stringify({ error: 'Invalid action' }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        )

    } catch (error) {
        return new Response(
            JSON.stringify({ error: String(error) }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
        )
    }
})
