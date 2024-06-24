#!/bin/bash

export AWS_REGION=us-west-2

aws bedrock-runtime invoke-model --no-verify-ssl --endpoint-url "https://oregon.runtime.bedrock.in" --model-id "anthropic.claude-3-sonnet-20240229-v1:0" --body "$(base64 -i payload.json)" response.json
