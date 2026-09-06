/// <reference path="../pb_data/types.d.ts" />

/**
 * Needil PMS — Razorpay Subscription Management Routes
 * All payment secret handling happens server-side here.
 * The Flutter client NEVER receives RAZORPAY_KEY_SECRET.
 */

console.log('>>> [RAZORPAY_HOOKS] Subscription hooks loaded');

const RZP_KEY_ID = $os.getenv('RAZORPAY_KEY_ID') || '';
const RZP_KEY_SECRET = $os.getenv('RAZORPAY_KEY_SECRET') || '';

// Pure-JS base64 (btoa / $security.base64Encode not available in this PB runtime)
function _base64(str) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let out = '';
  for (let block, code, idx = 0, map = chars;
       str.charAt(idx | 0) || (map = '=', idx % 1);
       out += map.charAt(63 & block >> 8 - idx % 1 * 8)) {
    code = str.charCodeAt(idx += 3 / 4);
    block = block << 8 | code;
  }
  return out;
}

const RZP_AUTH = 'Basic ' + _base64(RZP_KEY_ID + ':' + RZP_KEY_SECRET);

// Helper: get authenticated record from PocketBase request context
function getAuth(e) {
  if (e.auth) return e.auth;
  if (e.get && typeof e.get === 'function') {
    const rec = e.get('authRecord');
    if (rec) return rec;
  }
  if (e.httpContext && typeof e.httpContext.get === 'function') {
    const rec = e.httpContext.get('authRecord');
    if (rec) return rec;
  }
  try {
    if (typeof $app.requestInfo === 'function') {
      const info = $app.requestInfo();
      if (info && info.authRecord) return info.authRecord;
    }
  } catch (_) {}
  return null;
}

// Helper: save record across PB versions
function saveRecord(record) {
  if (typeof $app.save === 'function') {
    return $app.save(record);
  }
  if ($app.dao && typeof $app.dao().saveRecord === 'function') {
    return $app.dao().saveRecord(record);
  }
}

// Helper: find record by ID across PB versions
function findRecordById(collection, id) {
  try {
    if (typeof $app.findRecordById === 'function') {
      return $app.findRecordById(collection, id);
    }
    if ($app.dao && typeof $app.dao().findRecordById === 'function') {
      return $app.dao().findRecordById(collection, id);
    }
  } catch (_) {}
  return null;
}

// Helper: find first record by filter across PB versions
function findFirstRecordByFilter(collection, filter) {
  try {
    if (typeof $app.findFirstRecordByFilter === 'function') {
      return $app.findFirstRecordByFilter(collection, filter);
    }
    if ($app.dao && typeof $app.dao().findFirstRecordByFilter === 'function') {
      return $app.dao().findFirstRecordByFilter(collection, filter);
    }
  } catch (_) {}
  return null;
}

// Helper: find collection
function findCollection(nameOrId) {
  try {
    if (typeof $app.findCollectionByNameOrId === 'function') {
      return $app.findCollectionByNameOrId(nameOrId);
    }
    if ($app.dao && typeof $app.dao().findCollectionByNameOrId === 'function') {
      return $app.dao().findCollectionByNameOrId(nameOrId);
    }
  } catch (_) {}
  return null;
}


// Helper: get system setting value
function getSystemSetting(key, defaultValue) {
  try {
    const record = findFirstRecordByFilter('system_settings', `key = '${key}'`);
    return record ? record.getString('value') : defaultValue;
  } catch (_) {
    return defaultValue;
  }
}

// Helper: find clinic record by id
function findClinic(clinicId) {
  return findRecordById('clinics', clinicId);
}

