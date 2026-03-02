#!/usr/bin/env python3
"""
Generate the OncoKB Transcript JWT token programmatically for dev/prod.

The token is used by the OncoKB service to authenticate to the oncokb-transcript
service. The transcript service validates the token using the same base64 secret.

Usage (prefer pixi so Terraform and script share one environment):
    pixi run generate-transcript-token
    pixi run generate-transcript-token --generate-secret
    pixi run generate-transcript-token --out token.txt
OR with pip: pip install -r scripts/requirements.txt then
    export ONCOKB_TRANSCRIPT_JWT_BASE64_SECRET="$(openssl rand -base64 32)"
    python scripts/generate_transcript_token.py
    python scripts/generate_transcript_token.py --generate-secret
    python scripts/generate_transcript_token.py --out token.txt

    # Same for prod: set ONCOKB_TRANSCRIPT_JWT_BASE64_SECRET to your prod secret
    export ONCOKB_TRANSCRIPT_JWT_BASE64_SECRET="<prod-secret-from-vault>"
    python scripts/generate_transcript_token.py --out prod_token.txt

Then:
    - Configure oncokb-transcript with JHIPSTER_SECURITY_AUTHENTICATION_JWT_BASE64_SECRET=<secret>
    - Configure OncoKB with -Doncokb_transcript.token=<token> (or TF_VAR_oncokb_transcript_jwt_token)
"""

import argparse
import base64
import os
import secrets
import sys
import time


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate OncoKB Transcript JWT (HS256, auth=ROLE_ADMIN)"
    )
    parser.add_argument(
        "--generate-secret",
        action="store_true",
        help="Generate a new base64 secret and print it (store it for transcript service and future runs)",
    )
    parser.add_argument(
        "--out",
        metavar="FILE",
        help="Write the JWT token to FILE instead of stdout",
    )
    parser.add_argument(
        "--sub",
        default="oncokb-service",
        help="JWT subject (default: oncokb-service)",
    )
    parser.add_argument(
        "--name",
        default="OncoKB",
        help="JWT name claim (default: OncoKB)",
    )
    args = parser.parse_args()

    secret_b64 = os.environ.get("ONCOKB_TRANSCRIPT_JWT_BASE64_SECRET")
    if args.generate_secret:
        secret_b64 = base64.b64encode(secrets.token_bytes(32)).decode("ascii")
        print(
            "Generated base64 secret (set this in oncokb-transcript and in ONCOKB_TRANSCRIPT_JWT_BASE64_SECRET):",
            file=sys.stderr,
        )
        print(secret_b64, file=sys.stderr)
        print("", file=sys.stderr)
    elif not secret_b64:
        print(
            "Error: Set ONCOKB_TRANSCRIPT_JWT_BASE64_SECRET or use --generate-secret",
            file=sys.stderr,
        )
        sys.exit(1)

    try:
        key_bytes = base64.b64decode(secret_b64)
    except Exception as e:
        print(f"Error: Invalid base64 secret: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        import jwt
    except ImportError:
        print(
            "Error: Install PyJWT via pixi (pixi install) or pip install -r scripts/requirements.txt",
            file=sys.stderr,
        )
        sys.exit(1)

    payload = {
        "sub": args.sub,
        "name": args.name,
        "auth": "ROLE_ADMIN",
        "iat": int(time.time()),
    }
    token = jwt.encode(
        payload,
        key=key_bytes,
        algorithm="HS256",
    )
    if hasattr(token, "decode"):
        token = token.decode("utf-8")

    if args.out:
        with open(args.out, "w") as f:
            f.write(token)
        print(f"Token written to {args.out}", file=sys.stderr)
    else:
        print(token)


if __name__ == "__main__":
    main()
