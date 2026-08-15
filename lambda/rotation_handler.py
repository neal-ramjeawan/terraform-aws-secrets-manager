"""
Generic Secrets Manager rotation handler.

Implements the standard four-step rotation protocol (createSecret,
setSecret, testSecret, finishSecret) that Secrets Manager invokes this
function with. This generic version only knows how to regenerate a random
value using Secrets Manager's own GetRandomPassword API — it does NOT push
the new value anywhere else.

That means it's a fit for standalone secrets (API keys, tokens, arbitrary
passwords) where Secrets Manager is the only place the value needs to
live. It is NOT a fit for something like a database password, where a real
system also needs the new credential set — for that, override setSecret()
(and usually testSecret()) to actually talk to that system. AWS publishes
dedicated rotation templates for RDS/other database engines that do this;
this handler is intentionally the generic, no-external-dependency case.
"""

import logging

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    arn = event["SecretId"]
    token = event["ClientRequestToken"]
    step = event["Step"]

    client = boto3.client("secretsmanager")

    metadata = client.describe_secret(SecretId=arn)
    if not metadata.get("RotationEnabled", False):
        raise ValueError(f"Secret {arn} is not enabled for rotation")

    versions = metadata["VersionIdsToStages"]
    if token not in versions:
        raise ValueError(f"Secret version {token} has no stage for rotation of {arn}")
    if "AWSCURRENT" in versions[token]:
        logger.info(f"Version {token} already AWSCURRENT for {arn}, nothing to do")
        return
    if "AWSPENDING" not in versions[token]:
        raise ValueError(f"Secret version {token} not set as AWSPENDING for {arn}")

    if step == "createSecret":
        create_secret(client, arn, token)
    elif step == "setSecret":
        set_secret(client, arn, token)
    elif step == "testSecret":
        test_secret(client, arn, token)
    elif step == "finishSecret":
        finish_secret(client, arn, token)
    else:
        raise ValueError(f"Invalid rotation step: {step}")


def create_secret(client, arn, token):
    """Generate a new value and stage it as AWSPENDING."""
    try:
        client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
        logger.info(f"createSecret: AWSPENDING version already exists for {arn}")
        return
    except client.exceptions.ResourceNotFoundException:
        pass

    new_value = client.get_random_password(ExcludeCharacters='"@/\\')["RandomPassword"]
    client.put_secret_value(
        SecretId=arn,
        ClientRequestToken=token,
        SecretString=new_value,
        VersionStages=["AWSPENDING"],
    )
    logger.info(f"createSecret: staged new AWSPENDING version for {arn}")


def set_secret(client, arn, token):
    """
    No external system to push the new value to in this generic handler.
    Override this if your secret needs to be set somewhere else too.
    """
    logger.info(f"setSecret: no external system to update for {arn}")


def test_secret(client, arn, token):
    """
    No external system to validate against in this generic handler — just
    confirm the AWSPENDING value is readable.
    """
    client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
    logger.info(f"testSecret: AWSPENDING version is readable for {arn}")


def finish_secret(client, arn, token):
    """Move AWSCURRENT to the new version."""
    metadata = client.describe_secret(SecretId=arn)
    current_version = None
    for version, stages in metadata["VersionIdsToStages"].items():
        if "AWSCURRENT" in stages:
            if version == token:
                logger.info(f"finishSecret: {token} already AWSCURRENT for {arn}")
                return
            current_version = version
            break

    client.update_secret_version_stage(
        SecretId=arn,
        VersionStage="AWSCURRENT",
        MoveToVersionId=token,
        RemoveFromVersionId=current_version,
    )
    logger.info(f"finishSecret: AWSCURRENT moved to {token} for {arn}")
