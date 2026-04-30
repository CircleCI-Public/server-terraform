#!/bin/bash
set -euo pipefail
INSTANCE_ID=$1

imds_get() {
    curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
        "http://169.254.169.254/latest/meta-data/$1"
}

hmac_sha256() {
    printf "%s" "$2" | openssl dgst -sha256 -mac HMAC -macopt "$1" -binary | od -An -tx1 | tr -d ' \n'
}

TOKEN=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 60") || { echo "Failed to get IMDS token" >&2; exit 1; }

REGION=$(imds_get "placement/region")
ROLE=$(imds_get "iam/security-credentials/")
read -r ACCESS_KEY SECRET_KEY SESSION_TOKEN < <(
    imds_get "iam/security-credentials/$ROLE" | jq -r '[.AccessKeyId, .SecretAccessKey, .Token] | @tsv'
)

HOST="autoscaling.$REGION.amazonaws.com"
AMZDATE=$(date -u +"%Y%m%dT%H%M%SZ")
DATESTAMP=$(date -u +"%Y%m%d")
BODY="Action=SetInstanceHealth&HealthStatus=Unhealthy&InstanceId=$INSTANCE_ID&Version=2011-01-01"
PAYLOAD_HASH=$(printf "%s" "$BODY" | sha256sum | cut -d' ' -f1)

CANONICAL_REQUEST=$(printf "POST\n/\n\ncontent-type:application/x-www-form-urlencoded\nhost:%s\nx-amz-date:%s\nx-amz-security-token:%s\n\ncontent-type;host;x-amz-date;x-amz-security-token\n%s" \
    "$HOST" "$AMZDATE" "$SESSION_TOKEN" "$PAYLOAD_HASH")
SCOPE="$DATESTAMP/$REGION/autoscaling/aws4_request"
STRING_TO_SIGN=$(printf "AWS4-HMAC-SHA256\n%s\n%s\n%s" "$AMZDATE" "$SCOPE" \
    "$(printf "%s" "$CANONICAL_REQUEST" | sha256sum | cut -d' ' -f1)")

DATE_KEY=$(hmac_sha256 "key:AWS4$SECRET_KEY" "$DATESTAMP")
REGION_KEY=$(hmac_sha256 "hexkey:$DATE_KEY" "$REGION")
SERVICE_KEY=$(hmac_sha256 "hexkey:$REGION_KEY" "autoscaling")
SIGNING_KEY=$(hmac_sha256 "hexkey:$SERVICE_KEY" "aws4_request")
SIGNATURE=$(printf "%s" "$STRING_TO_SIGN" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$SIGNING_KEY" | sed 's/.* //')

curl -sf --max-time 10 -X POST "https://$HOST/" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "X-Amz-Date: $AMZDATE" \
    -H "X-Amz-Security-Token: $SESSION_TOKEN" \
    -H "Authorization: AWS4-HMAC-SHA256 Credential=$ACCESS_KEY/$SCOPE, SignedHeaders=content-type;host;x-amz-date;x-amz-security-token, Signature=$SIGNATURE" \
    -d "$BODY"
