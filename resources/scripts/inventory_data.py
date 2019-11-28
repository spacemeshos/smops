#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

try:
    import threading
except ImportError:
    import dummy_threading as threading

from datetime import datetime

from jinja2 import Template
import botocore.session

AWS_REGIONS = [
    "us-east-1",
    "us-east-2",
    "eu-north-1",
    "ap-northeast-2",
    "us-west-2",
    ]

def space_hr(space):
    """Convert space to human-readable form"""
    space = int(space / (1024*1024)) # Megabytes

    if space > 1024: # Gigabytes
        return str(int(space / 1024)) + "Gi"

    return str(space) + "Mi"


def inventory_initdata(aws_region):
    """Scan DynamoDB table and return summary of data files there"""
    table_name = f"testnet-initdata.{aws_region}.spacemesh.io"
    items_total = {}
    items_locked = {}

    dynamodb = botocore.session.get_session().create_client("dynamodb", region_name=aws_region)
    r = dynamodb.scan(TableName=table_name,
                      ProjectionExpression="#space,locked",
                      ExpressionAttributeNames={"#space": "space"},
                      )
    while r["Count"] > 0:
        for item in r["Items"]:
            space = int(item["space"]["N"])
            if space in items_total:
                items_total[space] += 1
            else:
                items_total[space] = 1
                items_locked[space] = 0

            if item["locked"]["N"] != "0":
                items_locked[space] += 1

        if "LastEvaluatedKey" not in r:
            break

        r = dynamodb.scan(TableName=table_name,
                          ProjectionExpression="#space,locked",
                          ExpressionAttributeNames={"#space": "space"},
                          ExclusiveStartKey=r["LastEvaluatedKey"],
                          )

    # Flatten the result
    return [(space, space_hr(space), items_total[space], items_locked[space]) for space in sorted(items_total.keys())]


def publish_inventory(data):
    """Print HTML-formatted report"""

    print(Template("""\
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>InitFactory Inventory</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  </head>
  <body>
    <h1>InitFactory Inventory</h1>
    <table border="1">
      <caption>InitFactory Data Files as of {{date}}</caption>
      <thead><tr>
        <th>Region</th>
        <th>Space</th>
        <th>Total</th>
        <th>Locked</th>
      </tr></thead>
      <tbody>
      {%- for region,files in data|dictsort: %}
        {%- for space,space_hr,total,locked in files: %}
        <tr>
          {%- if loop.first: %}
          <th rowspan="{{files|length}}">{{region}}</th>
          {%- endif %}
          <td>{{space_hr}} ({{space}})</td>
          <td>{{total}}</td>
          <td>{{locked}}</td>
        </tr>
        {%- endfor %}
      {%- endfor %}
      </tbody>
    </table>
  </body>
</html>
""").render(data=data, date=datetime.now().strftime("%d %b %Y %H:%M")))



if __name__ == "__main__":
    inventory = {}
    def run_inventory(aws_region):
        """Wraps inventory_data for Thread execution"""
        def wrapped():
            inventory[aws_region] = inventory_initdata(aws_region)
        return wrapped

    # Create a thread per region
    threads = [threading.Thread(target=run_inventory(aws_region)) for aws_region in AWS_REGIONS]

    # Start threads
    for thread in threads:
        thread.start()

    # Wait for threads to complete
    for thread in threads:
        thread.join()

    # Publish HTML-formatted list
    publish_inventory(inventory)
