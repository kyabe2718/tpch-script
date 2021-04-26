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
    cat $f
    if [ -e $f.exp ]; then
        echo "explain"
        MYSQL_PWD=${PASSWORD} mysql -uroot -D ${DBNAME} -e "$(cat $f.exp)"
    fi
    echo exec $f
    # time MYSQL_PWD=${PASSWORD} mysql -uroot -D ${DBNAME} < $f
    time MYSQL_PWD=${PASSWORD} mysql -uroot -D ${DBNAME} -e "$(cat $f)"
done

