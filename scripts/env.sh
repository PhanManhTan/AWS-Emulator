#!/usr/bin/env bash
# Source this file in Bash: source scripts/env.sh
# Changes apply only to this shell; credentials come from the local emulator.
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE AWS_DEFAULT_PROFILE
unset AWS_ENDPOINT_URL_S3 AWS_ENDPOINT_URL_DYNAMODB AWS_ENDPOINT_URL_SQS AWS_ENDPOINT_URL_STS
unset AWS_IGNORE_CONFIGURED_ENDPOINT_URLS
export AWS_ENDPOINT_URL=https://127.0.0.1:9297
export AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/emulator/9297/emulator_credentials"
export AWS_CONFIG_FILE="$HOME/.aws/emulator/9297/config"
export AWS_CA_BUNDLE="$HOME/.aws/emulator/9297/ca.pem"
export AWS_EC2_METADATA_DISABLED=true
export AWS_DISABLE_HOST_PREFIX_INJECTION=true
export AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1
export AWS_DEFAULT_OUTPUT=table
export AWS_PAGER="" AWS_CLI_AUTO_PROMPT=off

for _emulator_attempt in {1..60}; do
  if [[ -f "$AWS_SHARED_CREDENTIALS_FILE" ]] && curl --silent --fail --cacert "$AWS_CA_BUNDLE" \
      "$AWS_ENDPOINT_URL/__admin/health" >/dev/null 2>&1; then
    unset _emulator_attempt
    echo "AWS CLI is configured for AWS Emulator at $AWS_ENDPOINT_URL"
    return 0 2>/dev/null || exit 0
  fi
  sleep 1
done
unset _emulator_attempt
echo 'Emulator is not ready. Check: docker logs aws-emulator-demo' >&2
return 1 2>/dev/null || exit 1
