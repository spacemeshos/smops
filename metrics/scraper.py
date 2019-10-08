#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

import logging
import os
from time import sleep

import botocore.session
import kubernetes.config
import kubernetes.client

### Parameters
SCRAPE_TYPE = os.environ["SPACEMESH_SCRAPE_TYPE"]
SCRAPE_INTERVAL = int(os.environ.get("SPACEMESH_SCRAPE_INTERVAL", "300"))
SCRAPE_REGION = os.environ["SPACEMESH_SCRAPE_REGION"]

METRIC_REGION = os.environ.get("SPACEMESH_METRIC_REGION", "us-east-1")
METRIC_NAMESPACE = os.environ.get("SPACEMESH_METRIC_NAMESPACE", "spacemesh/" + SCRAPE_REGION)
METRIC_PREFIX = os.environ.get("SPACEMESH_METRIC_PREFIX", SCRAPE_TYPE)

### Configure logging
logging.basicConfig(
    format="%(asctime)s    %(levelname)-8s %(name)-8s %(message)s",
    level=logging.INFO,
    datefmt="%Y-%m-%dT%H:%M:%S.000%z"
    )


def _init_kube():
    kubernetes.config.load_incluster_config()


### Common scraping functions
def scrape_nodes(core_api, pool_names=[]):
    '''Get nodes in the cluster per pool'''
    logging.debug("Scraping nodes")
    pools = dict.fromkeys(pool_names, 0)
    for node in core_api.list_node().items:
        if "pool" in node.metadata.labels:
            pool = node.metadata.labels["pool"]
            logging.debug(f"Scraping node {node.metadata.name} from pool {pool}")
            if not pool in pools:
                pools[pool] = 0

            pools[pool] += 1
        else:
            logging.warning(f"Skipping node {node.metadata.name} with no pool label")

    return [{
        "MetricName": pool + "-nodes",
        "Value": ctr,
        "Unit": "Count",
        } for pool, ctr in pools.items()]


def _scrape_pods(core_api, basename="", selector=None):
    '''Get pod counts in the cluster'''
    logging.debug("Scraping pods")
    pod_status = {"ok": 0, "pending": 0, "error": 0}
    for pod in core_api.list_pod_for_all_namespaces(label_selector=selector).items:
        status = pod.status.phase
        if status == "Running":
            pod_status["ok"] += 1
        elif status == "Pending":
            pod_status["pending"] += 1
        elif status == "Unknown":
            pod_status["unknown"] += 1
        else:
            pod_status["error"] += 1

    prefix = basename + "-pods-" if basename else "pods-"
    return [{
        "MetricName": prefix + status,
        "Value": ctr,
        "Unit": "Count",
        } for status, ctr in pod_status.items()]


def scrape_pods(core_api):
    '''Get pod counts in the cluster'''
    return _scrape_pods(core_api)


def _scrape_deploy(basename, selector):
    '''Scrape the cluster to see the state of Deployments matching the selector'''
    apps_api = kubernetes.client.AppsV1Api()
    replicas = {"ok": 0, "total": 0}
    for deploy in apps_api.list_deployment_for_all_namespaces(label_selector=selector).items:
        replicas["ok"] += deploy.status.available_replicas
        replicas["total"] += deploy.status.replicas

    return [{
        "MetricName": basename + "-replicas-" + status,
        "Value": ctr,
        "Unit": "Count",
        } for status, ctr in replicas.items()]
        

def _scrape_jobs(basename, selector):
    '''Scrape the cluster to see the state of Jobs matching the selector'''
    batch_api = kubernetes.client.BatchV1Api()
    jobs = {"running": 0, "success": 0, "failed": 0}
    for job in batch_api.list_job_for_all_namespaces(label_selector=selector).items:
        if job.status.active:
            jobs["running"] += 1
        if job.status.succeeded:
            jobs["success"] += 1
        if job.status.failed:
            jobs["failed"] += 1

    prefix = basename + "-jobs-" if basename else "jobs-"
    return [{
        "MetricName": prefix + status,
        "Value": ctr,
        "Unit": "Count",
        } for status, ctr in jobs.items()]



### AWS resources scraping
def scrape_volumes():
    '''Scrape the number of EBS volumes in the region'''
    ec2 = botocore.session.get_session().create_client("ec2", region_name=SCRAPE_REGION)
    volumes = {"attached": 0, "available": 0, "total": 0}
    for vol in ec2.describe_volumes()["Volumes"]:
        volumes["total"] += 1
        if vol["State"] == "in-use":
            volumes["attached"] += 1
        if vol["State"] == "available":
            volumes["available"] += 1

    return [{
        "MetricName": "vol-" + status,
        "Value": ctr,
        "Unit": "Count",
        } for status, ctr in volumes.items()]


### Per-cluster scraping functions
def scrape_mgmt(core_api):
    '''Scrape the MGMT EKS and post metrics of PoET pods state'''
    result = _scrape_deploy("poet", "app=poet")
    result += _scrape_pods(core_api, "elasticsearch", "app=logs-master")
    return result


def scrape_initfactory(core_api):
    '''Scrape the InitFactory EKS and post metrics of InitFactory jobs state'''
    result = _scrape_jobs("initfactory", "app=initfactory")
    return result


def scrape_miner(core_api):
    '''Scrape the Miner EKS and post metrics of Miner deploy state'''
    result = _scrape_deploy("miner", "app=miner")
    return result



if __name__ == "__main__":
    logging.info("Starting scraper")
    pool_names = ["master",]
    if SCRAPE_TYPE == "mgmt":
        scrape_func = scrape_mgmt
        pool_names += ["logging", "poet"]
    elif SCRAPE_TYPE == "miner":
        scrape_func = scrape_miner
        pool_names += ["miner",]
    elif SCRAPE_TYPE == "initfactory":
        scrape_func = scrape_initfactory
        pool_names += ["initfactory",]
    else:
        logging.fatal(f"Scrape type '{SCRAPE_TYPE}' not recognised")
        raise SystemExit(1)

    logging.info(f"Scrape type set to {SCRAPE_TYPE}")

    from pprint import pprint
    while True:
        # (Re-)Authenticate with EKS
        _init_kube()
        core_api = kubernetes.client.CoreV1Api()

        # Scrape the nodes
        metrics = scrape_nodes(core_api, pool_names)

        # Scrape the pods
        metrics += scrape_pods(core_api)

        # Scrape the cluster
        metrics += scrape_func(core_api)

        # Scrape the EBS volumes
        if SCRAPE_TYPE == "miner":
            metrics += scrape_volumes()

        # Prepend prefix to metric names
        for metric in metrics:
            metric["MetricName"] = METRIC_PREFIX + "-" + metric["MetricName"]

        # Publish the metrics
        logging.info(f"Publishing metrics to {METRIC_NAMESPACE} into {METRIC_REGION}")
        cloudwatch = botocore.session.get_session().create_client("cloudwatch", region_name=METRIC_REGION)
        try:
            cloudwatch.put_metric_data(Namespace=METRIC_NAMESPACE, MetricData=metrics)
        except:
            logging.exception("Call failed")

        logging.info(f"Sleeping for {SCRAPE_INTERVAL} seconds")
        sleep(SCRAPE_INTERVAL)

# vim: set ts=4 sw=4 et:
