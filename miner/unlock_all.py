#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

import botocore.session
from pprint import pprint,pformat

dynamodb = botocore.session.get_session().create_client("dynamodb", region_name="us-east-1")
SPACEMESH_DYNAMODB_TABLE = "initdata-testnet-us-east-1.spacemesh.io"

for item in dynamodb.query(TableName=SPACEMESH_DYNAMODB_TABLE,
                           IndexName="locked",
                           KeyConditionExpression="locked = :true",
                           ExpressionAttributeValues={":true": {"N": "1"}},
                           ProjectionExpression="id",
                           )["Items"]:
    item_id = item["id"]["S"]
    print("Unlocking '{}'".format(item_id))
    pprint(dynamodb.update_item(TableName=SPACEMESH_DYNAMODB_TABLE,
                                Key={"id": {"S": item_id}},
                                UpdateExpression="SET locked = :false",
                                ExpressionAttributeValues={":false": {"N": "0"}},
                                ))
