#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

from datetime import datetime
from glob import glob
import logging
import os
from pprint import pformat
from random import randrange,randint
import subprocess
from time import sleep

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
# SPACEMESH_WORKER_ID - worker ID to recover the same dataset
SPACEMESH_WORKER_ID = os.environ.get("SPACEMESH_WORKER_ID", "")

# SPACEMESH_WORKDIR - working directory
SPACEMESH_WORKDIR = os.environ.get("SPACEMESH_WORKDIR", "/home/spacemesh")

# SPACEMESH_DATADIR - data directory, relative to SPACEMESH_WORKDIR
SPACEMESH_DATADIR = os.environ.get("SPACEMESH_DATADIR", "./data")

# SPACEMESH_MAX_TRIES - max attempts to obtain a data file
SPACEMESH_MAX_TRIES = int(os.environ.get("SPACEMESH_MAX_TRIES", 5))

# SPACEMESH_FILESIZE - integer value, default 1Mb (FIXME: Unused)
SPACEMESH_FILESIZE = str(int(os.environ.get("SPACEMESH_FILESIZE", 0)))

# SPACEMESH_SPACE - integer value, default 1Mb (FIXME: Unused)
SPACEMESH_SPACE = str(int(os.environ.get("SPACEMESH_SPACE", 0)))

# SPACEMESH_CLIENT
SPACEMESH_CLIENT = os.environ.get("SPACEMESH_CLIENT", "/bin/go-spacemesh")

# SPACEMESH_S3_BUCKET and SPACEMESH_S3_PREFIX
SPACEMESH_S3_BUCKET = os.environ.get("SPACEMESH_S3_BUCKET", "initfactory")
SPACEMESH_S3_PREFIX = os.environ.get("SPACEMESH_S3_PREFIX", "")

# SPACEMESH_DYNAMODB_TABLE and SPACEMESH_DYNAMODB_REGION
SPACEMESH_DYNAMODB_TABLE = os.environ.get("SPACEMESH_DYNAMODB_TABLE", "initdata")
SPACEMESH_DYNAMODB_REGION = os.environ.get("SPACEMESH_DYNAMODB_REGION", "us-east-1")


### Check if the data is already retrieved (pod restarted)
if glob(os.path.join(SPACEMESH_DATADIR, "*")):
    log.info("There is something in the data dir already, not retrieving new data")
    raise SystemExit(0)


### Get the data set to work with
dynamodb = botocore.session.get_session().create_client("dynamodb", region_name=SPACEMESH_DYNAMODB_REGION)
data_id = None

# Check if there is already a data set allocated for us from previous run (pre-crash)
log.info("Checking metadata table to see if there is a dataset locked by '{}'".format(SPACEMESH_WORKER_ID))

try:
    r = dynamodb.query(TableName=SPACEMESH_DYNAMODB_TABLE, IndexName="locked_by",
                       KeyConditionExpression="locked_by = :myid",
                       ExpressionAttributeValues={
                         ":myid": {"S": SPACEMESH_WORKER_ID},
                       },
                       ProjectionExpression="id",
                       Limit=1,
                       )
except Exception as e:
    log.fatal("Caught exception: {}".format(e))
    raise SystemExit(1)

if r["Count"] > 0:
    # Get the data id
    data_id = r["Items"][0]["id"]["S"]
