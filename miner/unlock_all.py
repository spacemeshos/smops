#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

import botocore.session
from pprint import pprint,pformat

dynamodb = botocore.session.get_session().create_client("dynamodb", region_name="us-east-1")
SPACEMESH_DYNAMODB_TABLE = "initdata-testnet-us-east-1.spacemesh.io"

for item in dynamodb.scan(TableName=SPACEMESH_DYNAMODB_TABLE,
                          ProjectionExpression="id",
                          )["Items"]:
    item_id = item["id"]["S"]
    print("Unlocking '{}'".format(item_id))
    pprint(dynamodb.update_item(TableName=SPACEMESH_DYNAMODB_TABLE,
                                Key={"id": {"S": item_id}},
                                UpdateExpression="SET locked = :false REMOVE locked_by",
                                ExpressionAttributeValues={":false": {"N": "0"}},
                                ))
