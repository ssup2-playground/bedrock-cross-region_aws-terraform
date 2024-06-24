#!/bin/bash

export AWS_REGION=us-east-1
export AWS_KEY_ACCESS=
export AWS_KEY_SECRET=

aws bedrock-runtime invoke-model --no-verify-ssl --endpoint-url "https://virginia.runtime.bedrock.in" --model-id "anthropic.claude-3-sonnet-20240229-v1:0" --body "$(base64 -i payload.json)" response.json