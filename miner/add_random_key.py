#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

from pprint import pprint,pformat
from random import randint

import botocore.session

dynamodb = botocore.session.get_session().create_client("dynamodb")
SPACEMESH_DYNAMODB_TABLE = "initdata-testnet-us-east-1.spacemesh.io"

for item in dynamodb.scan(TableName=SPACEMESH_DYNAMODB_TABLE,
                          FilterExpression="NOT attribute_exists(random_sort_key)",
                          ProjectionExpression="id",
                          )["Items"]:
    item_id = item["id"]["S"]
    random_sort_key = randint(1, 2**32-1)
    print("Addind sort key '{}' to '{}'".format(random_sort_key, item_id))
    pprint(dynamodb.update_item(TableName=SPACEMESH_DYNAMODB_TABLE,
                                Key={"id": {"S": item_id}},
                                UpdateExpression="SET random_sort_key = :key",
                                ExpressionAttributeValues={":key": {"N": str(random_sort_key)}},
                                ))
