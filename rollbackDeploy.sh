#!/bin/bash

set -e

taskDefFamilyName=<your task task definition family name>

currentTaskDefiniton=$(
  aws ecs describe-task-definition \
    --task-definition "$taskDefFamilyName" \
    --query '{  containerDefinitions: taskDefinition.containerDefinitions,
                family: taskDefinition.family,
                executionRoleArn: taskDefinition.executionRoleArn,
                networkMode: taskDefinition.networkMode,
                volumes: taskDefinition.volumes,
                placementConstraints: taskDefinition.placementConstraints,
                requiresCompatibilities: taskDefinition.requiresCompatibilities,}'
)

#   cpu: taskDefinition.cpu, memory: taskDefinition.memory 

current_task_definition_revision=$(
  aws ecs describe-task-definition --task-definition "$taskDefFamilyName" \
                                   --query 'taskDefinition.revision'
)

updated_app_image="<ecrUri>/app-container:${gitShortHash}"
updated_nginx_image="<ecrUri>/nginx-container:${gitShortHash}"

# inject new image tag into app
updated_app_task_definition=$(
    echo "$current_task_definition" | jq --arg CONTAINER_IMAGE "$updated_app_image" '.containerDefinitions[0].image = $CONTAINER_IMAGE'
)

# inject new image tag into nginx
updatedTaskDefinition=$(
    echo "$updated_app_task_definition" | jq --arg CONTAINER_IMAGE "$updated_nginx_image" '.containerDefinitions[1].image = $CONTAINER_IMAGE'
)

updatedTaskDefinitionDetail=$(aws ecs register-task-definition --cli-input-json "${updatedTaskDefinition}")

updatedTaskDefinitionRevision=$(echo "$updatedTaskDefinitionDetail" | jq '.taskDefinition.revision')
aws ecs update-service --cluster "Stagging" \
                    --service "${taskDefFamilyName}-service" \
                    --task-definition "${taskDefFamilyName}:$updatedTaskDefinitionRevision" \
                    >/dev/null