// ─── Route 1: Start Free Trial ───────────────────────────────────────────────
// POST /api/custom/start-trial
routerAdd('POST', '/api/custom/start-trial', (e) => {
  const auth = e.auth;
  if (!auth) {
    return e.json(401, { error: 'Unauthorized' });
  }

  try {
    const clinic = findClinic(auth.id);
    if (!clinic) {
      return e.json(404, { error: 'Clinic not found' });
    }

    // Server-side trial abuse prevention
    if (clinic.getBool('has_used_trial')) {
      return e.json(400, { error: 'Free trial already used for this account' });
    }

    const trialDays = parseInt(getSystemSetting('default_trial_days', '14'));
    const now = new Date();
    const trialEnd = new Date(now.getTime() + trialDays * 24 * 60 * 60 * 1000);

    // Apply promo extended trial if code was passed
    let promoCode = '';
    let extraDays = 0;
    try {
      const body = (e.request.data || {});
      promoCode = body.promoCode || '';
    } catch (_) {}

    if (promoCode) {
      try {
        const promo = findFirstRecordByFilter(
          'promo_codes',
          `code = '${promoCode}' && discount_type = 'extended_trial' && is_active = true`
        );
        if (promo) {
          const validUntil = promo.getString('valid_until');
          const maxUses = promo.getInt('max_uses');
          const timesUsed = promo.getInt('times_used');
          const now2 = new Date();
          const isExpired = validUntil && new Date(validUntil) < now2;
          const isExhausted = maxUses > 0 && timesUsed >= maxUses;
          if (!isExpired && !isExhausted) {
            extraDays = promo.getInt('discount_value');
            // Increment usage
            promo.set('times_used', timesUsed + 1);
            saveRecord(promo);
          }
        }
      } catch (_) {}
    }

    if (extraDays > 0) {
      trialEnd.setTime(trialEnd.getTime() + extraDays * 24 * 60 * 60 * 1000);
    }

    clinic.set('subscription_status', 'trialing');
    clinic.set('subscription_end_date', trialEnd.toISOString());
    clinic.set('has_used_trial', true);
    clinic.set('trial_started_at', now.toISOString());
    if (promoCode) clinic.set('promo_code_used', promoCode);
    saveRecord(clinic);

    console.log(`>>> [RAZORPAY_HOOKS] Trial started for clinic ${auth.id}, ends ${trialEnd.toISOString()}`);
    return e.json(200, {
      success: true,
      trialEndDate: trialEnd.toISOString(),
      trialDays: trialDays + extraDays,
    });
  } catch (err) {
    console.error('>>> [RAZORPAY_HOOKS] start-trial error:', err);
    return e.json(500, { error: 'Failed to start trial' });
  }
});

// ─── Route 2: Validate Promo Code ────────────────────────────────────────────
// POST /api/custom/validate-promo
routerAdd('POST', '/api/custom/validate-promo', (e) => {
  const auth = e.auth;
  if (!auth) {
    return e.json(401, { error: 'Unauthorized' });
  }

  let body;
  try {
    body = (e.request.data || {});
  } catch (_) {
    return e.json(400, { error: 'Invalid JSON body' });
  }

  const code = (body.code || '').toUpperCase();
  const billingCycle = body.billingCycle || '';
  const planId = body.planId || '';

  if (!code) {
    return e.json(400, { error: 'Promo code is required' });
  }

  try {
    const promo = findFirstRecordByFilter(
      'promo_codes',
      `code = '${code}'`
    );

    if (!promo) {
      return e.json(200, { valid: false, error: 'Promo code not found' });
    }

    if (!promo.getBool('is_active')) {
      return e.json(200, { valid: false, error: 'This promo code is no longer active' });
    }

    const validFrom = promo.getString('valid_from');
    const validUntil = promo.getString('valid_until');
    const now = new Date();

    if (validFrom && new Date(validFrom) > now) {
      return e.json(200, { valid: false, error: 'This promo code is not yet active' });
    }
    if (validUntil && new Date(validUntil) < now) {
      return e.json(200, { valid: false, error: 'This promo code has expired' });
    }

    const maxUses = promo.getInt('max_uses');
    const timesUsed = promo.getInt('times_used');
    if (maxUses > 0 && timesUsed >= maxUses) {
      return e.json(200, { valid: false, error: 'This promo code has reached its usage limit' });
    }

    // Check applicable cycles
    const applicableCycles = promo.getString('applicable_cycles');
    if (applicableCycles && billingCycle) {
      const allowed = applicableCycles.split(',').map(s => s.trim());
      if (!allowed.includes(billingCycle)) {
        return e.json(200, { valid: false, error: `This promo code is not valid for the ${billingCycle} plan` });
      }
    }

    const discountType = promo.getString('discount_type');
    const discountValue = promo.getInt('discount_value');

    // Calculate discounted price if planId provided
    let finalPricePaise = null;
    let discountAmountPaise = null;
    let extraTrialDays = null;

    if (discountType === 'extended_trial') {
      extraTrialDays = discountValue;
    } else if (planId) {
      try {
        const plan = findRecordById('subscription_plans', planId);
        if (plan) {
          const originalPrice = plan.getInt('price_paise');
          if (discountType === 'percentage') {
            discountAmountPaise = Math.floor(originalPrice * discountValue / 100);
          } else if (discountType === 'fixed') {
            discountAmountPaise = Math.min(discountValue, originalPrice);
          }
          finalPricePaise = Math.max(0, originalPrice - discountAmountPaise);
        }
      } catch (_) {}
    }

    return e.json(200, {
      valid: true,
      discountType,
      discountValue,
      finalPricePaise,
      discountAmountPaise,
      extraTrialDays,
      promoCode: promo.getString('code'),
    });
  } catch (err) {
    console.error('>>> [RAZORPAY_HOOKS] validate-promo error:', err);
    return e.json(500, { error: 'Failed to validate promo code' });
  }
});

