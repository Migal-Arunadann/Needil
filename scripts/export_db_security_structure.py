#!/usr/bin/env python3
"""
PocketBase Comprehensive Database Structure & Security Inspector (Python CLI).

Fetches / parses all collections, fields, relations, indexes, auth options, and API rules
from PocketBase, performs security audit, maps cross-collection relations, and outputs:
  1. pb_db_security_structure.md (Full Markdown Security & Schema Report)
  2. pb_db_structure.json (Enriched schema with resolved cross-collection relations)
  3. pocketbase_live_schema.json (Raw JSON schema dump)

Usage:
  python scripts/export_db_security_structure.py --offline [pocketbase_live_schema.json]
  python scripts/export_db_security_structure.py [admin_email] [admin_password] [pb_url]
"""

import sys
import os
import json
import re
import urllib.request
import urllib.error
import getpass
from datetime import datetime, timezone

# Ensure utf-8 stdout on Windows
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

DEFAULT_PB_URL = "https://api.needil.com"


def detect_pb_url():
    try:
        path = os.path.join("lib", "core", "providers", "pocketbase_provider.dart")
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
                m = re.search(r"pbBaseUrl\s*=\s*['\"]([^'\"]+)['\"]", content)
                if m:
                    return m.group(1)
    except Exception:
        pass
    return DEFAULT_PB_URL


def format_rule_badge(rule):
    if rule is None:
        return "[ADMIN ONLY]"
    if rule == "":
        return "[PUBLIC OPEN]"
    return "[AUTH SCOPED]"


def format_md_rule(rule):
    if rule is None:
        return "🔒 `null`"
    if rule == "":
        return "🔴 `\"\"` *(Open)*"
    r_str = str(rule)
    if len(r_str) > 55:
        return f"🟡 `{r_str[:52]}...`"
    return f"🟡 `{r_str}`"


def extract_fields(col):
    return col.get("fields") or col.get("schema") or []


