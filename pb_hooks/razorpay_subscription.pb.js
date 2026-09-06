/// <reference path=" ../pb_data/types.d.ts\ />

console.log('>>> [RAZORPAY_HOOKS] Subscription hooks loaded');

routerAdd('POST', '/api/custom/start-trial', (e) => {
 const auth = e.auth;
 if (!auth) return e.json(401, { error: 'Unauthorized' });
 try {
 const clinic = .findRecordById('clinics', auth.id);
 if (!clinic) return e.json(404, { error: 'Clinic not found' });
 const hasTrial = clinic.get('has_used_trial');
 if (hasTrial === true || hasTrial === 1 || hasTrial === 'true') {
 return e.json(400, { error: 'Free trial already used for this account' });
 }
 const now = new Date();
 const trialEnd = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);
 clinic.set('subscription_status', 'trialing');
 clinic.set('trial_start_date', now.toISOString());
 clinic.set('trial_end_date', trialEnd.toISOString());
 clinic.set('subscription_end_date', trialEnd.toISOString());
 clinic.set('has_used_trial', true);
 .save(clinic);
 return e.json(200, { success: true, trialEndDate: trialEnd.toISOString(), trialDays: 14 });
 } catch (err) {
 console.error('>>> [RAZORPAY_HOOKS] start-trial error:', err);
 return e.json(500, { error: 'Failed to start trial: ' + (err.message || String(err)) });
 }
});

routerAdd('POST', '/api/custom/validate-promo', (e) => {
 const auth = e.auth;
 if (!auth) return e.json(401, { error: 'Unauthorized' });
 return e.json(200, { valid: false, discount: 0 });
});

routerAdd('POST', '/api/custom/create-subscription', (e) => {
 const auth = e.auth;
 if (!auth) return e.json(401, { error: 'Unauthorized' });

 const KEY_ID = .getenv('RAZORPAY_KEY_ID') || '';
 const KEY_SECRET = .getenv('RAZORPAY_KEY_SECRET') || '';
 if (!KEY_ID || !KEY_SECRET) return e.json(500, { error: 'Razorpay not configured' });

 const AUTH_HEADER = 'Basic ' + (function(s) {
 var ch = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/', o = '';
 for (var bl, x, i = 0, m = ch; s.charAt(i | 0) || (m = '=', i % 1); o += m.charAt(63 & bl >> 8 - i % 1 * 8)) {
 x = s.charCodeAt(i += 3 / 4);
 bl = bl << 8 | x;
 }
 return o;
 })(KEY_ID + ':' + KEY_SECRET);

 let planId = '';
 let promoCode = '';

 // 1. Try e.requestInfo().body
 try {
 const ri = e.requestInfo();
 if (ri && ri.body) {
 if (typeof ri.body === 'string') {
 const parsed = JSON.parse(ri.body);
 planId = (parsed.planId || '').toString();
 promoCode = (parsed.promoCode || '').toString();
 } else if (typeof ri.body === 'object') {
 planId = (ri.body.planId || ri.body['planId'] || '').toString();
 promoCode = (ri.body.promoCode || ri.body['promoCode'] || '').toString();
 }
 }
 } catch (err) {
 console.log('>>> [RAZORPAY_HOOKS] requestInfo error:', err);
 }

 // 2. Try e.bindBody with predefined keys
 if (!planId) {
 try {
 const data = { planId: '', promoCode: '' };
 e.bindBody(data);
 if (data.planId) planId = data.planId.toString();
 if (data.promoCode) promoCode = data.promoCode.toString();
 } catch (err) {
 console.log('>>> [RAZORPAY_HOOKS] bindBody error:', err);
 }
 }

 if (!planId) {
 console.error('>>> [RAZORPAY_HOOKS] planId missing. requestInfo:', JSON.stringify(e.requestInfo() || {}));
 return e.json(400, { error: 'planId is required' });
 }

 try {
 const plan = .findRecordById('subscription_plans', planId);
 if (!plan) return e.json(404, { error: 'Plan not found' });
 const rzpPlanId = plan.get('razorpay_plan_id') || (plan.getString ? plan.getString('razorpay_plan_id') : '');
 if (!rzpPlanId) return e.json(400, { error: 'Plan not configured with Razorpay ID' });

 const clinic = .findRecordById('clinics', auth.id);
 if (!clinic) return e.json(404, { error: 'Clinic not found' });

 const billing = plan.get('billing_cycle') || (plan.getString ? plan.getString('billing_cycle') : '') || 'monthly';
 let totalCount = 12;
 if (billing === 'semi_annual') totalCount = 4;
 if (billing === 'annual') totalCount = 5;

 const resp = .send({
 method: 'POST',
 url: 'https://api.razorpay.com/v1/subscriptions',
 headers: {
 'Content-Type': 'application/json',
 'Authorization': AUTH_HEADER,
 },
 body: JSON.stringify({
 plan_id: rzpPlanId,
 total_count: totalCount,
 quantity: 1,
 customer_notify: 1,
 notes: {
 clinic_id: auth.id,
 plan_id: planId,
 },
 }),
 timeout: 30,
 });

 if (resp.statusCode !== 200 && resp.statusCode !== 201) {
 console.error('>>> [RAZORPAY_HOOKS] Razorpay API error:', resp.raw);
 return e.json(502, { error: 'Razorpay error: ' + resp.raw });
 }

 const rzp = resp.json || JSON.parse(resp.raw || '{}');
 clinic.set('razorpay_subscription_id', rzp.id);
 clinic.set('subscription_plan_id', planId);
 .save(clinic);

 console.log('>>> [RAZORPAY_HOOKS] Subscription created:', rzp.id);
 return e.json(200, {
 subscriptionId: rzp.id,
 shortUrl: rzp.short_url || '',
 razorpayKeyId: KEY_ID,
 });
 } catch (err) {
 console.error('>>> [RAZORPAY_HOOKS] create-subscription error:', err);
 return e.json(500, { error: 'Failed: ' + (err.message || String(err)) });
 }
});

