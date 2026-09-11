#!/usr/bin/env bash
#
# Trust the corporate Cloudflare Zero Trust gateway root CA in an iOS Simulator.
#
# Why: when your Mac is behind a Cloudflare Zero Trust (WARP) gateway, the gateway
# MITM-inspects TLS using a "Gateway CA - Cloudflare Managed G1" root that macOS
# trusts but a fresh iOS Simulator does not. Unit tests that make real HTTPS
# requests (e.g. NRMASessionExclusivityWithDelegateTests, which uploads to
# api.imgur.com) then fail with NSURLErrorDomain -1202 ("certificate invalid").
#
# This copies that root CA from your Mac's System keychain into the simulator's
# trust store. Run it once per simulator (the trust is lost when a simulator is
# erased). It exits cleanly and does nothing if you are not behind such a gateway.
#
# Usage:
#   scripts/trust_cloudflare_ca_in_simulator.sh            # the booted simulator
#   scripts/trust_cloudflare_ca_in_simulator.sh booted     # same as above
#   scripts/trust_cloudflare_ca_in_simulator.sh <UDID>     # a specific simulator
#
set -euo pipefail

TARGET="${1:-booted}"
CN="Gateway CA - Cloudflare Managed G1"
TMP_PEM="$(mktemp /tmp/cf_gateway_cas.XXXXXX.pem)"
SPLIT_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_PEM" "$SPLIT_DIR"' EXIT

# Export every matching gateway CA (there can be more than one) from the System keychain.
security find-certificate -a -c "$CN" -p /Library/Keychains/System.keychain > "$TMP_PEM" 2>/dev/null || true

if ! grep -q "BEGIN CERTIFICATE" "$TMP_PEM"; then
  echo "No '$CN' certificate found in your System keychain."
  echo "You're probably not behind the Cloudflare Zero Trust gateway — nothing to do."
  exit 0
fi

# Split the (possibly multi-cert) PEM into one file per certificate, then add each.
awk -v d="$SPLIT_DIR" 'BEGIN{n=0} /BEGIN CERTIFICATE/{n++} {print > sprintf("%s/ca_%02d.pem", d, n)}' "$TMP_PEM"

count=0
for f in "$SPLIT_DIR"/ca_*.pem; do
  [ -s "$f" ] || continue
  grep -q "BEGIN CERTIFICATE" "$f" || continue
  subj="$(openssl x509 -in "$f" -noout -subject 2>/dev/null || echo '(unknown subject)')"
  if xcrun simctl keychain "$TARGET" add-root-cert "$f"; then
    echo "Trusted: $subj"
    count=$((count + 1))
  fi
done

echo "Added $count root CA(s) to simulator '$TARGET'."
echo "Restart any in-progress test run so the new trust takes effect."
