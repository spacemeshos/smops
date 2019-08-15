#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

import botocore.session
from pprint import pprint,pformat

dynamodb = botocore.session.get_session().create_client("dynamodb", region_name="us-east-1")
SPACEMESH_DYNAMODB_TABLE = "initdata-testnet-us-east-1.spacemesh.io"

id_list = [item["id"]["S"] for item in dynamodb.scan(TableName=SPACEMESH_DYNAMODB_TABLE,
                                                     ProjectionExpression="id",
                                                     )["Items"]]

print(f"To delete: {len(id_list)} items")

for i in range(int((len(id_list) + 24)/25)):
    batch = id_list[0:25]
    pprint(dynamodb.batch_write_item(RequestItems={
        SPACEMESH_DYNAMODB_TABLE: [{"DeleteRequest": {"Key": {"id": {"S": item_id}}}} for item_id in batch]}))
    del(id_list[0:25])

# aws s3 rm --recursive s3://initdata-testnet-us-east-1.spacemesh.io/