else:
    log.info("No locked data set found, getting a new one")

    # Get a random unlocked InitData from DynamoDB
    for i in range(SPACEMESH_MAX_TRIES):
        log.info("Getting an unused data file, try #{}".format(i+1))

        log.info("Querying the metadata table")
        rnd = randint(1, 2**32-1)
        try:
            log.debug("Fetch the first item above the threshold {}".format(rnd))
            r = dynamodb.query(TableName=SPACEMESH_DYNAMODB_TABLE, IndexName="locked_random",
                               KeyConditionExpression="locked = :false AND random_sort_key > :rnd",
                               ExpressionAttributeValues={
                                   ":false": {"N": "0"},
                                   ":rnd":   {"N": str(rnd)},
                               },
                               ProjectionExpression="id",
                               Limit=1,
                               )
        except Exception as e:
            log.fatal("Caught exception: {}".format(e))
            raise SystemExit(1)

        if r["Count"] == 0:
            try:
                log.debug("Fetch the first item BELOW the threshold {} - nothing ABOVE it found".format(rnd))
                r = dynamodb.query(TableName=SPACEMESH_DYNAMODB_TABLE, IndexName="locked_random",
                                   KeyConditionExpression="locked = :false AND random_sort_key <= :rnd",
                                   ExpressionAttributeValues={
                                       ":false": {"N": "0"},
                                       ":rnd":   {"N": str(rnd)},
                                   },
                                   ProjectionExpression="id",
                                   Limit=1,
                                   )
            except Exception as e:
                log.fatal("Caught exception: {}".format(e))
                raise SystemExit(1)

        if r["Count"] == 0:
            log.info("No unused init data files found, exiting normally")
            raise SystemExit(0)

        # Get the data id
        data_id = r["Items"][0]["id"]["S"]
        log.info("Will proceed with data file '{}'".format(data_id))

        ### Lock the entry
        log.info("Locking data file '{}'".format(data_id))

        try:
            dynamodb.update_item(TableName=SPACEMESH_DYNAMODB_TABLE,
                                 Key={"id": {"S": data_id}},
                                 ConditionExpression="locked = :false",
                                 UpdateExpression="SET locked = :true, locked_by = :myid",
                                 ExpressionAttributeValues={
                                     ":false": {"N": "0"},
                                     ":true": {"N": "1"},
                                     ":myid": {"S": SPACEMESH_WORKER_ID},
                                 },
                                 )
        except Exception as e:
            if issubclass(type(e), botocore.exceptions.ClientError) and \
               e.response["Error"]["Code"] == "ConditionalCheckFailedException":
                   log.info("Someone already grabbed '{}' data file, retrying if possible".format(data_id))
                   sleep(randrange(2, 10))
                   continue

            log.fatal("Caught exception: {}".format(e))
            raise SystemExit(1)

        log.info("Successfully locked data file '{}' after {} tries".format(data_id, i+1))
        break


# Exit if no data file could be found
if data_id is None:
    log.fatal("Couldn't obtain a data file")
    raise SystemExit(2)

### Report the result
log.info("Will proceed with data file '{}'".format(data_id))

### Transfer the files from S3
s3 = botocore.session.get_session().create_client("s3")
transfer = S3Transfer(s3)

# List items under a specific prefix and download them
data_prefix = data_id + "/"
if SPACEMESH_S3_PREFIX != "":
    data_prefix = SPACEMESH_S3_PREFIX + "/" + data_prefix

log.info("Listing S3 Bucket '{}' under prefix '{}'".format(SPACEMESH_S3_BUCKET, data_prefix))
try:
    data_objects = s3.list_objects_v2(Bucket=SPACEMESH_S3_BUCKET, Prefix=data_prefix)
except Exception as e:
    log.fatal("Caught exception: {}".format(e))
    raise SystemExit(3)

# Download the objects
for obj in data_objects["Contents"]:
    dest = obj["Key"]
    # Remove S3 prefix if required
    if SPACEMESH_S3_PREFIX != "":
        dest = dest[length(SPACEMESH_S3_PREFIX)+1:]

    # Download under DATA/nodes/ path
    dest = os.path.join(SPACEMESH_DATADIR, dest)

    # Ensure all directories exist
    os.makedirs(os.path.dirname(dest), mode=0o755, exist_ok=True)

    log.info("Downloading '{}' to '{}'".format(obj["Key"], dest))
    try:
        transfer.download_file(SPACEMESH_S3_BUCKET, obj["Key"], dest)
    except Exception as e:
        log.error("Caught exception: {}".format(e))


### Prepare miner's config.toml
log.info("Writing config.toml")

# Generate config.toml contents
SPACEMESH_FULL_DATADIR=os.path.join(SPACEMESH_WORKDIR, SPACEMESH_DATADIR)
config_toml = f"""\
[post]
post-datadir = "{SPACEMESH_FULL_DATADIR}"
"""

log.debug("config.toml:\n" + config_toml)

with open("config.toml", "w") as config:
    config.write(config_toml)

log.info("Done!")

# vim:ts=4 sw=4 et:
