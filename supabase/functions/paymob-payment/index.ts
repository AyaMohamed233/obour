// Supabase Edge Function: paymob-payment
// This function handles Paymob payment integration for Egypt
// Supports: Credit Cards, Mobile Wallets (Vodafone Cash, Orange, Etisalat)

// @ts-ignore - Deno imports
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const PAYMOB_API_URL = 'https://accept.paymob.com/api'

serve(async (req: Request) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // @ts-ignore - Deno env
        const PAYMOB_API_KEY = Deno.env.get('PAYMOB_API_KEY')
        // @ts-ignore - Deno env
        const CARD_INTEGRATION_ID = Deno.env.get('PAYMOB_CARD_INTEGRATION_ID')
        // @ts-ignore - Deno env
        const WALLET_INTEGRATION_ID = Deno.env.get('PAYMOB_WALLET_INTEGRATION_ID')
        // @ts-ignore - Deno env
        const IFRAME_ID = Deno.env.get('PAYMOB_IFRAME_ID')

        if (!PAYMOB_API_KEY) {
            throw new Error('Missing PAYMOB_API_KEY')
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

            return new Response(
                JSON.stringify({ token: authData.token }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Step 2: Create Order
        if (action === 'create_order') {
            const { token, amount, orderId, items } = data

            const orderResponse = await fetch(`${PAYMOB_API_URL}/ecommerce/orders`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    auth_token: token,
                    delivery_needed: false,
                    amount_cents: Math.round(amount * 100),
                    currency: 'EGP',
                    merchant_order_id: orderId,
                    items: items || []
                })
            })
            const orderData = await orderResponse.json()

            return new Response(
                JSON.stringify({ order_id: orderData.id }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Step 3: Get Payment Key
        if (action === 'payment_key') {
            const { token, paymobOrderId, amount, billingData, paymentMethod } = data

            const integrationId = paymentMethod === 'wallet'
                ? (WALLET_INTEGRATION_ID || CARD_INTEGRATION_ID)
                : CARD_INTEGRATION_ID

            const paymentKeyResponse = await fetch(`${PAYMOB_API_URL}/acceptance/payment_keys`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    auth_token: token,
                    amount_cents: Math.round(amount * 100),
                    expiration: 3600,
                    order_id: paymobOrderId,
                    billing_data: {
                        apartment: billingData?.apartment || 'N/A',
                        email: billingData?.email || 'customer@example.com',
                        floor: billingData?.floor || 'N/A',
                        first_name: billingData?.firstName || 'Customer',
                        street: billingData?.street || 'N/A',
                        building: billingData?.building || 'N/A',
                        phone_number: billingData?.phone || '01000000000',
                        shipping_method: 'N/A',
                        postal_code: billingData?.postalCode || '00000',
                        city: billingData?.city || 'Cairo',
                        country: 'EG',
                        last_name: billingData?.lastName || 'Name',
                        state: billingData?.governorate || 'Cairo'
                    },
                    currency: 'EGP',
                    integration_id: parseInt(integrationId || '0'),
                    lock_order_when_paid: true
                })
            })
            const paymentKeyData = await paymentKeyResponse.json()

            return new Response(
                JSON.stringify({
                    payment_key: paymentKeyData.token,
                    iframe_id: IFRAME_ID,
                    integration_id: integrationId
                }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // For wallet payment
        if (action === 'wallet_pay') {
            const { paymentKey, phoneNumber } = data

            const walletResponse = await fetch(`${PAYMOB_API_URL}/acceptance/payments/pay`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    source: {
                        identifier: phoneNumber,
                        subtype: 'WALLET'
                    },
                    payment_token: paymentKey
                })
            })
            const walletData = await walletResponse.json()

            return new Response(
                JSON.stringify(walletData),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        throw new Error('Invalid action')

    } catch (error: unknown) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error'
        console.error('Paymob Error:', errorMessage)
        return new Response(
            JSON.stringify({ error: errorMessage }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        )
    }
})