// ─── Route 3: Create Subscription ────────────────────────────────────────────
// POST /api/custom/create-subscription
routerAdd('POST', '/api/custom/create-subscription', (e) => {
  const auth = e.auth;
  if (!auth) {
    return e.json(401, { error: 'Unauthorized' });
  }

  if (!RZP_KEY_ID || !RZP_KEY_SECRET) {
    return e.json(500, { error: 'Razorpay is not configured. Contact support.' });
  }

  let body;
  try {
    body = (e.request.data || {});
  } catch (_) {
    return e.json(400, { error: 'Invalid JSON body' });
  }

  const planId = body.planId || '';
  const promoCode = (body.promoCode || '').toUpperCase();

  if (!planId) {
    return e.json(400, { error: 'planId is required' });
  }

  try {
    const plan = findRecordById('subscription_plans', planId);
    if (!plan) {
      return e.json(404, { error: 'Plan not found' });
    }

    const razorpayPlanId = plan.getString('razorpay_plan_id');
    if (!razorpayPlanId) {
      return e.json(400, { error: 'This plan is not yet configured with a Razorpay Plan ID. Contact support.' });
    }

    const clinic = findClinic(auth.id);
    if (!clinic) {
      return e.json(404, { error: 'Clinic not found' });
    }

    // Determine total billing cycles based on billing cycle type
    const billingCycle = plan.getString('billing_cycle');
    let totalCount = 12; // default monthly
    if (billingCycle === 'semi_annual') totalCount = 4;
    if (billingCycle === 'annual') totalCount = 5;

    // Build Razorpay subscription payload
    const subscriptionPayload = {
      plan_id: razorpayPlanId,
      total_count: totalCount,
      quantity: 1,
      customer_notify: 1,
      notes: {
        clinic_id: auth.id,
        plan_id: planId,
        billing_cycle: billingCycle,
        promo_code: promoCode,
      },
    };

    // Call Razorpay Subscriptions API
    const response = $http.send({
      method: 'POST',
      url: 'https://api.razorpay.com/v1/subscriptions',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': RZP_AUTH,
      },
      body: JSON.stringify(subscriptionPayload),
      timeout: 30,
    });

    if (response.statusCode !== 200 && response.statusCode !== 201) {
      console.error('>>> [RAZORPAY_HOOKS] Razorpay error:', response.raw);
      return e.json(502, { error: 'Failed to create subscription with Razorpay. Please try again.' });
    }

    const rzpData = JSON.parse(response.raw);

    // Save subscription ID on clinic record
    clinic.set('razorpay_subscription_id', rzpData.id);
    clinic.set('subscription_plan_id', planId);
    if (promoCode) clinic.set('promo_code_used', promoCode);
    saveRecord(clinic);

    console.log(`>>> [RAZORPAY_HOOKS] Subscription created: ${rzpData.id} for clinic ${auth.id}`);

    return e.json(200, {
      subscriptionId: rzpData.id,
      shortUrl: rzpData.short_url || '',
      razorpayKeyId: RZP_KEY_ID,
    });
  } catch (err) {
    console.error('>>> [RAZORPAY_HOOKS] create-subscription error:', err);
    return e.json(500, { error: 'Failed to create subscription' });
  }
});

