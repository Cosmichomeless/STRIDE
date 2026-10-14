#!/usr/bin/env python3
"""Minimal App Store Connect API client: asc_api.py METHOD PATH [JSON_BODY].

Signs an ES256 JWT with openssl (the key is read by openssl only, never printed) and prints "status" then the body.

Configuration through the environment (nothing secret lives in the repository):
  ASC_KEY_ID   the API key id
  ASC_ISSUER   the issuer id (App Store Connect › Users and Access › Integrations)
  ASC_P8       path to the .p8 file; defaults to ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER"]
P8 = os.environ.get("ASC_P8", os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8"))


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    """Converts openssl's DER ECDSA signature into the raw r||s that JWT ES256 expects."""
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        n = der[i + 1]
        value = der[i + 2:i + 2 + n]
        i += 2 + n
        out += value.lstrip(b"\x00").rjust(32, b"\x00")
    return out


def token() -> str:
    header = b64(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
    now = int(time.time())
    payload = b64(json.dumps({"iss": ISSUER, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"}).encode())
    signature = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", P8], input=f"{header}.{payload}".encode(), capture_output=True, check=True
    ).stdout
    return f"{header}.{payload}.{b64(der_to_raw(signature))}"


def call(method: str, path: str, body=None):
    request = urllib.request.Request(
        "https://api.appstoreconnect.apple.com" + path,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request) as response:
            return response.status, response.read().decode()
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode()


if __name__ == "__main__":
    status, text = call(sys.argv[1], sys.argv[2], json.loads(sys.argv[3]) if len(sys.argv) > 3 else None)
    print(status)
    print(text)
