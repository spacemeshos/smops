import boto3
import io
import sys

s3 = boto3.client('s3')

network_id = "testnet"

f = io.BytesIO(bytes(' '.join(sys.argv), encoding="ascii"))
s3.upload_fileobj(f, "config.spacemesh.io", network_id)
