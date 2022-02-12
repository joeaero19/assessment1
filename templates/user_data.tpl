#!/bin/bash

echo BEGIN

# Update packages
yum update -y



# Let the ECS agent know to which cluster this host belongs.

echo ECS_CLUSTER='${ecs_cluster_name}-cluster' > /etc/ecs/ecs.config"

echo END
