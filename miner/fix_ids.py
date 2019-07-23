#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

import botocore.session
from pprint import pprint,pformat

dynamodb = botocore.session.get_session().create_client("dynamodb")
SPACEMESH_DYNAMODB_TABLE = "initdata-testnet-us-east-1.spacemesh.io"

for item in dynamodb.scan(TableName=SPACEMESH_DYNAMODB_TABLE)["Items"]:
    orig_id = item["id"]["S"]
    if orig_id.endswith("/"):
        print("Fixing ID for {}".format(orig_id))
        item["id"]["S"] = orig_id.rstrip("/")
        pprint(dynamodb.put_item(TableName=SPACEMESH_DYNAMODB_TABLE, Item=item))
        print("Deleting incorred record")
        pprint(dynamodb.delete_item(TableName=SPACEMESH_DYNAMODB_TABLE, Key={"id": {"S": orig_id}}))
    else:
        print("Skipping valid key '{}'".format(orig_id))
