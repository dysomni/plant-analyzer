import base64
import json
import logging
import os

import boto3

from lib.analyzer import analyze

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


def ssm_get_parameter(parameter_name):
    ssm = boto3.client("ssm")
    parameter = ssm.get_parameter(Name=parameter_name, WithDecryption=True)
    return parameter["Parameter"]["Value"]


def get_env():
    for key in os.environ:
        if os.environ[key].startswith("ssm://"):
            os.environ[key] = ssm_get_parameter(os.environ[key][6:])
    return os.environ


def handler(event, context):
    env = get_env()
    if event["headers"].get("auth", ...) != env["AUTH"]:
        return {"message": "Unauthorized"}

    query_params = event.get("queryStringParameters", {})
    body = event.get("body", "{}")
    try:
        parsed_body = json.loads(base64.b64decode(body))
    except json.decoder.JSONDecodeError:
        return {"message": "Invalid JSON body"}

    LOGGER.info("Query Params: %s", query_params)
    LOGGER.info("Body: %s", parsed_body)
    return analyze(query_params, parsed_body)
