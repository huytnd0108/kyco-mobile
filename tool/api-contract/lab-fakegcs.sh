#!/usr/bin/env bash
# Lab-only fake GCS (fsouza/fake-gcs-server) so the PROD build (`next start`) of
# kyco-wt/mobile-qa has real media storage: request-upload → signed PUT →
# finalize HEAD → proxy read, KYC upload, catalog image upload.
# (docs/web-api-only-infra.md §2.2; same image/flags as kyco-wt/verify scripts/verify/compose.yml)
#
#   tool/api-contract/lab-fakegcs.sh up     # start container + create bucket, print server env
#   tool/api-contract/lab-fakegcs.sh env    # print the server env only
#   tool/api-contract/lab-fakegcs.sh down   # stop + remove the container
#
# Do NOT also set KYCO_LOCAL_MEDIA_SECRET (that switches media to the local adapter).
# Path-style URLs only match when the request host equals -public-host, so the
# harness and the server must both reach it as $GCS_HOSTPORT.
set -euo pipefail
NAME=${FAKEGCS_NAME:-kyco-mqa-fakegcs}
PORT=${FAKEGCS_PORT:-4443}
GCS_HOSTPORT=${GCS_HOSTPORT:-localhost:$PORT}
BUCKET=${FAKEGCS_BUCKET:-kyco-mqa-media}
IMAGE=fsouza/fake-gcs-server:1.52.2

print_env() {
  cat <<EOF
GCS_API_ENDPOINT=http://$GCS_HOSTPORT
KYCO_ALLOW_STORAGE_EMULATOR=true
GCS_WEBSITE_CONTENT_BUCKET=$BUCKET
GCS_BUCKET=$BUCKET
EOF
}

case "${1:-up}" in
  up)
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    docker run -d --name "$NAME" -p "127.0.0.1:$PORT:4443" "$IMAGE" \
      -scheme http -port 4443 -public-host "$GCS_HOSTPORT" -external-url "http://$GCS_HOSTPORT" >/dev/null
    for _ in $(seq 1 30); do
      curl -sf "http://$GCS_HOSTPORT/storage/v1/b" >/dev/null 2>&1 && break; sleep 0.5
    done
    curl -sf -X POST "http://$GCS_HOSTPORT/storage/v1/b?project=kyco-mqa" \
      -H 'Content-Type: application/json' -d "{\"name\":\"$BUCKET\"}" >/dev/null
    curl -sf "http://$GCS_HOSTPORT/storage/v1/b" | grep -q "\"$BUCKET\"" \
      || { echo "bucket $BUCKET not created" >&2; exit 1; }
    echo "fake-gcs $NAME up at http://$GCS_HOSTPORT, bucket $BUCKET. Server env:" >&2
    print_env ;;
  env) print_env ;;
  down) docker rm -f "$NAME" >/dev/null && echo "removed $NAME" >&2 ;;
  *) echo "usage: $0 up|env|down" >&2; exit 2 ;;
esac
