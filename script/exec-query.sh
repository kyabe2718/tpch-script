#! /bin/bash

if [[ -z "${PASSWORD}" ]]; then
    echo "PASSWORD isn't defined"
    exit 1
fi

if [[ -z "${DBNAME}" ]]; then
    echo "DBNAME isn't defined"
    exit 1
fi

for f in $@ ; do
    echo exec $f
    time MYSQL_PWD=${PASSWORD} mysql -uroot -D ${DBNAME} < $f > /dev/null
done