// ─── Route 4: Verify Payment ──────────────────────────────────────────────────
// POST /api/custom/verify-payment
routerAdd('POST', '/api/custom/verify-payment', (e) => {
  const auth = e.auth;
  if (!auth) {
    return e.json(401, { error: 'Unauthorized' });
  }

  let body;
  try {
    body = (e.request.data || {});
  } catch (_) {
    return e.json(400, { error: 'Invalid JSON body' });
  }

  const { paymentId, subscriptionId, signature } = body;
  if (!paymentId || !subscriptionId || !signature) {
    return e.json(400, { error: 'paymentId, subscriptionId, and signature are required' });
  }

  try {
    // Verify HMAC-SHA256 signature
    const message = paymentId + '|' + subscriptionId;
    const expectedSignature = $security.hs256(message, RZP_KEY_SECRET);

    if (signature !== expectedSignature) {
      console.error(`>>> [RAZORPAY_HOOKS] Signature mismatch for payment ${paymentId}`);
      return e.json(400, { error: 'Payment verification failed: invalid signature' });
    }

    const clinic = findClinic(auth.id);
    if (!clinic) {
      return e.json(404, { error: 'Clinic not found' });
    }

    // Determine plan details from saved subscription_plan_id
    let billingCycle = 'monthly';
    let pricePaise = 0;
    const planId = clinic.getString('subscription_plan_id');
    let planRecord = null;
    if (planId) {
      try {
        planRecord = findRecordById('subscription_plans', planId);
        if (planRecord) {
          billingCycle = planRecord.getString('billing_cycle');
          pricePaise = planRecord.getInt('price_paise');
        }
      } catch (_) {}
    }

    // Calculate subscription end date from billing cycle
    const now = new Date();
    let endDate = new Date(now);
    if (billingCycle === 'monthly') endDate.setMonth(endDate.getMonth() + 1);
    else if (billingCycle === 'semi_annual') endDate.setMonth(endDate.getMonth() + 6);
    else if (billingCycle === 'annual') endDate.setFullYear(endDate.getFullYear() + 1);

    // Update clinic subscription
    clinic.set('subscription_status', 'active');
    clinic.set('subscription_end_date', endDate.toISOString());
    clinic.set('razorpay_subscription_id', subscriptionId);
    saveRecord(clinic);

    // Log to payment_history
    try {
      const paymentHistoryCol = findCollection('payment_history');
      if (paymentHistoryCol) {
        const histRecord = new Record(paymentHistoryCol);
        histRecord.set('clinic_id', auth.id);
        histRecord.set('razorpay_payment_id', paymentId);
        histRecord.set('razorpay_subscription_id', subscriptionId);
        histRecord.set('amount_paise', pricePaise);
        histRecord.set('currency', 'INR');
        histRecord.set('status', 'success');
        histRecord.set('billing_cycle', billingCycle);
        histRecord.set('promo_code', clinic.getString('promo_code_used') || '');
        histRecord.set('event_type', 'payment.verified');
        histRecord.set('timestamp', now.toISOString());
        saveRecord(histRecord);
      }
    } catch (logErr) {
      console.error('>>> [RAZORPAY_HOOKS] Failed to log payment history:', logErr);
    }

    console.log(`>>> [RAZORPAY_HOOKS] Payment verified: ${paymentId}, clinic ${auth.id} now active until ${endDate.toISOString()}`);
    return e.json(200, {
      success: true,
      subscriptionStatus: 'active',
      subscriptionEndDate: endDate.toISOString(),
    });
  } catch (err) {
    console.error('>>> [RAZORPAY_HOOKS] verify-payment error:', err);
    return e.json(500, { error: 'Failed to verify payment' });
  }
});
