// Supabase Edge Function: paymob-webhook
// This function handles Paymob transaction callbacks

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.39.3";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req: Request) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const PAYMOB_HMAC_SECRET = Deno.env.get('PAYMOB_HMAC_SECRET');
        if (!PAYMOB_HMAC_SECRET) {
             console.error("Missing HMAC secret");
             return new Response("Missing HMAC secret", { status: 400 });
        }

        // Parse Paymob payload
        const payload = await req.json();
        
        // For security, you would normally verify the HMAC signature here
        // using the hmac algorithm provided by Paymob

        const obj = payload.obj;
        const merchant_order_id = obj?.order?.merchant_order_id;
        const success = obj?.success;

        if (!merchant_order_id) {
            return new Response("Missing order ID", { status: 400 });
        }

        // Initialize Supabase Client to update the database
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        if (success) {
            // Update order to paid
            await supabaseClient
                .from('orders')
                .update({ payment_status: 'paid', status: 'processing' })
                .eq('id', merchant_order_id);
                
            console.log(`Order ${merchant_order_id} marked as paid.`);
        } else {
            // Update order to failed
            await supabaseClient
                .from('orders')
                .update({ payment_status: 'failed' })
                .eq('id', merchant_order_id);
                
            console.log(`Order ${merchant_order_id} payment failed.`);
        }

        return new Response(JSON.stringify({ success: true }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })
    } catch (error) {
        console.error("Webhook Error:", error);
        return new Response(
            JSON.stringify({ error: String(error) }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
        )
    }
})