routerAdd('POST', '/api/custom/verify-payment', (e) => {
 const auth = e.auth;
 if (!auth) return e.json(401, { error: 'Unauthorized' });

 const KEY_SECRET = .getenv('RAZORPAY_KEY_SECRET') || '';
 let paymentId = '';
 let subscriptionId = '';
 let sig = '';

 // 1. Try e.requestInfo().body
 try {
 const ri = e.requestInfo();
 if (ri && ri.body) {
 if (typeof ri.body === 'string') {
 const parsed = JSON.parse(ri.body);
 paymentId = (parsed.paymentId || '').toString();
 subscriptionId = (parsed.subscriptionId || '').toString();
 sig = (parsed.signature || '').toString();
 } else if (typeof ri.body === 'object') {
 paymentId = (ri.body.paymentId || ri.body['paymentId'] || '').toString();
 subscriptionId = (ri.body.subscriptionId || ri.body['subscriptionId'] || '').toString();
 sig = (ri.body.signature || ri.body['signature'] || '').toString();
 }
 }
 } catch (_) {}

 // 2. Try e.bindBody
 if (!paymentId || !subscriptionId || !sig) {
 try {
 const data = { paymentId: '', subscriptionId: '', signature: '' };
 e.bindBody(data);
 paymentId = paymentId || (data.paymentId || '').toString();
 subscriptionId = subscriptionId || (data.subscriptionId || '').toString();
 sig = sig || (data.signature || '').toString();
 } catch (_) {}
 }

 if (!paymentId || !subscriptionId || !sig) {
 return e.json(400, { error: 'Missing required fields: paymentId, subscriptionId, signature' });
 }

 try {
 const expected = .hs256(paymentId + '|' + subscriptionId, KEY_SECRET);
 if (expected !== sig) {
 console.error('>>> [RAZORPAY_HOOKS] Signature mismatch. Expected:', expected, 'Got:', sig);
 return e.json(400, { error: 'Invalid payment signature' });
 }
 const clinic = .findRecordById('clinics', auth.id);
 if (!clinic) return e.json(404, { error: 'Clinic not found' });
 clinic.set('subscription_status', 'active');
 clinic.set('last_payment_id', paymentId);
 .save(clinic);
 console.log('>>> [RAZORPAY_HOOKS] Payment verified for clinic:', auth.id);
 return e.json(200, { success: true, subscriptionStatus: 'active' });
 } catch (err) {
 console.error('>>> [RAZORPAY_HOOKS] verify-payment error:', err);
 return e.json(500, { error: 'Failed: ' + (err.message || String(err)) });
 }
});
