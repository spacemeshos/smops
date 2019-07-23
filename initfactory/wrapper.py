#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

from datetime import datetime
from glob import iglob
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

# SPACEMESH_FILESIZE - integer value, default 1Mb
SPACEMESH_FILESIZE = str(int(os.environ.get("SPACEMESH_FILESIZE", 1048576)))

# SPACEMESH_SPACE - integer value, default 1Mb
SPACEMESH_SPACE = str(int(os.environ.get("SPACEMESH_SPACE", 1048576)))

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
    "file_size": SPACEMESH_FILESIZE if SPACEMESH_FILESIZE != "0" else "1048576",
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

if SPACEMESH_FILESIZE != "0":
    log.info("NOTICE: Set filesize to '{}'".format(SPACEMESH_FILESIZE))
    init_cmd += ["-filesize", SPACEMESH_FILESIZE]


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

for f in iglob(os.path.join(SPACEMESH_DATADIR, "**", "*"), recursive=True):
    stat_f = os.stat(f)
    if not stat.S_ISREG(stat_f.st_mode):
        log.debug("Skipping '{}', not a regular file".format(f))
        continue
    # Extract only relative path
    s3_key = os.path.relpath(f, SPACEMESH_DATADIR)

    if SPACEMESH_ID is None and s3_key.endswith("/key.bin"):
        SPACEMESH_ID = os.path.dirname(s3_key)
        log.info("Found client miner id '{}' from path '{}'".format(SPACEMESH_ID, f))

    # Append a prefix if required
    if SPACEMESH_S3_PREFIX != "":
        s3_key = SPACEMESH_S3_PREFIX + "/" + s3_key

    log.info("Uploading '{}' as 's3://{}/{}'".format(f, SPACEMESH_S3_BUCKET, s3_key))
    try:
        transfer.upload_file(f, SPACEMESH_S3_BUCKET, s3_key)
    except Exception as e:
        log.critical("Caught exception: {}".format(e))


### Record metadata into DynamoDB
# Check if SPACEMESH_ID is set
if SPACEMESH_ID is None:
    log.fatal("No miner ID detected, cannot record!")
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
                          "file_size": {"N": str(metadata["file_size"])},
                      },
                      )
except Exception as e:
    log.critical("Caught exception: {}".format(e))

log.info("Done, exiting")

# vim:ts=4 sw=4 et:
