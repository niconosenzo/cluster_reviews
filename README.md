# Description:

OCP4 version of the cluster-review PG program. It only includes checks that can be done through a regular must-gather report, which means components that need to make use of custom must-gather images (like logging, etcd, etc.) are not included wihtin the checks list.

## Usage:
./cluster_review.sh <must-gather_path>

## Dependecies:
- omg
- jq
