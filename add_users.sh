#!/bin/sh

docker exec rabbitmq rabbitmqctl add_user rabbitmq rabbitmq ; \

docker exec rabbitmq rabbitmqctl set_user_tags rabbitmq administrator ; \

docker exec rabbitmq rabbitmqctl set_permissions -p / rabbitmq ".*" ".*" ".*" ;
