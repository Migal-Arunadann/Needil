/// PocketBase JS Hook — Fast Indexed Username Availability Check
///
/// Route: GET /api/check-username?username=<candidate>
/// Returns: { "available": boolean, "exists": boolean, "error"?: string }

routerAdd("GET", "/api/check-username", (c) => {
    const rawUsername = c.request().url.query().get("username") || "";
    const username = rawUsername.trim().toLowerCase();

    if (!username || username.length < 3) {
        return c.json(400, {
            "available": false,
            "exists": false,
            "error": "Username must be at least 3 characters."
        });
    }

    if (username.length > 30) {
        return c.json(400, {
            "available": false,
            "exists": false,
            "error": "Username cannot exceed 30 characters."
        });
    }

    // Instagram-style format: lowercase alphanumeric, underscore, dot.
    // Cannot start with a period, cannot end with a period, cannot have consecutive periods.
    const validFormat = /^[a-z0-9_](?:[a-z0-9_.]*[a-z0-9_])?$/.test(username) && !username.includes("..");
    if (!validFormat) {
        return c.json(400, {
            "available": false,
            "exists": false,
            "error": "Usernames can only contain letters, numbers, underscores, and periods."
        });
    }

    // 1. Direct indexed B-Tree point-lookup in clinics
    try {
        let clinic = null;
        if (typeof $app.findFirstRecordByData === "function") {
            clinic = $app.findFirstRecordByData("clinics", "username", username);
        } else if ($app.dao && typeof $app.dao().findFirstRecordByData === "function") {
            clinic = $app.dao().findFirstRecordByData("clinics", "username", username);
        }
        if (clinic) {
            return c.json(200, { "available": false, "exists": true, "reason": "taken" });
        }
    } catch (_) {}

    // 2. Direct indexed B-Tree point-lookup in doctors
    try {
        let doctor = null;
        if (typeof $app.findFirstRecordByData === "function") {
            doctor = $app.findFirstRecordByData("doctors", "username", username);
        } else if ($app.dao && typeof $app.dao().findFirstRecordByData === "function") {
            doctor = $app.dao().findFirstRecordByData("doctors", "username", username);
        }
        if (doctor) {
            return c.json(200, { "available": false, "exists": true, "reason": "taken" });
        }
    } catch (_) {}

    // 3. Direct indexed B-Tree point-lookup in receptionists
    try {
        let receptionist = null;
        if (typeof $app.findFirstRecordByData === "function") {
            receptionist = $app.findFirstRecordByData("receptionists", "username", username);
        } else if ($app.dao && typeof $app.dao().findFirstRecordByData === "function") {
            receptionist = $app.dao().findFirstRecordByData("receptionists", "username", username);
        }
        if (receptionist) {
            return c.json(200, { "available": false, "exists": true, "reason": "taken" });
        }
    } catch (_) {}

    return c.json(200, { "available": true, "exists": false });
});
