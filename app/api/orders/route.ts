import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

// Initialize Supabase client with Service Role key for secure server-side execution
const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL || '',
  process.env.SUPABASE_SERVICE_ROLE_KEY || ''
);

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { customerId, items, idempotencyKey, idempotencyHash } = body;

    if (!customerId || !items || !idempotencyKey) {
      return NextResponse.json(
        { error: 'Missing required fields: customerId, items, or idempotencyKey' },
        { status: 400 }
      );
    }

    // Call the trusted database function create_order
    const { data, error } = await supabaseAdmin.rpc('create_order', {
      p_customer_id: customerId,
      p_items: items,
      p_idempotency_key: idempotencyKey,
      p_idempotency_hash: idempotencyHash || 'default-hash'
    });

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }

    return NextResponse.json({ success: true, data }, { status: 200 });
  } catch (err: any) {
    return NextResponse.json({ error: err.message || 'Internal server error' }, { status: 500 });
  }
}
