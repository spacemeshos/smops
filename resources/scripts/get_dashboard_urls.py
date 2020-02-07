#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

import argparse
from itertools import chain
import os
from pprint import pprint

from jinja2 import Template
import kubernetes.client
import kubernetes.config

def parse_args():
    """Parse command-line arguments"""
    parser = argparse.ArgumentParser(description="Inventory Kubernetes Dashboard URLs")
    parser.add_argument("--regions", help="Regions", type=str, nargs="+",
                        default=["us-east-1", "us-east-2", "us-west-2", "ap-northeast-2", "eu-north-1"],
                        )
    parser.add_argument("--clusters", help="Clusters in each region", type=str, nargs="+",
                        default=["initfactory", "miner"],
                        )
    parser.add_argument("--extra-contexts", help="Extra contexts, as CTX_NAME:REGION", type=str, nargs="*",
                        default=["mgmt:us-east-1"],
                        )
    parser.add_argument("--port", help="Dashboard service port", type=int, default=30909)

    return parser.parse_args()


def render_page(urls):
    """Render the HTML page from URLs"""
    tpl = Template("""\
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Kubernetes Dashboard locations</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  </head>
  <body>
    <h1>Kubernetes Dashboard locations</h1>
    <table border="1">
      <thead><tr>
        <th>Cluster</th>
        <th>Region</th>
        <th>Dashboard</th>
      </tr></thead>
      <tbody>
      {%- for cluster,regions in urls.items(): %}
        {%- for r,url in regions.items(): %}
        <tr>
          {%- if loop.first: %}
          <th rowspan="{{regions|length}}">{{cluster}}</th>
          {%- endif %}
          <td>{{r}}</td><td><a href="{{url}}" target="_blank">{{url}}</a></td>
        </tr>
        {%- endfor %}
      {%- endfor %}
      </tbody>
    </table>
  </body>
</html>
""")
    return tpl.render(urls=urls)



### MAIN
if __name__ == "__main__":
    args = parse_args()

    contexts = {}
    for cluster in sorted(args.clusters):
        contexts[cluster] = sorted(args.regions)

    for extra_ctx in args.extra_contexts:
        cluster, region = extra_ctx.split(":")
        if not cluster in contexts:
            contexts[cluster] = []
        contexts[cluster].append(region)

    warnings = []
    urls = {}

    for cluster in sorted(contexts):
        urls[cluster] = {}
        for region in sorted(contexts[cluster]):
            ctx = f"{cluster}-{region}"
            kubernetes.config.load_kube_config(context=ctx)
            nodes = kubernetes.client.apis.CoreV1Api().list_node(label_selector="pool=master").items
            for addr in chain(*[node.status.addresses for node in nodes]):
                if addr.type == "InternalIP":
                    urls[cluster][region] = f"http://{addr.address}:{args.port}/"
                    break
            else:
                warnings.append(f"No master node with internal IP in {ctx}")
                continue

    print(render_page(urls))

# vim: filetype=python ts=4 sw=4 et ai:
