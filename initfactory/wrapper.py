#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

from datetime import datetime
import logging
import os
from random import randint
import stat
import subprocess

from pprint import pformat

import botocore.session
from s3transfer import S3Transfer

### Configure logging
logging.basicConfig(
    format="%(asctime)s    %(levelname)-7s %(name)-15s %(message)s",
    level=logging.INFO,
    datefmt="%Y-%m-%dT%H:%M:%S.000%z"
    )
log = logging.getLogger("InitFactory")
log.setLevel(logging.DEBUG)
if "LOGLEVEL" in os.environ:
    log.setLevel(getattr(logging, os.environ["LOGLEVEL"].upper(), logging.DEBUG))
log.debug("Level set to {}".format(log.level))

# Suppress botocore debug log
logging.getLogger("botocore").setLevel(logging.INFO)

### Set parameters
# SPACEMESH_ID - miner ID, default - generate one
SPACEMESH_ID = os.environ.get("SPACEMESH_ID", None)
if SPACEMESH_ID == "":
    SPACEMESH_ID = None

if SPACEMESH_ID is not None:
    log.info("Creating init file for '{}'".format(SPACEMESH_ID))

# SPACEMESH_SPACE - integer value, default 1Mb
SPACEMESH_SPACE = str(int(os.environ.get("SPACEMESH_SPACE", 0)))

# SPACEMESH_DATADIR
SPACEMESH_DATADIR = os.environ.get("SPACEMESH_DATADIR", "./data")

# SPACEMESH_INIT
SPACEMESH_INIT = os.environ.get("SPACEMESH_INIT", "/bin/spacemesh-init")

# SPACEMESH_S3_BUCKET and SPACEMESH_S3_PREFIX
SPACEMESH_S3_BUCKET = os.environ.get("SPACEMESH_S3_BUCKET", "initfactory")
SPACEMESH_S3_PREFIX = os.environ.get("SPACEMESH_S3_PREFIX", "")

# SPACEMESH_DYNAMODB_TABLE and SPACEMESH_DYNAMODB_REGION
SPACEMESH_DYNAMODB_TABLE = os.environ.get("SPACEMESH_DYNAMODB_TABLE", "initdata")
SPACEMESH_DYNAMODB_REGION = os.environ.get("SPACEMESH_DYNAMODB_REGION", "us-east-1")

### Initialize metadata
metadata = {
    "locked": 0,
    "space": SPACEMESH_SPACE if SPACEMESH_SPACE != "0" else "1048576",
    "started_at": datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%f+0000"),
}

# Check if SPACEMESH_ID is set
if SPACEMESH_ID is not None:
    log.info("Using miner ID '{}' from the environment".format(SPACEMESH_ID))
    metadata["id"] = SPACEMESH_ID

### Assemble the command line
log.info("Using init at '{}'".format(SPACEMESH_INIT))
init_cmd = [SPACEMESH_INIT]

if SPACEMESH_DATADIR is not None:
    log.info("NOTICE: Set data dir to '{}'".format(SPACEMESH_DATADIR))
    init_cmd += ["-datadir", SPACEMESH_DATADIR]
else:
    SPACEMESH_DATADIR=os.path.join(".", "data")
    log.info("NOTICE: Assuming data dir to be '{}'".format(SPACEMESH_DATADIR))

if SPACEMESH_ID is not None:
    log.info("NOTICE: Set miner id to '{}'".format(SPACEMESH_ID))
    init_cmd += ["-id", SPACEMESH_ID]

if SPACEMESH_SPACE != "0":
    log.info("NOTICE: Set file chunk size to '{}'".format(SPACEMESH_SPACE))
    init_cmd += ["-space", SPACEMESH_SPACE]

### Execute the process and wait for completion
log.info("Executing the process")
init_result = subprocess.run(init_cmd)


### Check if the process was successful
if init_result.returncode != 0:
    log.fatal("Non-zero exit code {} from '{}'".format(init_result.returncode, init_result.args))
    raise SystemExit(init_result.returncode)

log.info("Success, recording results")
metadata["finished_at"] = datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%f+0000")


### Upload the files to S3
s3 = botocore.session.get_session().create_client("s3")
transfer = S3Transfer(s3)

s3_upload_success = True
for dirname, subdirs, files in os.walk(SPACEMESH_DATADIR):
    # Get the path relative to data dir
    subdir = os.path.relpath(dirname, SPACEMESH_DATADIR)

    # Iterate over files
    for f in files:
        fullpath = os.path.join(dirname, f)
        if SPACEMESH_ID is None and f == "key.bin":
            SPACEMESH_ID = subdir
            log.info("Found client miner id '{}' from path '{}'".format(SPACEMESH_ID, fullpath))

        s3_key = os.path.join(SPACEMESH_S3_PREFIX, subdir, f)

        log.info("Uploading '{}' as 's3://{}/{}'".format(fullpath, SPACEMESH_S3_BUCKET, s3_key))
        try:
            transfer.upload_file(fullpath, SPACEMESH_S3_BUCKET, s3_key)
        except Exception as e:
            log.critical("Caught exception: {}".format(e))
            s3_upload_success = False


# If the upload was not a complete success - do not upload it
if not s3_upload_success:
    log.fatal("Upload was incomplete, cannot record to DynamoDB!")
    raise SystemExit(3)

### Record metadata into DynamoDB
# Check if SPACEMESH_ID is set
if SPACEMESH_ID is None:
    log.fatal("No miner ID detected, cannot record to DynamoDB!")
    raise SystemExit(2)

metadata["id"] = SPACEMESH_ID

log.info("Recording metadata into DynamoDB table '{}' in region '{}'".format(
    SPACEMESH_DYNAMODB_TABLE, SPACEMESH_DYNAMODB_REGION))
log.debug("Metadata: " + pformat(metadata))

dynamodb = botocore.session.get_session().create_client("dynamodb", region_name=SPACEMESH_DYNAMODB_REGION)

try:
    dynamodb.put_item(TableName=SPACEMESH_DYNAMODB_TABLE,
                      Item={
                          "id": {"S": metadata["id"]},
                          "locked": {"N": str(metadata["locked"])},
                          "random_sort_key": {"N": str(randint(1, 2**32-1))},
                          "started_at": {"S": metadata["started_at"]},
                          "finished_at": {"S": metadata["finished_at"]},
                          "space": {"N": str(metadata["space"])},
                      },
                      )
except Exception as e:
    log.critical("Caught exception: {}".format(e))

log.info("Done, exiting")

# vim:ts=4 sw=4 et:
