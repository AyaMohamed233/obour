// Supabase Edge Function: create-payment-intent
// This function creates a Stripe PaymentIntent for secure payment processing

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from 'https://esm.sh/stripe@13.10.0?target=deno'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Get Stripe secret key from environment
        const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY')
        if (!stripeSecretKey) {
            throw new Error('Missing STRIPE_SECRET_KEY')
        }

        const stripe = new Stripe(stripeSecretKey, {
            apiVersion: '2023-10-16',
        })

        // Parse request body
        const { amount, currency = 'egp', orderId, customerEmail, customerName, metadata = {} } = await req.json()

        // Validate amount
        if (!amount || amount <= 0) {
            throw new Error('Invalid amount')
        }

        // Convert to smallest currency unit (piasters for EGP)
        const amountInSmallestUnit = Math.round(amount * 100)

        // Create PaymentIntent
        const paymentIntent = await stripe.paymentIntents.create({
            amount: amountInSmallestUnit,
            currency: currency.toLowerCase(),
            automatic_payment_methods: {
                enabled: true,
            },
            metadata: {
                order_id: orderId || '',
                customer_email: customerEmail || '',
                customer_name: customerName || '',
                ...metadata
            },
            receipt_email: customerEmail,
            description: `Order ${orderId || 'N/A'} - Luxury Bags Store`,
        })

        // Return client secret
        return new Response(
            JSON.stringify({
                clientSecret: paymentIntent.client_secret,
                paymentIntentId: paymentIntent.id,
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )

    } catch (error) {
        console.error('Payment Intent Error:', error)
        return new Response(
            JSON.stringify({
                error: error.message || 'Failed to create payment intent'
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            }
        )
    }
})
