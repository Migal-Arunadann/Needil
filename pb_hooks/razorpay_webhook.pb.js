/// <reference path="../pb_data/types.d.ts" />

/**
 * Needil PMS — Razorpay Webhook Handler
 * Verifies HMAC-SHA256 signature and handles all subscription lifecycle events.
 */

console.log('>>> [WEBHOOK_HOOK] Razorpay webhook hook loaded');

const WEBHOOK_SECRET = $os.getenv('RAZORPAY_WEBHOOK_SECRET') || '';

routerAdd('POST', '/api/webhooks/razorpay', (e) => {
  const signature = e.request.header.get('x-razorpay-signature');
  const rawBody = JSON.stringify(e.request.data || {});

  if (!signature || !rawBody) {
    console.error('>>> [WEBHOOK_HOOK] Missing signature or body');
    return e.json(400, { error: 'Missing signature or body' });
  }

  // 1. Verify HMAC-SHA256 signature
  if (WEBHOOK_SECRET) {
    const expectedSignature = $security.hs256(rawBody, WEBHOOK_SECRET);
    if (signature !== expectedSignature) {
      console.error('>>> [WEBHOOK_HOOK] Invalid webhook signature');
      return e.json(401, { error: 'Invalid signature' });
    }
  } else {
    console.warn('>>> [WEBHOOK_HOOK] RAZORPAY_WEBHOOK_SECRET not set — skipping signature check (CONFIGURE THIS IN PRODUCTION!)');
  }

  // 2. Parse event
  let eventData;
  try {
    eventData = JSON.parse(rawBody);
  } catch (_) {
    return e.json(400, { error: 'Invalid JSON' });
  }

  const eventName = eventData.event || '';
  const subscriptionEntity = eventData.payload && eventData.payload.subscription && eventData.payload.subscription.entity;
  const paymentEntity = eventData.payload && eventData.payload.payment && eventData.payload.payment.entity;

  console.log(`>>> [WEBHOOK_HOOK] Event received: ${eventName}`);

  if (!subscriptionEntity) {
    return e.json(200, { message: 'Non-subscription event ignored' });
  }

  const razorpaySubId = subscriptionEntity.id;
  if (!razorpaySubId) {
    return e.json(400, { error: 'No subscription ID in payload' });
  }

  try {
    // 3. Find matching clinic by razorpay_subscription_id
    const clinic = $app.findFirstRecordByFilter(
      'clinics',
      `razorpay_subscription_id = '${razorpaySubId}'`
    );

    if (!clinic) {
      console.warn(`>>> [WEBHOOK_HOOK] No clinic found for subscription ${razorpaySubId}`);
      return e.json(200, { message: 'No matching clinic found' });
    }

    const now = new Date();

    // 4. Handle lifecycle events
    switch (eventName) {
      case 'subscription.activated': {
        clinic.set('subscription_status', 'active');
        if (subscriptionEntity.current_end) {
          clinic.set('subscription_end_date', new Date(subscriptionEntity.current_end * 1000).toISOString());
        }
        break;
      }
      case 'subscription.charged': {
        clinic.set('subscription_status', 'active');
        if (subscriptionEntity.current_end) {
          clinic.set('subscription_end_date', new Date(subscriptionEntity.current_end * 1000).toISOString());
        }
        // Log payment to payment_history
        if (paymentEntity && paymentEntity.id) {
          try {
            const phCol = $app.findCollectionByNameOrId('payment_history');
            if (phCol) {
              const ph = new Record(phCol);
              ph.set('clinic_id', clinic.id);
              ph.set('razorpay_payment_id', paymentEntity.id);
              ph.set('razorpay_subscription_id', razorpaySubId);
              ph.set('amount_paise', paymentEntity.amount || 0);
              ph.set('currency', paymentEntity.currency || 'INR');
              ph.set('status', 'success');
              ph.set('event_type', 'subscription.charged');
              ph.set('timestamp', now.toISOString());
              ph.set('raw_payload', rawBody.substring(0, 5000));
              $app.save(ph);
            }
          } catch (logErr) {
            console.error('>>> [WEBHOOK_HOOK] Failed to log charged payment:', logErr);
          }
        }
        break;
      }
      case 'subscription.halted': {
        clinic.set('subscription_status', 'past_due');
        break;
      }
      case 'subscription.cancelled': {
        clinic.set('subscription_status', 'canceled');
        break;
      }
      case 'subscription.paused': {
        clinic.set('subscription_status', 'paused');
        break;
      }
      case 'subscription.resumed': {
        clinic.set('subscription_status', 'active');
        break;
      }
      case 'subscription.completed': {
        clinic.set('subscription_status', 'expired');
        break;
      }
      case 'subscription.expired': {
        clinic.set('subscription_status', 'expired');
        break;
      }
      case 'subscription.pending': {
        // No action needed; subscription is pending first payment
        console.log(`>>> [WEBHOOK_HOOK] Subscription pending for clinic ${clinic.id}`);
        return e.json(200, { message: 'Pending event acknowledged' });
      }
      default: {
        console.log(`>>> [WEBHOOK_HOOK] Unhandled event: ${eventName}`);
        return e.json(200, { message: `Event ${eventName} acknowledged` });
      }
    }

    $app.save(clinic);
    console.log(`>>> [WEBHOOK_HOOK] Processed ${eventName} for clinic ${clinic.id}`);
    return e.json(200, { success: true, event: eventName });

  } catch (err) {
    console.error('>>> [WEBHOOK_HOOK] Error processing webhook:', err);
    return e.json(500, { error: 'Internal error processing webhook' });
  }
});
