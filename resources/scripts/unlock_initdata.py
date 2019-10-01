#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

import sys

import botocore.session

if len(sys.argv) != 2:
    print(f"Usage: {sys.argv[0]} REGION")
    raise SystemExit(1)

AWS_REGION = sys.argv[1]
TABLE_NAME = f"testnet-initdata.{AWS_REGION}.spacemesh.io"

print(f"Unlocking all items in {TABLE_NAME} at {AWS_REGION}")

dynamodb = botocore.session.get_session().create_client("dynamodb", region_name=AWS_REGION)

r = dynamodb.scan(TableName=TABLE_NAME, ProjectionExpression="id")

while r["Count"] > 0:
    print(f"""To unlock: {r["Count"]} items""")

    for item in r["Items"]:
        print(f"""Unlocking id '{item["id"]["S"]}'""")
        dynamodb.update_item(TableName=TABLE_NAME, Key=item,
                             UpdateExpression="REMOVE locked_by SET locked=:false",
                             ExpressionAttributeValues={":false": {"N": "0"}})

    if "LastEvaluatedKey" not in r:
        break
    r = dynamodb.scan(TableName=TABLE_NAME, ProjectionExpression="id",
                      ExclusiveStartKey=r["LastEvaluatedKey"])

print("Done!")