def admin_auth(pb_url, email, password):
    auth_url = f"{pb_url}/api/collections/_superusers/auth-with-password"
    payload = json.dumps({"identity": email, "password": password}).encode("utf-8")
    req = urllib.request.Request(auth_url, data=payload, headers={"Content-Type": "application/json"})
    
    try:
        with urllib.request.urlopen(req) as res:
            data = json.loads(res.read().decode("utf-8"))
            if "token" in data:
                return data["token"]
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        try:
            data = json.loads(body)
        except Exception:
            data = {}
        
        mfa_id = data.get("mfaId")
        if e.code in (401, 403) or mfa_id:
            print(f"   [!] OTP / 2FA required for superadmin: {email}")
            print("   Requesting OTP from PocketBase...")
            otp_url = f"{pb_url}/api/collections/_superusers/request-otp"
            otp_req = urllib.request.Request(
                otp_url,
                data=json.dumps({"email": email}).encode("utf-8"),
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(otp_req) as otp_res:
                otp_data = json.loads(otp_res.read().decode("utf-8"))
                otp_id = otp_data["otpId"]
            
            print(f"   Check your email ({email}) for the OTP code.")
            otp_code = input("   Enter OTP Code: ").strip()
            
            verify_url = f"{pb_url}/api/collections/_superusers/auth-with-otp"
            verify_payload = {"otpId": otp_id, "password": otp_code}
            if mfa_id:
                verify_payload["mfaId"] = mfa_id
            verify_req = urllib.request.Request(
                verify_url,
                data=json.dumps(verify_payload).encode("utf-8"),
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(verify_req) as v_res:
                v_data = json.loads(v_res.read().decode("utf-8"))
                return v_data["token"]
        else:
            raise RuntimeError(f"Authentication failed ({e.code}): {body}")


def main():
    print("=" * 80)
    print("POCKETBASE COMPLETE DATABASE STRUCTURE & SECURITY INSPECTION")
    print("=" * 80 + "\n")

    is_offline = "--offline" in sys.argv
    collections = []
    source_info = ""

    if is_offline:
        schema_file = "pocketbase_live_schema.json"
        for i, arg in enumerate(sys.argv):
            if arg == "--offline" and i + 1 < len(sys.argv) and not sys.argv[i + 1].startswith("-"):
                schema_file = sys.argv[i + 1]
        
        if not os.path.exists(schema_file):
            print(f"Error: Offline schema file '{schema_file}' not found.")
            sys.exit(1)
        
        print(f"Loading offline schema from: {schema_file}...")
        with open(schema_file, "r", encoding="utf-8") as f:
            raw = json.load(f)
            collections = raw if isinstance(raw, list) else raw.get("items", [])
        source_info = f"Offline File: {schema_file}"
    else:
        pb_url = detect_pb_url()
        email = ""
        password = ""

        args = [a for a in sys.argv[1:] if not a.startswith("-")]
        if len(args) >= 2:
            email, password = args[0], args[1]
            if len(args) >= 3:
                pb_url = args[2]
        
        if not email or not password:
            print(f"PocketBase Server: {pb_url}")
            email = input("Enter Superadmin Email: ").strip()
            password = getpass.getpass("Enter Superadmin Password: ").strip()
            print()

        if not email or not password:
            print("Error: Email and password are required.")
            print("Tip: Use --offline to analyze existing pocketbase_live_schema.json.")
            sys.exit(1)

        try:
            print("1. Authenticating as Superadmin (supporting MFA & OTP)...")
            token = admin_auth(pb_url, email, password)
            print("   Authenticated successfully.\n")

            print("2. Fetching collections from /api/collections...")
            req = urllib.request.Request(
                f"{pb_url}/api/collections?perPage=500",
                headers={"Authorization": token}
            )
            with urllib.request.urlopen(req) as res:
                data = json.loads(res.read().decode("utf-8"))
                collections = data.get("items", [])
            
            with open("pocketbase_live_schema.json", "w", encoding="utf-8") as f:
                json.dump(collections, f, indent=2)
            print("   Raw schema saved to pocketbase_live_schema.json\n")
            source_info = f"Live PocketBase Server: {pb_url}"
        except Exception as e:
            print(f"Connection error: {e}")
            if os.path.exists("pocketbase_live_schema.json"):
                print("Falling back to pocketbase_live_schema.json...")
                with open("pocketbase_live_schema.json", "r", encoding="utf-8") as f:
                    collections = json.load(f)
                source_info = "Offline Fallback: pocketbase_live_schema.json"
            else:
                sys.exit(1)

    # Sort collections (regular first, system _* last)
    def sort_key(c):
        name = c.get("name", "")
        return (1 if name.startswith("_") else 0, name)

    collections.sort(key=sort_key)

    id_to_name = {c.get("id"): c.get("name") for c in collections if c.get("id") and c.get("name")}
    
    relations = []
    incoming_relations = {}

    for col in collections:
        source_name = col.get("name", "")
        source_id = col.get("id", "")
        fields = extract_fields(col)

        for f in fields:
            f_type = f.get("type", "")
            if f_type == "relation":
                target_id = f.get("collectionId") or (f.get("options") or {}).get("collectionId", "")
                target_name = id_to_name.get(target_id, target_id)
                max_select = f.get("maxSelect") or (f.get("options") or {}).get("maxSelect", 1)
                min_select = f.get("minSelect") or (f.get("options") or {}).get("minSelect", 0)
                cascade_delete = f.get("cascadeDelete") or (f.get("options") or {}).get("cascadeDelete", False)
                required = f.get("required", False)

                rel_info = {
                    "sourceCollection": source_name,
                    "sourceCollectionId": source_id,
                    "sourceField": f.get("name", ""),
                    "targetCollection": target_name,
                    "targetCollectionId": target_id,
                    "relationType": "Many-to-One (N:1)" if max_select == 1 else "Many-to-Many (N:M)",
                    "maxSelect": max_select,
                    "minSelect": min_select,
                    "cascadeDelete": bool(cascade_delete),
                    "required": bool(required),
                }
                relations.append(rel_info)
                incoming_relations.setdefault(target_name, []).append(rel_info)

    # Output Enriched JSON
    enriched = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "source": source_info,
        "collectionCount": len(collections),
        "relationCount": len(relations),
        "collections": [
            {**col, "resolvedIncomingRelations": incoming_relations.get(col.get("name", ""), [])}
            for col in collections
        ],
        "allRelations": relations,
    }
    with open("pb_db_structure.json", "w", encoding="utf-8") as f:
        json.dump(enriched, f, indent=2)

    # Generate Markdown Report
    md_lines = [
        "# PocketBase Database Security & Architecture Report",
        "",
        f"> **Generated:** {datetime.now(timezone.utc).isoformat()}  ",
        f"> **Data Source:** {source_info}  ",
        f"> **Total Collections:** {len(collections)}  ",
        f"> **Total Foreign-Key Relations:** {len(relations)}  ",
        "",
        "## 1. Security Overview & API Rule Audit",
        "",
        "| Collection | Type | List Rule | View Rule | Create Rule | Update Rule | Delete Rule |",
        "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |",
    ]

    for col in collections:
        name = col.get("name", "")
        ctype = col.get("type", "base")
        lR = format_md_rule(col.get("listRule"))
        vR = format_md_rule(col.get("viewRule"))
        cR = format_md_rule(col.get("createRule"))
        uR = format_md_rule(col.get("updateRule"))
        dR = format_md_rule(col.get("deleteRule"))
        md_lines.append(f"| **`{name}`** | `{ctype}` | {lR} | {vR} | {cR} | {uR} | {dR} |")

    md_lines.extend([
        "",
        "## 2. Database Entity-Relationship Diagram",
        "",
        "```mermaid",
        "erDiagram",
    ])

    for r in relations:
        src = r["sourceCollection"]
        tgt = r["targetCollection"]
        fld = r["sourceField"]
        md_lines.append(f'    {src} }}o--|| {tgt} : "{fld}"')

    md_lines.extend([
        "```",
        "",
        "## 3. Foreign Key Relations Matrix",
        "",
        "| Source Collection | Field Name | Target Collection | Cardinality | Cascade Delete | Required |",
        "| :--- | :--- | :--- | :--- | :--- | :--- |",
    ])

    for r in relations:
        src = r["sourceCollection"]
        fld = r["sourceField"]
        tgt = r["targetCollection"]
        card = r["relationType"]
        cascade = "✅ Yes" if r["cascadeDelete"] else "❌ No"
        req = "✅ Yes" if r["required"] else "❌ No"
        md_lines.append(f"| **`{src}`** | `{fld}` | **`{tgt}`** | {card} | {cascade} | {req} |")

    md_lines.extend(["", "## 4. Detailed Collection Specifications", ""])

    for col in collections:
        name = col.get("name", "")
        ctype = col.get("type", "base")
        cid = col.get("id", "")
        system = col.get("system", False)
        fields = extract_fields(col)
        indexes = col.get("indexes") or []

        md_lines.extend([
            f"### Collection: `{name}`",
            "",
            f"- **Collection ID:** `{cid}`",
            f"- **Type:** `{ctype}` {'(System Collection)' if system else ''}",
            "",
            "#### API Access Rules",
            "```",
            f"List Rule:   {'null (Superadmin Only)' if col.get('listRule') is None else '\"\" (Public Open)' if col.get('listRule') == '' else col.get('listRule')}",
            f"View Rule:   {'null (Superadmin Only)' if col.get('viewRule') is None else '\"\" (Public Open)' if col.get('viewRule') == '' else col.get('viewRule')}",
            f"Create Rule: {'null (Superadmin Only)' if col.get('createRule') is None else '\"\" (Public Open)' if col.get('createRule') == '' else col.get('createRule')}",
            f"Update Rule: {'null (Superadmin Only)' if col.get('updateRule') is None else '\"\" (Public Open)' if col.get('updateRule') == '' else col.get('updateRule')}",
            f"Delete Rule: {'null (Superadmin Only)' if col.get('deleteRule') is None else '\"\" (Public Open)' if col.get('deleteRule') == '' else col.get('deleteRule')}",
        ])
        if ctype == "auth":
            md_lines.append(f"Manage Rule: {'null (Superadmin Only)' if col.get('manageRule') is None else '\"\" (Public Open)' if col.get('manageRule') == '' else col.get('manageRule')}")
            md_lines.append(f"Auth Rule:   {col.get('authRule', 'Default')}")
        md_lines.extend(["```", ""])

        if indexes:
            md_lines.extend([f"#### Database Indexes ({len(indexes)})"])
            for idx in indexes:
                md_lines.append(f"- `{idx}`")
            md_lines.append("")

        inc = incoming_relations.get(name, [])
        if inc:
            md_lines.extend([f"#### Referenced By ({len(inc)} Inbound Relations)"])
            for item in inc:
                md_lines.append(f"- `{item['sourceCollection']}.{item['sourceField']}` ({item['relationType']})")
            md_lines.append("")

        md_lines.extend([
            f"#### Fields ({len(fields)})",
            "",
            "| Field Name | Type | Required | Unique | System | Details / Constraints |",
            "| :--- | :--- | :--- | :--- | :--- | :--- |",
        ])

        for f in fields:
            fname = f.get("name", "")
            ftype = f.get("type", "")
            freq = "✅" if f.get("required") else "—"
            funiq = "✅" if f.get("unique") else "—"
            fsys = "🔒" if f.get("system") else "—"

            parts = []
            if ftype == "relation":
                tid = f.get("collectionId") or (f.get("options") or {}).get("collectionId", "")
                tname = id_to_name.get(tid, tid)
                m = f.get("maxSelect") or (f.get("options") or {}).get("maxSelect", 1)
                cas = f.get("cascadeDelete") or (f.get("options") or {}).get("cascadeDelete", False)
                parts.append(f"-> **`{tname}`** (max: {m}{', cascadeDelete' if cas else ''})")
            elif ftype == "select":
                vals = f.get("values") or (f.get("options") or {}).get("values", [])
                m = f.get("maxSelect") or (f.get("options") or {}).get("maxSelect", 1)
                parts.append(f"Options: `{vals}` (max: {m})")
            elif ftype == "file":
                m = f.get("maxSelect") or (f.get("options") or {}).get("maxSelect", 1)
                ms = f.get("maxSize") or (f.get("options") or {}).get("maxSize", "N/A")
                parts.append(f"maxSelect: {m}, maxSize: {ms}B")
            elif ftype == "text":
                mn = f.get("min") or (f.get("options") or {}).get("min")
                mx = f.get("max") or (f.get("options") or {}).get("max")
                if mn: parts.append(f"min: {mn}")
                if mx: parts.append(f"max: {mx}")
            elif ftype == "number":
                mn = f.get("min") or (f.get("options") or {}).get("min")
                mx = f.get("max") or (f.get("options") or {}).get("max")
                if mn is not None: parts.append(f"min: {mn}")
                if mx is not None: parts.append(f"max: {mx}")

            details = "; ".join(parts) if parts else "—"
            md_lines.append(f"| **`{fname}`** | `{ftype}` | {freq} | {funiq} | {fsys} | {details} |")

        md_lines.extend(["", "---", ""])

    with open("pb_db_security_structure.md", "w", encoding="utf-8") as f:
        f.write("\n".join(md_lines) + "\n")

    print("Enriched JSON saved to: pb_db_structure.json")
    print("Markdown Report saved to: pb_db_security_structure.md")
    print("\n" + "=" * 80)
    print("Export complete!")
    print("=" * 80)


if __name__ == "__main__":
    main()
