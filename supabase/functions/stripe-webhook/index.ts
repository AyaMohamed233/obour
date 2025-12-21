// Supabase Edge Function: stripe-webhook
// This function handles Stripe webhooks to update order payment status

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from 'https://esm.sh/stripe@13.10.0?target=deno'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.0'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, stripe-signature',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY')
        const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')
        const supabaseUrl = Deno.env.get('SUPABASE_URL')
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

        if (!stripeSecretKey || !webhookSecret) {
            throw new Error('Missing Stripe configuration')
        }

        const stripe = new Stripe(stripeSecretKey, { apiVersion: '2023-10-16' })
        const supabase = createClient(supabaseUrl!, supabaseServiceKey!)

        // Get raw body and signature
        const body = await req.text()
        const signature = req.headers.get('stripe-signature')

        if (!signature) {
            throw new Error('Missing Stripe signature')
        }

        // Verify webhook signature
        let event: Stripe.Event
        try {
            event = stripe.webhooks.constructEvent(body, signature, webhookSecret)
        } catch (err) {
            console.error('Webhook signature verification failed:', err)
            return new Response(JSON.stringify({ error: 'Invalid signature' }), { status: 400 })
        }

        console.log('Received Stripe event:', event.type)

        // Handle specific events
        switch (event.type) {
            case 'payment_intent.succeeded': {
                const paymentIntent = event.data.object as Stripe.PaymentIntent
                const orderId = paymentIntent.metadata?.order_id

                if (orderId) {
                    // Update order payment status
                    const { error } = await supabase
                        .from('orders')
                        .update({
                            payment_status: 'paid',
                            stripe_payment_intent_id: paymentIntent.id,
                            status: 'confirmed'
                        })
                        .eq('id', orderId)

                    if (error) {
                        console.error('Failed to update order:', error)
                    } else {
                        console.log('Order updated successfully:', orderId)
                    }

                    // Create transaction record
                    await supabase.from('transactions').insert({
                        order_id: orderId,
                        user_id: paymentIntent.metadata?.user_id,
                        amount: paymentIntent.amount / 100,
                        currency: paymentIntent.currency,
                        payment_method: 'stripe',
                        payment_provider: 'stripe',
                        provider_transaction_id: paymentIntent.id,
                        status: 'completed',
                        type: 'payment'
                    })
                }
                break
            }

            case 'payment_intent.payment_failed': {
                const paymentIntent = event.data.object as Stripe.PaymentIntent
                const orderId = paymentIntent.metadata?.order_id

                if (orderId) {
                    await supabase
                        .from('orders')
                        .update({
                            payment_status: 'failed',
                            status: 'payment_failed'
                        })
                        .eq('id', orderId)
                }
                break
            }

            case 'charge.refunded': {
                const charge = event.data.object as Stripe.Charge
                const paymentIntentId = charge.payment_intent as string

                // Find order by payment intent
                const { data: order } = await supabase
                    .from('orders')
                    .select('id')
                    .eq('stripe_payment_intent_id', paymentIntentId)
                    .single()

                if (order) {
                    await supabase
                        .from('orders')
                        .update({ payment_status: 'refunded' })
                        .eq('id', order.id)

                    // Create refund record
                    await supabase.from('refunds').insert({
                        order_id: order.id,
                        amount: charge.amount_refunded / 100,
                        reason: 'Stripe refund',
                        status: 'completed',
                        refund_method: 'original_payment_method'
                    })
                }
                break
            }
        }

        return new Response(JSON.stringify({ received: true }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })

    } catch (error) {
        console.error('Webhook error:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: corsHeaders, status: 400 }
        )
    }
})
